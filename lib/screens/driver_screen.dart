import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;

import '../models/bus_routes_repository.dart';
import '../services/smart_transport_ai_service.dart';
import '../services/telemetry_publisher_service.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final service = SmartTransportAIService.instance;
  final TelemetryPublisherService _telemetryPublisherService =
      TelemetryPublisherService();

  ll.LatLng location = const ll.LatLng(28.6139, 77.2090);
  bool tracking = false;
  String selectedRouteId = BusRoutesRepository.allRoutes.first.id;
  int passengerCount = 0;
  String busStatus = 'Running';
  int drivingMinutes = 0;
  double eyeClosureScore = 0.8;
  double steeringVariation = 0.4;
  double trafficFactor = 0.2;
  int selectedPanel = 0;

  @override
  void dispose() {
    // Ensure background telemetry stream is stopped when this widget unmounts.
    unawaited(_telemetryPublisherService.dispose());
    super.dispose();
  }

  Future<void> _handleStartTrip(dynamic route) async {
    try {
      await _telemetryPublisherService.startPublishing(vehicleId: route.id);
      if (!mounted) return;

      setState(() => tracking = true);
      service.shareDriverLocation(
        busId: route.id,
        location: gmaps.LatLng(
          location.latitude,
          location.longitude,
        ),
      );
      service.addTripHistory(
        driverId: 'D-101',
        routeId: route.id,
        status: 'Duty Started',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => tracking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start trip telemetry: $error')),
      );
    }
  }

  Future<void> _handleStopTrip(dynamic route) async {
    try {
      await _telemetryPublisherService.stopPublishing();
      if (!mounted) return;

      setState(() => tracking = false);
      service.addTripHistory(
        driverId: 'D-101',
        routeId: route.id,
        status: 'Duty Stopped',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not stop trip telemetry: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final route = BusRoutesRepository.getRouteById(selectedRouteId) ??
        BusRoutesRepository.allRoutes.first;
    final isFatigued = service.detectDriverFatigue(
      drivingMinutes: drivingMinutes,
      eyeClosureScore: eyeClosureScore,
      steeringVariation: steeringVariation,
    );
    final bestRoute = service.optimizeRoute(
      routes: BusRoutesRepository.allRoutes.take(12).toList(),
      trafficFactor: trafficFactor,
    );
    final tripHistory = service.getTripHistory().take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Command Center'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/help'),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/chatbot'),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
        ],
      ),
      drawer: MediaQuery.sizeOf(context).width >= 860
          ? null
          : Drawer(
              child: SafeArea(
                child: _buildCompactMenu(colorScheme),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final payload = service.createEmergencyPayload(
            role: 'driver',
            busId: route.id,
            latitude: location.latitude,
            longitude: location.longitude,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('SOS sent: ${payload['status']}')),
          );
        },
        icon: const Icon(Icons.warning_amber_rounded),
        label: const Text('SOS'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showRail = constraints.maxWidth >= 860;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0F141B),
                  colorScheme.surface,
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
            child: Row(
              children: [
                if (showRail) _buildRail(colorScheme),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCard(context, route, colorScheme),
                        const SizedBox(height: 18),
                        if (!showRail) _buildTopSelector(colorScheme),
                        if (!showRail) const SizedBox(height: 18),
                        _buildPanelContent(
                          context,
                          route,
                          bestRoute,
                          tripHistory,
                          isFatigued,
                          colorScheme,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRail(ColorScheme colorScheme) {
    return Container(
      width: 104,
      margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B24),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF293542)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.drive_eta_rounded,
                color: Color(0xFF271900),
                size: 30,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Driver',
              style: TextStyle(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: NavigationRail(
                backgroundColor: Colors.transparent,
                selectedIndex: selectedPanel,
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.9,
                indicatorColor: colorScheme.primary.withValues(alpha: 0.16),
                selectedIconTheme: IconThemeData(color: colorScheme.primary),
                unselectedIconTheme:
                    const IconThemeData(color: Color(0xFF93A2B2)),
                selectedLabelTextStyle: TextStyle(
                  color: colorScheme.primary,
                ),
                unselectedLabelTextStyle:
                    const TextStyle(color: Color(0xFF93A2B2)),
                onDestinationSelected: (index) {
                  setState(() => selectedPanel = index);
                },
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: Text('1'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.route_outlined),
                    selectedIcon: Icon(Icons.route_rounded),
                    label: Text('2'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.health_and_safety_outlined),
                    selectedIcon: Icon(Icons.health_and_safety_rounded),
                    label: Text('3'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.groups_2_outlined),
                    selectedIcon: Icon(Icons.groups_2_rounded),
                    label: Text('4'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history_rounded),
                    label: Text('5'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMenu(ColorScheme colorScheme) {
    final items = _driverPanels();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131B24),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.drive_eta_rounded,
                  color: Color(0xFF271900),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Driver Sequence',
                  style: TextStyle(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Icon(
              item.icon,
              color: selectedPanel == index
                  ? colorScheme.primary
                  : const Color(0xFF93A2B2),
            ),
            title: Text(item.title),
            subtitle: Text(item.subtitle),
            onTap: () {
              setState(() => selectedPanel = index);
              Navigator.pop(context);
            },
          );
        }),
      ],
    );
  }

  Widget _buildTopSelector(ColorScheme colorScheme) {
    final items = _driverPanels();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selectedPanel == index;

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => selectedPanel = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 112,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.16)
                    : const Color(0xFF131B24),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.45)
                      : const Color(0xFF293542),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.icon,
                    color: isSelected
                        ? colorScheme.primary
                        : const Color(0xFF93A2B2),
                  ),
                  const Spacer(),
                  Text(
                    '${index + 1}. ${item.shortTitle}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    dynamic route,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.secondary.withValues(alpha: 0.14),
            const Color(0xFF18212B),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B24),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Route ${route.routeNumber}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              _statusPill(
                busStatus,
                busStatus == 'Delayed'
                    ? colorScheme.secondary
                    : const Color(0xFF26A69A),
              ),
              _statusPill(
                tracking ? 'Trip Active' : 'Trip Paused',
                tracking ? colorScheme.primary : const Color(0xFF90A4AE),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${route.source} → ${route.destination}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'A cleaner driver interface with sequential tools on the side and focused operating panels on the right.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                context,
                icon: Icons.group,
                label: 'Passengers',
                value: '$passengerCount',
                accentColor: colorScheme.primary,
              ),
              _metricCard(
                context,
                icon: Icons.timer_outlined,
                label: 'Driving Time',
                value: '${drivingMinutes}m',
                accentColor: colorScheme.secondary,
              ),
              _metricCard(
                context,
                icon: Icons.alt_route,
                label: 'Best Route',
                value: route.routeNumber,
                accentColor: colorScheme.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent(
    BuildContext context,
    dynamic route,
    dynamic bestRoute,
    List<dynamic> tripHistory,
    bool isFatigued,
    ColorScheme colorScheme,
  ) {
    switch (selectedPanel) {
      case 0:
        return _buildOverviewPanel(context, route, colorScheme);
      case 1:
        return _buildOperationsPanel(context, route, colorScheme);
      case 2:
        return _buildSafetyPanel(context, isFatigued, colorScheme);
      case 3:
        return _buildCapacityPanel(context, route, bestRoute, colorScheme);
      case 4:
        return _buildHistoryPanel(context, tripHistory, colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewPanel(
    BuildContext context,
    dynamic route,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '1. Live Overview',
          'Map, trip controls, and instant route visibility.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 280,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: location,
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: location,
                              width: 96,
                              height: 96,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.2),
                                ),
                                child: Icon(
                                  Icons.directions_bus_rounded,
                                  size: 44,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async => _handleStartTrip(route),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start Trip'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async => _handleStopTrip(route),
                        icon: const Icon(Icons.pause_circle_outline_rounded),
                        label: const Text('Stop Trip'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationsPanel(
    BuildContext context,
    dynamic route,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '2. Route Operations',
          'Assigned route, status updates, and driver actions.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedRouteId),
                  initialValue: selectedRouteId,
                  decoration:
                      const InputDecoration(labelText: 'Assigned Route'),
                  items: BusRoutesRepository.allRoutes
                      .take(20)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            '${item.routeNumber} • ${item.source} → ${item.destination}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => selectedRouteId = value);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey(busStatus),
                  initialValue: busStatus,
                  decoration: const InputDecoration(labelText: 'Bus Status'),
                  items: const [
                    DropdownMenuItem(value: 'Running', child: Text('Running')),
                    DropdownMenuItem(value: 'Delayed', child: Text('Delayed')),
                    DropdownMenuItem(value: 'Stopped', child: Text('Stopped')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => busStatus = value);
                    service.updateBusStatus(busId: route.id, status: value);
                  },
                ),
                const SizedBox(height: 16),
                _infoBanner(
                  context,
                  icon: Icons.navigation_rounded,
                  title: 'Current Navigation Route',
                  subtitle: '${route.source} → ${route.destination}',
                  accentColor: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Passenger Count Monitoring: $passengerCount',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Slider(
                  value: passengerCount.toDouble(),
                  min: 0,
                  max: 80,
                  onChanged: (value) {
                    setState(() => passengerCount = value.round());
                  },
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      service.publishRouteChange(
                        routeNumber: route.routeNumber,
                        note: 'Temporary diversion due to traffic congestion',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Route change notification sent.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.campaign_rounded),
                    label: const Text('Send Route Change Notification'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyPanel(
    BuildContext context,
    bool isFatigued,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '3. Safety Monitoring',
          'Fatigue controls and driver wellness indicators.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoBanner(
                  context,
                  icon: isFatigued
                      ? Icons.warning_amber_rounded
                      : Icons.verified_user_rounded,
                  title:
                      isFatigued ? 'Fatigue Alert' : 'Driver Condition Stable',
                  subtitle: isFatigued
                      ? 'Reduce speed and take a rest break soon.'
                      : 'No immediate fatigue risk detected.',
                  accentColor:
                      isFatigued ? colorScheme.secondary : colorScheme.tertiary,
                ),
                const SizedBox(height: 18),
                Text(
                  'Driving Minutes: $drivingMinutes',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: drivingMinutes.toDouble(),
                  min: 0,
                  max: 600,
                  onChanged: (value) {
                    setState(() => drivingMinutes = value.round());
                  },
                ),
                Text(
                  'Eye Closure Score: ${eyeClosureScore.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: eyeClosureScore,
                  min: 0,
                  max: 2,
                  onChanged: (value) {
                    setState(() => eyeClosureScore = value);
                  },
                ),
                Text(
                  'Steering Variation: ${steeringVariation.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: steeringVariation,
                  min: 0,
                  max: 2,
                  onChanged: (value) {
                    setState(() => steeringVariation = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapacityPanel(
    BuildContext context,
    dynamic route,
    dynamic bestRoute,
    ColorScheme colorScheme,
  ) {
    final occupied = service.crowdPercentage(route.id);
    final seatsFree = service.availableSeats(route.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '4. Capacity & AI Insights',
          'Crowd level, free seats, and optimized routing.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        context,
                        icon: Icons.groups_rounded,
                        label: 'Occupied',
                        value: '$occupied%',
                        accentColor: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metricCard(
                        context,
                        icon: Icons.event_seat_rounded,
                        label: 'Seats Free',
                        value: '$seatsFree',
                        accentColor: colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Traffic Load: ${(trafficFactor * 100).round()}%',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: trafficFactor,
                  min: 0,
                  max: 1,
                  onChanged: (value) {
                    setState(() => trafficFactor = value);
                  },
                ),
                const SizedBox(height: 8),
                _infoBanner(
                  context,
                  icon: Icons.auto_awesome_rounded,
                  title: 'Suggested Fastest Route',
                  subtitle:
                      '${bestRoute.routeNumber} • ${bestRoute.source} → ${bestRoute.destination}',
                  accentColor: colorScheme.secondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryPanel(
    BuildContext context,
    List<dynamic> tripHistory,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '5. Trip History',
          'Recent duty activity and quick assistance access.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (tripHistory.isEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.history_toggle_off_rounded,
                      color: colorScheme.primary,
                    ),
                    title: const Text('No recent trip history'),
                    subtitle:
                        const Text('Start a trip to log driver activity.'),
                  )
                else
                  ...tripHistory.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.route_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                      title: Text('${item['status'] ?? item['type']}'),
                      subtitle: Text(
                        'Route: ${item['routeId'] ?? '-'} • Driver: ${item['driverId'] ?? 'D-101'}',
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/help'),
                        icon: const Icon(Icons.help_outline_rounded),
                        label: const Text('Help'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/chatbot'),
                        icon: const Icon(Icons.smart_toy_outlined),
                        label: const Text('AI Assistant'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF293542)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleSmall),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color),
      ),
    );
  }

  List<_DriverPanel> _driverPanels() {
    return const [
      _DriverPanel(
        title: 'Live Overview',
        shortTitle: 'Overview',
        subtitle: 'Map and trip controls',
        icon: Icons.dashboard_outlined,
      ),
      _DriverPanel(
        title: 'Route Operations',
        shortTitle: 'Route',
        subtitle: 'Status and route actions',
        icon: Icons.route_outlined,
      ),
      _DriverPanel(
        title: 'Safety Monitoring',
        shortTitle: 'Safety',
        subtitle: 'Fatigue and wellness',
        icon: Icons.health_and_safety_outlined,
      ),
      _DriverPanel(
        title: 'Capacity & AI',
        shortTitle: 'Capacity',
        subtitle: 'Crowd and optimization',
        icon: Icons.groups_2_outlined,
      ),
      _DriverPanel(
        title: 'Trip History',
        shortTitle: 'History',
        subtitle: 'Recent duty logs',
        icon: Icons.history_outlined,
      ),
    ];
  }
}

class _DriverPanel {
  final String title;
  final String shortTitle;
  final String subtitle;
  final IconData icon;

  const _DriverPanel({
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.icon,
  });
}
