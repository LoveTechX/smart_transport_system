class BusRoute {
  final String id;
  final String routeNumber;
  final String name;
  final String source;
  final String destination;
  final List<RouteStop> stops;
  final double distance;
  final int estimatedMinutes;
  final String operator;
  final String busType;
  final double fare;
  final bool isActive;

  BusRoute({
    required this.id,
    required this.routeNumber,
    required this.name,
    required this.source,
    required this.destination,
    required this.stops,
    required this.distance,
    required this.estimatedMinutes,
    required this.operator,
    required this.busType,
    required this.fare,
    this.isActive = true,
  });

  factory BusRoute.fromMap(Map<String, dynamic> map) {
    return BusRoute(
      id: map['id'] ?? '',
      routeNumber: map['routeNumber'] ?? '',
      name: map['name'] ?? '',
      source: map['source'] ?? '',
      destination: map['destination'] ?? '',
      stops:
          (map['stops'] as List?)?.map((s) => RouteStop.fromMap(s)).toList() ??
              [],
      distance: (map['distance'] ?? 0).toDouble(),
      estimatedMinutes: map['estimatedMinutes'] ?? 0,
      operator: map['operator'] ?? '',
      busType: map['busType'] ?? '',
      fare: (map['fare'] ?? 0).toDouble(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routeNumber': routeNumber,
      'name': name,
      'source': source,
      'destination': destination,
      'stops': stops.map((s) => s.toMap()).toList(),
      'distance': distance,
      'estimatedMinutes': estimatedMinutes,
      'operator': operator,
      'busType': busType,
      'fare': fare,
      'isActive': isActive,
    };
  }
}

class RouteStop {
  final String id;
  final String stopName;
  final double latitude;
  final double longitude;
  final int sequenceNumber;
  final int arrivalMinutes;
  final String landmark;

  RouteStop({
    required this.id,
    required this.stopName,
    required this.latitude,
    required this.longitude,
    required this.sequenceNumber,
    required this.arrivalMinutes,
    this.landmark = '',
  });

  factory RouteStop.fromMap(Map<String, dynamic> map) {
    return RouteStop(
      id: map['id'] ?? '',
      stopName: map['stopName'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      sequenceNumber: map['sequenceNumber'] ?? 0,
      arrivalMinutes: map['arrivalMinutes'] ?? 0,
      landmark: map['landmark'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stopName': stopName,
      'latitude': latitude,
      'longitude': longitude,
      'sequenceNumber': sequenceNumber,
      'arrivalMinutes': arrivalMinutes,
      'landmark': landmark,
    };
  }
}
