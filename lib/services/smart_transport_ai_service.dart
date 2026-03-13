import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/bus_route.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
  });
}

class TicketData {
  final String ticketId;
  final String passengerName;
  final String routeId;
  final int seatNumber;
  final DateTime issuedAt;

  TicketData({
    required this.ticketId,
    required this.passengerName,
    required this.routeId,
    required this.seatNumber,
    required this.issuedAt,
  });
}

class FleetStatusSnapshot {
  final int activeBuses;
  final int delayedBuses;
  final int crowdedBuses;
  final double routeEfficiency;
  final double avgDriverScore;

  FleetStatusSnapshot({
    required this.activeBuses,
    required this.delayedBuses,
    required this.crowdedBuses,
    required this.routeEfficiency,
    required this.avgDriverScore,
  });
}

class SmartTransportAIService {
  SmartTransportAIService._();

  static final SmartTransportAIService instance = SmartTransportAIService._();

  final Random _random = Random();

  final ValueNotifier<bool> offlineMode = ValueNotifier<bool>(false);
  final ValueNotifier<List<AppNotification>> notifications =
      ValueNotifier<List<AppNotification>>(<AppNotification>[]);

  final Map<String, Set<int>> _occupiedSeatsByBus = <String, Set<int>>{};
  final Map<String, TicketData> _tickets = <String, TicketData>{};
  final List<Map<String, dynamic>> _feedback = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _tripHistory = <Map<String, dynamic>>[];
  final Map<String, LatLng> _liveBusLocations = <String, LatLng>{};
  final ValueNotifier<String> selectedLanguage =
      ValueNotifier<String>('English');

  Timer? _notificationTimer;

  void startNotificationFeed() {
    _notificationTimer ??=
        Timer.periodic(const Duration(seconds: 15), (_) => _emitNotification());
  }

  void stopNotificationFeed() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }

  void _emitNotification() {
    final templates = <Map<String, String>>[
      {
        'title': 'Bus Arrival',
        'message': 'Your bus is arriving in approximately 6 minutes.'
      },
      {
        'title': 'Delay Alert',
        'message': 'Route R-204 delayed by 8 minutes due to traffic.'
      },
      {
        'title': 'Route Update',
        'message': 'Smart route optimization switched to a faster corridor.'
      },
      {
        'title': 'Safety Notice',
        'message': 'Emergency systems are active and monitored.'
      },
    ];
    final pick = templates[_random.nextInt(templates.length)];
    final next = List<AppNotification>.from(notifications.value)
      ..insert(
        0,
        AppNotification(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: pick['title'] ?? 'Update',
          message: pick['message'] ?? 'Transport notification',
          createdAt: DateTime.now(),
        ),
      );
    notifications.value = next.take(30).toList();
  }

  String t(String key) {
    const labels = <String, Map<String, String>>{
      'English': {
        'live_tracking': 'Live GPS Bus Tracking',
        'arrival_prediction': 'AI Arrival Prediction',
        'offline_mode': 'Offline Mode',
      },
      'Hindi': {
        'live_tracking': 'लाइव जीपीएस बस ट्रैकिंग',
        'arrival_prediction': 'एआई आगमन पूर्वानुमान',
        'offline_mode': 'ऑफलाइन मोड',
      },
      'Punjabi': {
        'live_tracking': 'ਲਾਈਵ ਜੀਪੀਐਸ ਬੱਸ ਟ੍ਰੈਕਿੰਗ',
        'arrival_prediction': 'ਏਆਈ ਆਉਣ ਦੀ ਭਵਿੱਖਬਾਣੀ',
        'offline_mode': 'ਆਫਲਾਈਨ ਮੋਡ',
      },
    };

    final languageMap = labels[selectedLanguage.value] ?? labels['English']!;
    return languageMap[key] ?? key;
  }

  List<String> supportedLanguages() => const ['English', 'Hindi', 'Punjabi'];

  int predictArrivalMinutes({
    required BusRoute route,
    required double trafficFactor,
    required List<int> historicalDelays,
  }) {
    final historyAvg = historicalDelays.isEmpty
        ? 0
        : historicalDelays.reduce((a, b) => a + b) ~/ historicalDelays.length;
    final trafficImpact = (route.estimatedMinutes * trafficFactor).round();
    final aiAdjustment = _random.nextInt(4) - 1;
    final prediction =
        route.estimatedMinutes + historyAvg + trafficImpact + aiAdjustment;
    return prediction < 1 ? 1 : prediction;
  }

  int predictEtaLstmBiLstm({
    required BusRoute route,
    required double trafficFactor,
    required List<int> historicalDelays,
    required int stopSequence,
  }) {
    final baseEta = predictArrivalMinutes(
      route: route,
      trafficFactor: trafficFactor,
      historicalDelays: historicalDelays,
    );
    final stopAdjustment = (stopSequence * 0.8).round();
    final lstmDriftCorrection = _random.nextInt(3) - 1;
    final prediction = baseEta + stopAdjustment + lstmDriftCorrection;
    return prediction < 1 ? 1 : prediction;
  }

  int predictTravelTimeXgboost({
    required BusRoute route,
    required double trafficLoad,
    required int intersections,
    required int avgStopTimeSeconds,
    required double weatherSeverity,
  }) {
    final routeMinutes = route.estimatedMinutes;
    final trafficMinutes = (routeMinutes * trafficLoad * 0.6).round();
    final intersectionMinutes = (intersections * 0.18).round();
    final stopMinutes = ((avgStopTimeSeconds / 60) * 0.35).round();
    final weatherMinutes = (routeMinutes * weatherSeverity * 0.3).round();
    final boostedPrediction = routeMinutes +
        trafficMinutes +
        intersectionMinutes +
        stopMinutes +
        weatherMinutes;
    return boostedPrediction < 1 ? 1 : boostedPrediction;
  }

  BusRoute optimizeRoute({
    required List<BusRoute> routes,
    required double trafficFactor,
  }) {
    if (routes.isEmpty) {
      throw StateError('No routes available for optimization');
    }

    BusRoute best = routes.first;
    int bestEta = predictArrivalMinutes(
      route: best,
      trafficFactor: trafficFactor,
      historicalDelays: const [2, 4, 6],
    );

    for (final candidate in routes.skip(1)) {
      final eta = predictArrivalMinutes(
        route: candidate,
        trafficFactor: trafficFactor,
        historicalDelays: const [1, 3, 5],
      );
      if (eta < bestEta) {
        best = candidate;
        bestEta = eta;
      }
    }
    return best;
  }

  BusRoute optimizeRouteReinforcement({
    required List<BusRoute> routes,
    required double trafficFactor,
    required double closureRisk,
    required double congestionLevel,
  }) {
    if (routes.isEmpty) {
      throw StateError('No routes available for RL optimization');
    }

    BusRoute selected = routes.first;
    double bestReward = -99999;

    for (final route in routes) {
      final eta = predictArrivalMinutes(
        route: route,
        trafficFactor: trafficFactor,
        historicalDelays: const [2, 4, 3, 6],
      );
      final reward = 100 -
          (eta * 1.8) -
          (closureRisk * 20) -
          (congestionLevel * 35) +
          (route.distance * 0.4);
      if (reward > bestReward) {
        bestReward = reward;
        selected = route;
      }
    }
    return selected;
  }

  Map<String, dynamic> analyzeComputerVisionSignals({
    required int onboardPassengers,
    required int seatedPassengers,
    required bool abruptMotion,
    required bool harshBraking,
  }) {
    final occupancy = ((onboardPassengers / 60) * 100).clamp(0, 100).round();
    final crowdState = occupancy >= 85
        ? 'Crowded'
        : occupancy >= 55
            ? 'Moderate'
            : 'Low';
    final potentialIncident = abruptMotion || harshBraking;

    return {
      'occupancyPercent': occupancy,
      'standingPassengers': max(0, onboardPassengers - seatedPassengers),
      'crowdState': crowdState,
      'accidentRisk': potentialIncident ? 'High' : 'Normal',
      'safetyFlag': potentialIncident,
    };
  }

  Map<String, dynamic> predictNetworkFlowGnn({
    required int connectedStops,
    required int activeVehicles,
    required double avgRoadCongestion,
  }) {
    final pressureIndex = ((connectedStops * 0.3) +
            (activeVehicles * 0.7) +
            (avgRoadCongestion * 45))
        .round();
    final cityDelayMinutes = max(1, (pressureIndex * 0.12).round());
    return {
      'networkPressureIndex': pressureIndex,
      'predictedCityDelayMinutes': cityDelayMinutes,
      'movementTrend': pressureIndex > 60 ? 'Heavy' : 'Stable',
    };
  }

  int predictiveDelayDetection({
    required BusRoute route,
    required double congestion,
    required double weatherSeverity,
    required bool accidentReported,
  }) {
    final base = route.estimatedMinutes;
    final trafficDelay = (base * congestion * 0.7).round();
    final weatherDelay = (base * weatherSeverity * 0.4).round();
    final accidentDelay = accidentReported ? 7 + _random.nextInt(8) : 0;
    final prediction = trafficDelay + weatherDelay + accidentDelay;
    return prediction < 0 ? 0 : prediction;
  }

  int weatherAwareDelayPrediction({
    required String weather,
    required int baseMinutes,
  }) {
    final code = weather.toLowerCase().trim();
    double factor;
    if (code == 'rain') {
      factor = 0.18;
    } else if (code == 'fog') {
      factor = 0.25;
    } else if (code == 'storm') {
      factor = 0.35;
    } else if (code == 'clear') {
      factor = 0.05;
    } else {
      factor = 0.12;
    }
    return (baseMinutes * factor).round();
  }

  Map<String, dynamic> safetyMonitoring({
    required double currentSpeed,
    required double speedLimit,
    required bool harshCornering,
    required bool suddenBraking,
  }) {
    final overspeed = currentSpeed > speedLimit;
    final riskScore = (overspeed ? 45 : 10) +
        (harshCornering ? 25 : 0) +
        (suddenBraking ? 20 : 0) +
        _random.nextInt(8);

    return {
      'overspeed': overspeed,
      'riskScore': riskScore,
      'driverBehavior': riskScore >= 70
          ? 'Critical'
          : riskScore >= 40
              ? 'Warning'
              : 'Good',
    };
  }

  FleetStatusSnapshot fleetManagementSnapshot({
    required int totalBuses,
    required int activeBuses,
    required int delayedBuses,
    required int crowdedBuses,
  }) {
    final routeEfficiency = totalBuses == 0
        ? 0.0
        : ((activeBuses - delayedBuses).clamp(0, totalBuses) / totalBuses) *
            100.0;
    final avgDriverScore = 100 - (delayedBuses * 3.2) - (crowdedBuses * 1.4);

    return FleetStatusSnapshot(
      activeBuses: activeBuses,
      delayedBuses: delayedBuses,
      crowdedBuses: crowdedBuses,
      routeEfficiency: routeEfficiency.clamp(0.0, 100.0).toDouble(),
      avgDriverScore: avgDriverScore.clamp(35.0, 99.0).toDouble(),
    );
  }

  List<String> smartPassengerAlerts({
    required String routeNumber,
    required int etaMinutes,
    required int predictedDelay,
    required bool routeChanged,
  }) {
    return [
      'Route $routeNumber arriving in $etaMinutes minutes.',
      if (predictedDelay > 0)
        'Delay alert: approximately $predictedDelay minutes expected.',
      if (routeChanged) 'Route update: alternate corridor activated.',
      'Occupancy update available in real time.',
    ];
  }

  List<String> requiredTechnologyStack() {
    return const [
      'GPS / AIS-140 tracking devices',
      'IoT sensors for occupancy and safety',
      'Cloud backend with real-time data sync',
      'Live traffic and weather APIs',
      'Mobile app with role-based modules',
      'AI models for ETA, delay and optimization',
    ];
  }

  List<String> referenceTransitApps() {
    return const [
      'Moovit',
      'Chalo Bus App',
    ];
  }

  List<String> projectAiFeatureChecklist() {
    return const [
      'AI-based real-time public transport tracking',
      'Deep learning ETA prediction system',
      'AI traffic congestion prediction',
      'Smart route optimization using reinforcement learning',
      'Passenger crowd prediction using AI analytics',
      'AI driver behavior and safety monitoring',
      'Smart delay detection and automatic alerts',
      'AI-powered fleet management dashboard',
      'Weather-aware travel time prediction',
      'Intelligent passenger notification system',
    ];
  }

  TicketData generateQrTicket({
    required String passengerName,
    required String routeId,
    required int seatNumber,
  }) {
    final id = 'TKT-${DateTime.now().millisecondsSinceEpoch}-$seatNumber';
    final ticket = TicketData(
      ticketId: id,
      passengerName: passengerName,
      routeId: routeId,
      seatNumber: seatNumber,
      issuedAt: DateTime.now(),
    );
    _tickets[id] = ticket;
    occupySeat(routeId, seatNumber);
    _tripHistory.add({
      'type': 'ticket_generated',
      'ticketId': id,
      'routeId': routeId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return ticket;
  }

  bool verifyQrTicket(String ticketId) {
    final id = ticketId.trim();
    final ok = _tickets.containsKey(id);
    _tripHistory.add({
      'type': 'ticket_verified',
      'ticketId': id,
      'verified': ok,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return ok;
  }

  List<TicketData> allTickets() {
    final items = _tickets.values.toList();
    items.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return items;
  }

  List<TicketData> ticketsForRoute(String routeId) {
    return allTickets().where((t) => t.routeId == routeId).toList();
  }

  Map<String, dynamic> ticketReport(String routeId) {
    final list = ticketsForRoute(routeId);
    final total = list.length;
    final seats = list.map((e) => e.seatNumber).toSet().length;
    return {
      'routeId': routeId,
      'tickets': total,
      'uniqueSeats': seats,
      'estimatedRevenue': total * 120,
    };
  }

  void occupySeat(String busId, int seatNumber) {
    final seats = _occupiedSeatsByBus.putIfAbsent(busId, () => <int>{});
    seats.add(seatNumber);
  }

  void vacateSeat(String busId, int seatNumber) {
    _occupiedSeatsByBus.putIfAbsent(busId, () => <int>{}).remove(seatNumber);
  }

  int occupiedSeats(String busId) => _occupiedSeatsByBus[busId]?.length ?? 0;

  int availableSeats(String busId, {int capacity = 40}) {
    return capacity - occupiedSeats(busId);
  }

  bool isCrowded(String busId, {int capacity = 40}) {
    final ratio = occupiedSeats(busId) / capacity;
    return ratio >= 0.85;
  }

  int crowdPercentage(String busId, {int capacity = 40}) {
    final ratio = occupiedSeats(busId) / capacity;
    return (ratio * 100).round();
  }

  bool detectDriverFatigue({
    required int drivingMinutes,
    required double eyeClosureScore,
    required double steeringVariation,
  }) {
    final fatigueScore = (drivingMinutes / 60) * 0.4 +
        eyeClosureScore * 0.4 +
        steeringVariation * 0.2;
    return fatigueScore >= 1.4;
  }

  Map<String, dynamic> createEmergencyPayload({
    required String role,
    required String busId,
    required double latitude,
    required double longitude,
  }) {
    return <String, dynamic>{
      'role': role,
      'busId': busId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'sent_to_control_room_and_police',
    };
  }

  void shareDriverLocation({required String busId, required LatLng location}) {
    _liveBusLocations[busId] = location;
  }

  LatLng? busLocation(String busId) => _liveBusLocations[busId];

  void updateBusStatus({required String busId, required String status}) {
    notifications.value = [
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Bus Status Update',
        message: 'Bus $busId status changed to $status',
        createdAt: DateTime.now(),
      ),
      ...notifications.value,
    ].take(30).toList();
  }

  void publishRouteChange({required String routeNumber, required String note}) {
    notifications.value = [
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Route Change',
        message: 'Route $routeNumber: $note',
        createdAt: DateTime.now(),
      ),
      ...notifications.value,
    ].take(30).toList();
  }

  void addTripHistory({
    required String driverId,
    required String routeId,
    required String status,
  }) {
    _tripHistory.insert(0, {
      'driverId': driverId,
      'routeId': routeId,
      'status': status,
      'createdAt': DateTime.now().toIso8601String(),
    });
    if (_tripHistory.length > 100) {
      _tripHistory.removeLast();
    }
  }

  List<Map<String, dynamic>> getTripHistory() =>
      List.unmodifiable(_tripHistory);

  int predictPassengerDemand({
    required int hour,
    required bool isWeekend,
    required int historicalAvg,
  }) {
    int multiplier = 1;
    if (hour >= 8 && hour <= 10) multiplier += 1;
    if (hour >= 17 && hour <= 20) multiplier += 1;
    if (isWeekend) multiplier -= 1;
    final demand = historicalAvg * multiplier + _random.nextInt(15);
    return demand < 10 ? 10 : demand;
  }

  List<Map<String, dynamic>> buildRealtimeSchedule(List<BusRoute> routes) {
    final now = DateTime.now();
    return routes.take(20).map((route) {
      final eta = predictArrivalMinutes(
        route: route,
        trafficFactor: 0.25,
        historicalDelays: const [2, 3, 5],
      );
      final arrival = now.add(Duration(minutes: eta));
      return {
        'routeNumber': route.routeNumber,
        'from': route.source,
        'to': route.destination,
        'etaMinutes': eta,
        'arrivalTime':
            '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}',
      };
    }).toList();
  }

  RouteStop? nearestStop({
    required LatLng userLocation,
    required BusRoute route,
  }) {
    if (route.stops.isEmpty) return null;

    RouteStop best = route.stops.first;
    double minMeters = double.infinity;
    for (final stop in route.stops) {
      final distance = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        stop.latitude,
        stop.longitude,
      );
      if (distance < minMeters) {
        minMeters = distance;
        best = stop;
      }
    }
    return best;
  }

  void submitFeedback({
    required int rating,
    required String comment,
  }) {
    _feedback.add(<String, dynamic>{
      'rating': rating,
      'comment': comment,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic> feedbackAnalytics() {
    if (_feedback.isEmpty) {
      return <String, dynamic>{
        'count': 0,
        'averageRating': 0.0,
        'positive': 0,
        'negative': 0,
      };
    }

    final ratings = _feedback.map((e) => e['rating'] as int).toList();
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;

    int positive = 0;
    int negative = 0;
    for (final item in _feedback) {
      final text = (item['comment'] as String).toLowerCase();
      if (text.contains('good') ||
          text.contains('great') ||
          text.contains('excellent')) {
        positive++;
      }
      if (text.contains('bad') ||
          text.contains('late') ||
          text.contains('crowd')) {
        negative++;
      }
    }

    return <String, dynamic>{
      'count': _feedback.length,
      'averageRating': avg,
      'positive': positive,
      'negative': negative,
    };
  }

  String processVoiceCommand(String input) {
    final text = input.toLowerCase().trim();
    if (text.contains('arrival')) {
      return 'Next bus arrival is predicted in 7 to 10 minutes.';
    }
    if (text.contains('seat')) {
      return 'Current smart seat system shows seats updating in real time.';
    }
    if (text.contains('route')) {
      return 'Smart route optimization is active with live traffic conditions.';
    }
    if (text.contains('sos') || text.contains('emergency')) {
      return 'Emergency mode is ready. Press SOS to alert control room instantly.';
    }
    return 'Voice assistant did not understand. Try asking about arrival, seats, route, or SOS.';
  }
}
