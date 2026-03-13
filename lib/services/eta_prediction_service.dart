import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/bus_route.dart';

class EtaPredictionService {
  EtaPredictionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const double _minimumUsableSpeedMps = 0.5;
  static const double _nextStopReachedThresholdMeters = 60;

  final FirebaseFirestore _firestore;

  Future<EtaPrediction?> predictAndStore({
    required String vehicleId,
    required BusRoute route,
    required double latitude,
    required double longitude,
    required DateTime telemetryUpdatedAt,
    double? speedMps,
  }) async {
    final normalizedVehicleId = vehicleId.trim();
    if (normalizedVehicleId.isEmpty || route.stops.isEmpty) {
      return null;
    }

    final orderedStops = List<RouteStop>.from(route.stops)
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    final nextStop = _resolveNextStop(
      latitude: latitude,
      longitude: longitude,
      orderedStops: orderedStops,
    );
    if (nextStop == null) {
      return null;
    }

    final distanceMeters = Geolocator.distanceBetween(
      latitude,
      longitude,
      nextStop.latitude,
      nextStop.longitude,
    );

    final hasLiveSpeed = speedMps != null && speedMps >= _minimumUsableSpeedMps;
    final routeAverageSpeedMps = _routeAverageSpeedMps(route);
    final effectiveSpeedMps = hasLiveSpeed ? speedMps! : routeAverageSpeedMps;

    final etaSeconds =
        (distanceMeters / effectiveSpeedMps).round().clamp(0, 24 * 60 * 60);

    final predictedArrival = telemetryUpdatedAt.add(
      Duration(seconds: etaSeconds),
    );

    final confidence = _confidenceScore(
      hasLiveSpeed: hasLiveSpeed,
      distanceMeters: distanceMeters,
      telemetryUpdatedAt: telemetryUpdatedAt,
    );

    final prediction = EtaPrediction(
      vehicleId: normalizedVehicleId,
      nextStopId: nextStop.id,
      predictedArrival: predictedArrival,
      confidence: confidence,
      distanceMeters: distanceMeters,
      speedMpsUsed: effectiveSpeedMps,
      usedFallbackSpeed: !hasLiveSpeed,
    );

    await _firestore.collection('etas').doc(normalizedVehicleId).set({
      'nextStopId': prediction.nextStopId,
      'predictedArrival': Timestamp.fromDate(prediction.predictedArrival),
      'confidence': prediction.confidence,
      'routeId': route.id,
      'distanceMeters': prediction.distanceMeters,
      'speedMps': prediction.speedMpsUsed,
      'usedFallbackSpeed': prediction.usedFallbackSpeed,
      'telemetryUpdatedAt': Timestamp.fromDate(telemetryUpdatedAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return prediction;
  }

  RouteStop? _resolveNextStop({
    required double latitude,
    required double longitude,
    required List<RouteStop> orderedStops,
  }) {
    if (orderedStops.isEmpty) {
      return null;
    }

    var nearestIndex = 0;
    var nearestDistance = double.infinity;

    for (var i = 0; i < orderedStops.length; i++) {
      final stop = orderedStops[i];
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        stop.latitude,
        stop.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    if (nearestDistance <= _nextStopReachedThresholdMeters &&
        nearestIndex < orderedStops.length - 1) {
      return orderedStops[nearestIndex + 1];
    }

    return orderedStops[nearestIndex];
  }

  double _routeAverageSpeedMps(BusRoute route) {
    if (route.distance <= 0 || route.estimatedMinutes <= 0) {
      return 6.0;
    }

    final seconds = route.estimatedMinutes * 60;
    return (route.distance * 1000) / seconds;
  }

  double _confidenceScore({
    required bool hasLiveSpeed,
    required double distanceMeters,
    required DateTime telemetryUpdatedAt,
  }) {
    var base = hasLiveSpeed ? 0.86 : 0.62;

    if (distanceMeters > 5000) {
      base -= 0.08;
    } else if (distanceMeters < 800) {
      base += 0.05;
    }

    final ageSeconds = DateTime.now().difference(telemetryUpdatedAt).inSeconds;
    if (ageSeconds > 45) {
      base -= 0.07;
    } else if (ageSeconds < 10) {
      base += 0.03;
    }

    return base.clamp(0.1, 0.99);
  }
}

class EtaPrediction {
  const EtaPrediction({
    required this.vehicleId,
    required this.nextStopId,
    required this.predictedArrival,
    required this.confidence,
    required this.distanceMeters,
    required this.speedMpsUsed,
    required this.usedFallbackSpeed,
  });

  final String vehicleId;
  final String nextStopId;
  final DateTime predictedArrival;
  final double confidence;
  final double distanceMeters;
  final double speedMpsUsed;
  final bool usedFallbackSpeed;
}
