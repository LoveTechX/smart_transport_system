import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/fleet_alert.dart';

/// Monitors the `telemetry` and `trips` Firestore collections and writes
/// alert documents to `alerts/{vehicleId}_{type}` whenever a threshold is
/// crossed.  When the condition clears the alert document is deleted so the
/// dashboard always reflects the *current* fleet state.
///
/// One document per (vehicle, alert-type) pair is maintained so that
/// rapidly-changing telemetry values never flood the `alerts` collection.
///
/// Call [start] once and [dispose] when done (e.g. in a widget's dispose).
class FleetAlertService {
  FleetAlertService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Thresholds ────────────────────────────────────────────────────────────

  /// Speeds strictly above this value (km/h) raise an overspeed alert.
  static const double overspeedThresholdKmh = 80.0;

  /// Vehicles that have not published telemetry within this window are
  /// considered offline.
  static const Duration offlineThreshold = Duration(seconds: 20);

  /// Occupancy fraction above which a crowded-bus alert is raised (0–1).
  static const double crowdThresholdFraction = 0.9;

  // ── Private state ─────────────────────────────────────────────────────────

  final FirebaseFirestore _firestore;

  final Map<String, _TelemetryState> _telemetry = {};
  final Map<String, _TripState> _trips = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _telemetrySubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tripSubscription;

  /// Periodic timer that re-evaluates the offline condition for all known
  /// vehicles even when no new telemetry arrives.
  Timer? _offlineTimer;

  bool get isRunning => _telemetrySubscription != null;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Start monitoring.  Safe to call multiple times — subsequent calls are
  /// ignored if the service is already running.
  void start() {
    if (isRunning) return;

    _telemetrySubscription = _firestore
        .collection('telemetry')
        .snapshots()
        .listen(_onTelemetrySnapshot, onError: _onStreamError);

    _tripSubscription = _firestore
        .collection('trips')
        .snapshots()
        .listen(_onTripSnapshot, onError: _onStreamError);

    // Re-check offline status every 10 s even when no telemetry arrives.
    _offlineTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkAllOffline(),
    );
  }

  /// Stop monitoring and release resources.
  void stop() {
    _telemetrySubscription?.cancel();
    _telemetrySubscription = null;
    _tripSubscription?.cancel();
    _tripSubscription = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _telemetry.clear();
    _trips.clear();
  }

  /// Alias for [stop] — suitable for use as a dispose callback.
  void dispose() => stop();

  // ── Stream handlers ───────────────────────────────────────────────────────

  void _onTelemetrySnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    for (final change in snapshot.docChanges) {
      final vehicleId = change.doc.id;

      if (change.type == DocumentChangeType.removed) {
        _telemetry.remove(vehicleId);
        _clearAllAlertsFor(vehicleId);
        continue;
      }

      final data = change.doc.data();
      if (data == null) continue;

      final speedKmh = _toDouble(data['speedKmh']) ?? 0.0;
      final updatedAt = _toDateTime(data['updatedAt']);

      _telemetry[vehicleId] = _TelemetryState(
        speedKmh: speedKmh,
        updatedAt: updatedAt,
      );

      _evaluateSpeed(vehicleId, speedKmh);
      _evaluateOffline(vehicleId, updatedAt);
    }
  }

  void _onTripSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;

      final vehicleId = data['vehicleId']?.toString().trim();
      if (vehicleId == null || vehicleId.isEmpty) continue;

      if (change.type == DocumentChangeType.removed) {
        _trips.remove(vehicleId);
        _clearAlert(vehicleId, FleetAlertType.crowdedBus);
        continue;
      }

      final occupancy = _toInt(data['currentOccupancy']) ?? 0;
      final available = _toInt(data['availableSeats']) ?? 0;

      _trips[vehicleId] = _TripState(
        currentOccupancy: occupancy,
        availableSeats: available,
      );

      _evaluateOccupancy(vehicleId, occupancy, available);
    }
  }

  void _checkAllOffline() {
    for (final entry in _telemetry.entries) {
      _evaluateOffline(entry.key, entry.value.updatedAt);
    }
  }

  // ── Alert evaluation ──────────────────────────────────────────────────────

  void _evaluateSpeed(String vehicleId, double speedKmh) {
    if (speedKmh > overspeedThresholdKmh) {
      _upsertAlert(
        vehicleId: vehicleId,
        type: FleetAlertType.overspeed,
        message:
            'Vehicle $vehicleId is overspeeding at ${speedKmh.toStringAsFixed(1)} km/h '
            '(limit: ${overspeedThresholdKmh.toStringAsFixed(0)} km/h).',
        severity: AlertSeverity.critical,
      );
    } else {
      _clearAlert(vehicleId, FleetAlertType.overspeed);
    }
  }

  void _evaluateOffline(String vehicleId, DateTime? updatedAt) {
    final isOffline = updatedAt == null ||
        DateTime.now().difference(updatedAt) > offlineThreshold;

    if (isOffline) {
      _upsertAlert(
        vehicleId: vehicleId,
        type: FleetAlertType.vehicleOffline,
        message: 'Vehicle $vehicleId has not sent telemetry for more than '
            '${offlineThreshold.inSeconds} seconds.',
        severity: AlertSeverity.warning,
      );
    } else {
      _clearAlert(vehicleId, FleetAlertType.vehicleOffline);
    }
  }

  void _evaluateOccupancy(String vehicleId, int occupancy, int availableSeats) {
    final total = occupancy + availableSeats;
    if (total <= 0) return;

    final fraction = occupancy / total;
    if (fraction > crowdThresholdFraction) {
      final pct = (fraction * 100).toStringAsFixed(0);
      _upsertAlert(
        vehicleId: vehicleId,
        type: FleetAlertType.crowdedBus,
        message:
            'Vehicle $vehicleId is at $pct% capacity ($occupancy/$total passengers).',
        severity: AlertSeverity.warning,
      );
    } else {
      _clearAlert(vehicleId, FleetAlertType.crowdedBus);
    }
  }

  // ── Firestore writes ──────────────────────────────────────────────────────

  /// Creates or updates an alert document.  Using `set` is idempotent: when
  /// the same condition fires repeatedly the existing document is simply
  /// refreshed with the latest message and timestamp.
  void _upsertAlert({
    required String vehicleId,
    required FleetAlertType type,
    required String message,
    required AlertSeverity severity,
  }) {
    final docId = _docId(vehicleId, type);
    _firestore.collection('alerts').doc(docId).set({
      'vehicleId': vehicleId,
      'type': type.name,
      'message': message,
      'severity': severity.name,
      'timestamp': FieldValue.serverTimestamp(),
    }).catchError((Object error) {
      debugPrint('FleetAlertService: failed to write $docId — $error');
    });
  }

  /// Deletes the alert document if it exists.  A not-found error is silently
  /// swallowed because the document may never have been created.
  void _clearAlert(String vehicleId, FleetAlertType type) {
    final docId = _docId(vehicleId, type);
    _firestore
        .collection('alerts')
        .doc(docId)
        .delete()
        .catchError((Object _) {});
  }

  void _clearAllAlertsFor(String vehicleId) {
    for (final type in FleetAlertType.values) {
      _clearAlert(vehicleId, type);
    }
  }

  static String _docId(String vehicleId, FleetAlertType type) =>
      '${vehicleId}_${type.name}';

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double? _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _toDateTime(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  void _onStreamError(Object error) {
    debugPrint('FleetAlertService stream error: $error');
  }
}

// ── Internal value types ───────────────────────────────────────────────────

class _TelemetryState {
  const _TelemetryState({required this.speedKmh, required this.updatedAt});

  final double speedKmh;
  final DateTime? updatedAt;
}

class _TripState {
  const _TripState(
      {required this.currentOccupancy, required this.availableSeats});

  final int currentOccupancy;
  final int availableSeats;
}
