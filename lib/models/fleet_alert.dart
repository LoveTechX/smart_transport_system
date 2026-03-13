import 'package:cloud_firestore/cloud_firestore.dart';

/// The category of fleet alert that was raised.
enum FleetAlertType {
  /// Vehicle speed exceeded the configured threshold.
  overspeed,

  /// Vehicle has not published telemetry recently.
  vehicleOffline,

  /// Bus occupancy exceeds the crowding threshold.
  crowdedBus,
}

/// How urgent the alert is.
enum AlertSeverity { info, warning, critical }

/// A single active alert stored in `alerts/{alertId}`.
class FleetAlert {
  const FleetAlert({
    required this.alertId,
    required this.vehicleId,
    required this.type,
    required this.message,
    required this.timestamp,
    required this.severity,
  });

  final String alertId;
  final String vehicleId;
  final FleetAlertType type;
  final String message;
  final DateTime timestamp;
  final AlertSeverity severity;

  /// Parses a Firestore document into a [FleetAlert].
  /// Returns `null` if required fields are missing or unrecognised.
  static FleetAlert? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;

    final type = _typeFromString(data['type']?.toString());
    if (type == null) return null;

    final ts = data['timestamp'];
    final DateTime timestamp;
    if (ts is Timestamp) {
      timestamp = ts.toDate();
    } else {
      timestamp = DateTime.now();
    }

    return FleetAlert(
      alertId: doc.id,
      vehicleId: data['vehicleId']?.toString() ?? '',
      type: type,
      message: data['message']?.toString() ?? '',
      timestamp: timestamp,
      severity: _severityFromString(data['severity']?.toString()),
    );
  }

  /// Serialises to the Firestore document map sent on write.
  /// `timestamp` uses `FieldValue.serverTimestamp()` so the field is set by
  /// the Firestore backend and is always reliable.
  Map<String, dynamic> toWriteMap() {
    return {
      'vehicleId': vehicleId,
      'type': type.name,
      'message': message,
      'severity': severity.name,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  static FleetAlertType? _typeFromString(String? value) {
    return switch (value) {
      'overspeed' => FleetAlertType.overspeed,
      'vehicleOffline' => FleetAlertType.vehicleOffline,
      'crowdedBus' => FleetAlertType.crowdedBus,
      _ => null,
    };
  }

  static AlertSeverity _severityFromString(String? value) {
    return switch (value) {
      'critical' => AlertSeverity.critical,
      'warning' => AlertSeverity.warning,
      _ => AlertSeverity.info,
    };
  }
}
