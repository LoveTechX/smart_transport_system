import 'package:cloud_firestore/cloud_firestore.dart';

class RouteAnalyticsData {
  const RouteAnalyticsData({
    required this.routeId,
    required this.averageOccupancy,
    required this.peakHour,
    required this.averageTripDuration,
    required this.utilization,
    required this.updatedAt,
  });

  final String routeId;
  final double averageOccupancy;
  final int peakHour;
  final double averageTripDuration;
  final double utilization;
  final DateTime? updatedAt;

  factory RouteAnalyticsData.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RouteAnalyticsData(
      routeId: doc.id,
      averageOccupancy: _toDouble(data['averageOccupancy']) ?? 0,
      peakHour: (_toInt(data['peakHour']) ?? 0).clamp(0, 23),
      averageTripDuration: _toDouble(data['averageTripDuration']) ?? 0,
      utilization: _toDouble(data['utilization']) ?? 0,
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toWriteMap() {
    return {
      'routeId': routeId,
      'averageOccupancy': averageOccupancy,
      'peakHour': peakHour,
      'averageTripDuration': averageTripDuration,
      'utilization': utilization,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static int? _toInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class TransportAnalyticsService {
  TransportAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const Duration _activeTelemetryWindow = Duration(minutes: 30);

  final FirebaseFirestore _firestore;

  Stream<List<RouteAnalyticsData>> watchRouteAnalytics() {
    return _firestore.collection('analytics').snapshots().map((snapshot) =>
        snapshot.docs.map(RouteAnalyticsData.fromDoc).toList(growable: false)
          ..sort((a, b) => a.routeId.compareTo(b.routeId)));
  }

  Future<List<RouteAnalyticsData>> recomputeAndPersistAllRoutes() async {
    final tripsFuture = _firestore.collection('trips').get();
    final ticketsFuture = _firestore.collection('tickets').get();
    final telemetryFuture = _firestore.collection('telemetry').get();

    final tripsSnapshot = await tripsFuture;
    final ticketsSnapshot = await ticketsFuture;
    final telemetrySnapshot = await telemetryFuture;

    final trips = tripsSnapshot.docs;
    final tickets = ticketsSnapshot.docs;
    final telemetry = telemetrySnapshot.docs;

    final routeIds = <String>{};
    for (final doc in trips) {
      final routeId = doc.data()['routeId']?.toString().trim();
      if (routeId != null && routeId.isNotEmpty) {
        routeIds.add(routeId);
      }
    }
    for (final doc in tickets) {
      final routeId = doc.data()['routeId']?.toString().trim();
      if (routeId != null && routeId.isNotEmpty) {
        routeIds.add(routeId);
      }
    }

    final now = DateTime.now();
    final analytics = <RouteAnalyticsData>[];

    for (final routeId in routeIds) {
      final routeTrips = trips.where(
        (doc) => doc.data()['routeId']?.toString().trim() == routeId,
      );
      final routeTickets = tickets.where(
        (doc) => doc.data()['routeId']?.toString().trim() == routeId,
      );

      final occupancySamples = <double>[];
      final tripDurationsMinutes = <double>[];
      final assignedVehicles = <String>{};

      for (final tripDoc in routeTrips) {
        final trip = tripDoc.data();

        final occupancy = _toDouble(trip['currentOccupancy']);
        var capacity = _toDouble(trip['capacity']) ??
            _toDouble(trip['seatCapacity']) ??
            _toDouble(trip['totalSeats']);

        final availableSeats = _toDouble(trip['availableSeats']);
        if ((capacity == null || capacity <= 0) &&
            occupancy != null &&
            availableSeats != null &&
            occupancy + availableSeats > 0) {
          capacity = occupancy + availableSeats;
        }

        final occupancyPercent = _toDouble(trip['occupancyPercent']);
        if (occupancy != null && capacity != null && capacity > 0) {
          occupancySamples.add(((occupancy / capacity) * 100).clamp(0, 100));
        } else if (occupancyPercent != null) {
          occupancySamples.add(occupancyPercent.clamp(0, 100));
        }

        final directDuration = _toDouble(trip['durationMinutes']) ??
            _toDouble(trip['tripDuration']) ??
            _toDouble(trip['duration']);

        if (directDuration != null && directDuration > 0) {
          tripDurationsMinutes.add(directDuration);
        } else {
          final startTime = _extractDateTime(
            trip,
            const [
              'actualStartTime',
              'startTime',
              'startedAt',
              'departureTime',
              'tripStart',
            ],
          );
          final endTime = _extractDateTime(
            trip,
            const [
              'actualEndTime',
              'endTime',
              'endedAt',
              'arrivalTime',
              'tripEnd',
            ],
          );

          if (startTime != null &&
              endTime != null &&
              endTime.isAfter(startTime)) {
            tripDurationsMinutes
                .add(endTime.difference(startTime).inMinutes.toDouble());
          }
        }

        final vehicleId = trip['vehicleId']?.toString().trim();
        if (vehicleId != null && vehicleId.isNotEmpty) {
          assignedVehicles.add(vehicleId);
        }
      }

      final hourCounts = List<int>.filled(24, 0);
      for (final ticketDoc in routeTickets) {
        final ticket = ticketDoc.data();
        final ts = _extractDateTime(
          ticket,
          const [
            'verifiedAt',
            'usedAt',
            'boardedAt',
            'createdAt',
            'issuedAt',
            'purchaseTime',
          ],
        );
        if (ts != null) {
          hourCounts[ts.toLocal().hour]++;
        }
      }

      var peakHour = 0;
      var peakCount = -1;
      for (var hour = 0; hour < hourCounts.length; hour++) {
        if (hourCounts[hour] > peakCount) {
          peakCount = hourCounts[hour];
          peakHour = hour;
        }
      }

      final activeVehicles = _countActiveVehicles(
        telemetryDocs: telemetry,
        assignedVehicles: assignedVehicles,
        now: now,
      );
      final utilization = assignedVehicles.isEmpty
          ? 0.0
          : ((activeVehicles / assignedVehicles.length) * 100).clamp(0, 100);

      analytics.add(
        RouteAnalyticsData(
          routeId: routeId,
          averageOccupancy: _average(occupancySamples),
          peakHour: peakHour,
          averageTripDuration: _average(tripDurationsMinutes),
          utilization: utilization,
          updatedAt: null,
        ),
      );
    }

    final batch = _firestore.batch();
    for (final routeAnalytics in analytics) {
      final analyticsRef =
          _firestore.collection('analytics').doc(routeAnalytics.routeId);
      batch.set(
          analyticsRef, routeAnalytics.toWriteMap(), SetOptions(merge: true));
    }
    await batch.commit();

    return analytics;
  }

  int _countActiveVehicles({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> telemetryDocs,
    required Set<String> assignedVehicles,
    required DateTime now,
  }) {
    if (assignedVehicles.isEmpty) {
      return 0;
    }

    var activeCount = 0;
    for (final doc in telemetryDocs) {
      final vehicleId = doc.id.trim();
      if (!assignedVehicles.contains(vehicleId)) {
        continue;
      }

      final data = doc.data();
      final ts = _extractDateTime(data, const ['timestamp', 'updatedAt']);
      if (ts == null) {
        continue;
      }

      if (now.difference(ts.toLocal()) <= _activeTelemetryWindow) {
        activeCount++;
      }
    }

    return activeCount;
  }

  DateTime? _extractDateTime(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      final dt = _toDateTime(value);
      if (dt != null) {
        return dt;
      }
    }
    return null;
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final total = values.reduce((a, b) => a + b);
    return total / values.length;
  }

  static double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
