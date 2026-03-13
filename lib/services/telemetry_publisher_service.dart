import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class TelemetryPublisherService {
  TelemetryPublisherService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    GeolocatorPlatform? geolocator,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _geolocator = geolocator ?? GeolocatorPlatform.instance;

  static const double _minDistanceMeters = 5.0;
  static const Duration _maxPublishInterval = Duration(seconds: 3);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final GeolocatorPlatform _geolocator;

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPublishedPosition;
  DateTime? _lastPublishedAt;

  bool get isPublishing => _positionSubscription != null;

  Future<void> startPublishing({
    required String vehicleId,
    String? driverId,
  }) async {
    if (vehicleId.trim().isEmpty) {
      throw ArgumentError.value(
          vehicleId, 'vehicleId', 'vehicleId is required');
    }

    final resolvedDriverId = _resolveDriverId(driverId);

    await _ensureLocationAccess();
    await stopPublishing();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionSubscription = _geolocator
        .getPositionStream(locationSettings: settings)
        .listen((position) {
      _handlePosition(
        vehicleId: vehicleId.trim(),
        driverId: resolvedDriverId,
        position: position,
      );
    });
  }

  Future<void> stopPublishing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPublishedPosition = null;
    _lastPublishedAt = null;
  }

  Future<void> dispose() async {
    await stopPublishing();
  }

  Future<void> _handlePosition({
    required String vehicleId,
    required String driverId,
    required Position position,
  }) async {
    final now = DateTime.now();
    final shouldPublish = _shouldPublish(position: position, now: now);

    if (!shouldPublish) {
      return;
    }

    final telemetry = <String, dynamic>{
      'vehicleId': vehicleId,
      'driverId': driverId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed': position.speed < 0 ? 0.0 : position.speed,
      'heading': _normalizedHeading(position.heading),
      'timestamp': Timestamp.fromDate(position.timestamp ?? now),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('telemetry')
        .doc(vehicleId)
        .set(telemetry, SetOptions(merge: true));

    _lastPublishedPosition = position;
    _lastPublishedAt = now;
  }

  bool _shouldPublish({
    required Position position,
    required DateTime now,
  }) {
    final previousPosition = _lastPublishedPosition;
    final previousTimestamp = _lastPublishedAt;

    if (previousPosition == null || previousTimestamp == null) {
      return true;
    }

    final movedMeters = Geolocator.distanceBetween(
      previousPosition.latitude,
      previousPosition.longitude,
      position.latitude,
      position.longitude,
    );

    final elapsed = now.difference(previousTimestamp);

    return movedMeters > _minDistanceMeters || elapsed >= _maxPublishInterval;
  }

  double _normalizedHeading(double rawHeading) {
    if (rawHeading.isNaN || rawHeading.isInfinite) {
      return 0.0;
    }

    final heading = rawHeading % 360;
    if (heading < 0) {
      return heading + 360;
    }

    return heading;
  }

  String _resolveDriverId(String? explicitDriverId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError(
          'Driver must be authenticated before telemetry publishing starts.');
    }

    if (explicitDriverId != null && explicitDriverId != currentUser.uid) {
      throw StateError(
          'driverId must match the authenticated user uid for telemetry writes.');
    }

    return currentUser.uid;
  }

  Future<void> _ensureLocationAccess() async {
    final serviceEnabled = await _geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location services are disabled.');
    }

    var permission = await _geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission not granted.');
    }
  }
}
