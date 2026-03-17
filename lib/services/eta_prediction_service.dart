import 'package:geolocator/geolocator.dart';

import '../models/bus_route.dart';

class EtaPredictionService {
  EtaPredictionService();

  static const double _minimumUsableSpeedKmh = 2.0;
  static const double _nextStopReachedThresholdMeters = 60;

  Future<EtaPrediction?> predict({
    required String vehicleId,
    required BusRoute route,
    required double latitude,
    required double longitude,
    required DateTime telemetryUpdatedAt,
    double? speedKmh,
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

    final hasLiveSpeed = speedKmh != null && speedKmh >= _minimumUsableSpeedKmh;
    final routeAverageSpeedKmh = _routeAverageSpeedKmh(route);
    final effectiveSpeedKmh = hasLiveSpeed ? speedKmh : routeAverageSpeedKmh;

    final etaSeconds = ((distanceMeters * 3.6) / effectiveSpeedKmh)
        .round()
        .clamp(0, 24 * 60 * 60);

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
      speedKmhUsed: effectiveSpeedKmh,
      usedFallbackSpeed: !hasLiveSpeed,
    );

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

  double _routeAverageSpeedKmh(BusRoute route) {
    if (route.distance <= 0 || route.estimatedMinutes <= 0) {
      return 24.0;
    }

    return (route.distance / route.estimatedMinutes) * 60;
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
    required this.speedKmhUsed,
    required this.usedFallbackSpeed,
  });

  final String vehicleId;
  final String nextStopId;
  final DateTime predictedArrival;
  final double confidence;
  final double distanceMeters;
  final double speedKmhUsed;
  final bool usedFallbackSpeed;
}
