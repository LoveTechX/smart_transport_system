import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/bus_route.dart';
import '../../models/bus_routes_repository.dart';
import '../../services/smart_transport_ai_service.dart';

class AIFeaturesScreen extends StatefulWidget {
  const AIFeaturesScreen({super.key});

  @override
  State<AIFeaturesScreen> createState() => _AIFeaturesScreenState();
}

class _AIFeaturesScreenState extends State<AIFeaturesScreen> {
  final service = SmartTransportAIService.instance;
  final TextEditingController voiceController = TextEditingController();
  final TextEditingController feedbackController = TextEditingController();

  BusRoute selectedRoute = BusRoutesRepository.allRoutes.first;
  double trafficFactor = 0.25;
  double weatherSeverity = 0.2;
  double congestion = 0.35;
  bool accidentReported = false;
  bool routeChanged = false;
  String weatherType = 'clear';
  double currentSpeed = 48;
  int selectedRating = 4;
  String voiceResponse = 'Ask: arrival, seat, route, or SOS';

  @override
  void initState() {
    super.initState();
    service.startNotificationFeed();
  }

  @override
  void dispose() {
    voiceController.dispose();
    feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final eta = service.predictArrivalMinutes(
      route: selectedRoute,
      trafficFactor: trafficFactor,
      historicalDelays: const [2, 5, 3, 4],
    );
    final lstmEta = service.predictEtaLstmBiLstm(
      route: selectedRoute,
      trafficFactor: trafficFactor,
      historicalDelays: const [2, 5, 3, 4],
      stopSequence: 4,
    );
    final xgboostTravelTime = service.predictTravelTimeXgboost(
      route: selectedRoute,
      trafficLoad: congestion,
      intersections: 14,
      avgStopTimeSeconds: 42,
      weatherSeverity: weatherSeverity,
    );
    final optimized = service.optimizeRoute(
      routes: BusRoutesRepository.allRoutes.take(10).toList(),
      trafficFactor: trafficFactor,
    );
    final rlRoute = service.optimizeRouteReinforcement(
      routes: BusRoutesRepository.allRoutes.take(12).toList(),
      trafficFactor: trafficFactor,
      closureRisk: routeChanged ? 0.55 : 0.15,
      congestionLevel: congestion,
    );
    final predictedDelay = service.predictiveDelayDetection(
      route: selectedRoute,
      congestion: congestion,
      weatherSeverity: weatherSeverity,
      accidentReported: accidentReported,
    );
    final weatherDelay = service.weatherAwareDelayPrediction(
      weather: weatherType,
      baseMinutes: selectedRoute.estimatedMinutes,
    );
    final cvData = service.analyzeComputerVisionSignals(
      onboardPassengers: 43,
      seatedPassengers: 31,
      abruptMotion: accidentReported,
      harshBraking: trafficFactor > 0.65,
    );
    final gnnFlow = service.predictNetworkFlowGnn(
      connectedStops: 58,
      activeVehicles: 36,
      avgRoadCongestion: congestion,
    );
    final safetyData = service.safetyMonitoring(
      currentSpeed: currentSpeed,
      speedLimit: 50,
      harshCornering: trafficFactor > 0.6,
      suddenBraking: accidentReported,
    );
    final fleet = service.fleetManagementSnapshot(
      totalBuses: 50,
      activeBuses: 44,
      delayedBuses: 7,
      crowdedBuses: 9,
    );
    final passengerAlerts = service.smartPassengerAlerts(
      routeNumber: selectedRoute.routeNumber,
      etaMinutes: lstmEta,
      predictedDelay: predictedDelay,
      routeChanged: routeChanged,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('AI Smart Features')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _card(
            title: 'AI Bus Arrival Prediction',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedRoute.id),
                  initialValue: selectedRoute.id,
                  decoration: const InputDecoration(labelText: 'Select Route'),
                  items: BusRoutesRepository.allRoutes
                      .take(20)
                      .map((r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(
                                '${r.routeNumber} • ${r.source} → ${r.destination}'),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() {
                      selectedRoute =
                          BusRoutesRepository.getRouteById(id) ?? selectedRoute;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Text('Traffic Load: ${(trafficFactor * 100).round()}%'),
                Slider(
                  value: trafficFactor,
                  min: 0,
                  max: 1,
                  onChanged: (v) => setState(() => trafficFactor = v),
                ),
                Text('Base ETA: $eta minutes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                        )),
                const SizedBox(height: 6),
                Text('LSTM / Bi-LSTM ETA: $lstmEta minutes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                        )),
                const SizedBox(height: 6),
                Text('XGBoost Travel Time: $xgboostTravelTime minutes'),
              ],
            ),
          ),
          _card(
            title: 'Smart Route Optimization',
            child: Text(
              'Fastest suggested route: ${optimized.routeNumber} (${optimized.source} → ${optimized.destination})',
            ),
          ),
          _card(
            title: 'Reinforcement Learning Route Optimization',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Road closure risk simulation'),
                    ),
                    Switch(
                      value: routeChanged,
                      onChanged: (v) => setState(() => routeChanged = v),
                    ),
                  ],
                ),
                Text(
                  'RL Suggested Route: ${rlRoute.routeNumber} (${rlRoute.source} → ${rlRoute.destination})',
                ),
              ],
            ),
          ),
          _card(
            title: 'Predictive Delay Detection + Weather-Aware AI',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Congestion: ${(congestion * 100).round()}%'),
                Slider(
                  value: congestion,
                  min: 0,
                  max: 1,
                  onChanged: (v) => setState(() => congestion = v),
                ),
                Text('Weather Severity: ${(weatherSeverity * 100).round()}%'),
                Slider(
                  value: weatherSeverity,
                  min: 0,
                  max: 1,
                  onChanged: (v) => setState(() => weatherSeverity = v),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(weatherType),
                  initialValue: weatherType,
                  decoration: const InputDecoration(labelText: 'Weather Type'),
                  items: const ['clear', 'rain', 'fog', 'storm']
                      .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => weatherType = v);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Accident Reported')),
                    Switch(
                      value: accidentReported,
                      onChanged: (v) => setState(() => accidentReported = v),
                    ),
                  ],
                ),
                Text('Predicted Delay: $predictedDelay min'),
                Text('Weather Delay Impact: $weatherDelay min'),
              ],
            ),
          ),
          _card(
            title: 'Computer Vision (YOLO/CNN) Crowd & Occupancy',
            child: Text(
              'Occupancy: ${cvData['occupancyPercent']}% • Crowd: ${cvData['crowdState']} • Standing: ${cvData['standingPassengers']} • Safety: ${cvData['accidentRisk']}',
            ),
          ),
          _card(
            title: 'Graph Neural Network (GNN) Network Flow',
            child: Text(
              'Network Pressure: ${gnnFlow['networkPressureIndex']} • City Delay: ${gnnFlow['predictedCityDelayMinutes']} min • Trend: ${gnnFlow['movementTrend']}',
            ),
          ),
          _card(
            title: 'AI Driver Safety Monitoring',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Speed: ${currentSpeed.toStringAsFixed(0)} km/h'),
                Slider(
                  value: currentSpeed,
                  min: 0,
                  max: 100,
                  onChanged: (v) => setState(() => currentSpeed = v),
                ),
                Text(
                  'Risk Score: ${safetyData['riskScore']} • Overspeed: ${safetyData['overspeed']} • Driver: ${safetyData['driverBehavior']}',
                ),
              ],
            ),
          ),
          _card(
            title: 'AI Fleet Management Dashboard Snapshot',
            child: Text(
              'Active: ${fleet.activeBuses} • Delayed: ${fleet.delayedBuses} • Crowded: ${fleet.crowdedBuses} • Efficiency: ${fleet.routeEfficiency.toStringAsFixed(1)}% • Driver Score: ${fleet.avgDriverScore.toStringAsFixed(1)}',
            ),
          ),
          _card(
            title: 'Smart Passenger Alerts',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: passengerAlerts
                  .map((alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $alert'),
                      ))
                  .toList(),
            ),
          ),
          _card(
            title: 'Smart Bus Stop Detection',
            child: Builder(
              builder: (_) {
                final stop = service.nearestStop(
                  userLocation: const LatLng(28.6139, 77.2090),
                  route: selectedRoute,
                );
                return Text(
                  stop == null
                      ? 'No nearby stop detected'
                      : 'Nearest stop: ${stop.stopName} (ETA point: ${stop.arrivalMinutes} min)',
                );
              },
            ),
          ),
          _card(
            title: 'Voice Assistant Support',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: voiceController,
                  decoration: const InputDecoration(
                    labelText: 'Type voice command simulation',
                    hintText: 'e.g. next arrival',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      voiceResponse =
                          service.processVoiceCommand(voiceController.text);
                    });
                  },
                  child: const Text('Run Voice Assistant'),
                ),
                const SizedBox(height: 8),
                Text(voiceResponse),
              ],
            ),
          ),
          _card(
            title: 'Offline Mode Support',
            child: ValueListenableBuilder<bool>(
              valueListenable: service.offlineMode,
              builder: (_, isOffline, __) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(isOffline
                        ? 'Offline mode ON: route & stop cache active'
                        : 'Offline mode OFF: live sync active'),
                  ),
                  Switch(
                    value: isOffline,
                    onChanged: (v) => service.offlineMode.value = v,
                  ),
                ],
              ),
            ),
          ),
          _card(
            title: 'Passenger Feedback Analytics',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  key: ValueKey(selectedRating),
                  initialValue: selectedRating,
                  decoration: const InputDecoration(labelText: 'Rating'),
                  items: [1, 2, 3, 4, 5]
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text('$r Star')))
                      .toList(),
                  onChanged: (v) => setState(() => selectedRating = v ?? 4),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    labelText: 'Feedback',
                    hintText: 'good service / late bus / crowd issue ...',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    service.submitFeedback(
                      rating: selectedRating,
                      comment: feedbackController.text,
                    );
                    setState(() {});
                  },
                  child: const Text('Submit Feedback'),
                ),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final analytics = service.feedbackAnalytics();
                  return Text(
                    'Total: ${analytics['count']} • Avg: ${(analytics['averageRating'] as double).toStringAsFixed(1)} • Positive: ${analytics['positive']} • Negative: ${analytics['negative']}',
                  );
                }),
              ],
            ),
          ),
          _card(
            title: 'Required Technology Stack',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: service
                  .requiredTechnologyStack()
                  .map((item) => Text('• $item'))
                  .toList(),
            ),
          ),
          _card(
            title: 'Reference Apps + Project AI Checklist',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reference: ${service.referenceTransitApps().join(', ')}',
                ),
                const SizedBox(height: 8),
                ...service
                    .projectAiFeatureChecklist()
                    .map((item) => Text('• $item')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
