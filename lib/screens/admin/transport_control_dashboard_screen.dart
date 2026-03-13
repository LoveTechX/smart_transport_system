import 'package:flutter/material.dart';

import '../../models/bus_routes_repository.dart';
import '../../services/smart_transport_ai_service.dart';

class TransportControlDashboardScreen extends StatefulWidget {
  const TransportControlDashboardScreen({super.key});

  @override
  State<TransportControlDashboardScreen> createState() =>
      _TransportControlDashboardScreenState();
}

class _TransportControlDashboardScreenState
    extends State<TransportControlDashboardScreen> {
  final service = SmartTransportAIService.instance;
  final routeNameController = TextEditingController();
  final scheduleController = TextEditingController();

  bool emergencyControlEnabled = true;
  int selectedPanel = 0;
  double rlClosureRisk = 0.2;
  double rlCongestionLevel = 0.35;
  int demandHour = 9;
  bool demandWeekend = false;
  String broadcastRouteId = BusRoutesRepository.allRoutes.first.id;
  bool broadcastRouteChanged = false;
  late List<String> managedRoutes;
  final List<String> managedSchedules = <String>[];

  final List<Map<String, dynamic>> mockDrivers = [
    {
      'id': 'D-101',
      'name': 'A. Sharma',
      'status': 'On Trip',
      'fatigue': 'Normal'
    },
    {
      'id': 'D-102',
      'name': 'R. Singh',
      'status': 'On Trip',
      'fatigue': 'Warning'
    },
    {
      'id': 'D-103',
      'name': 'M. Kumar',
      'status': 'Standby',
      'fatigue': 'Normal'
    },
  ];

  @override
  void initState() {
    super.initState();
    service.startNotificationFeed();
    managedRoutes = BusRoutesRepository.allRoutes
        .take(12)
        .map((e) => '${e.routeNumber} (${e.source}->${e.destination})')
        .toList();
    managedSchedules.addAll([
      '101 - 08:00 AM',
      '204 - 09:15 AM',
      '309 - 10:05 AM',
    ]);
  }

  @override
  void dispose() {
    routeNameController.dispose();
    scheduleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routes = BusRoutesRepository.allRoutes;
    final activeRoutes = routes.where((r) => r.isActive).length;
    final analytics = service.feedbackAnalytics();
    final avgRating = (analytics['averageRating'] as double).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Command Center'),
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
      drawer: MediaQuery.sizeOf(context).width >= 900
          ? null
          : Drawer(
              child: SafeArea(
                child: _buildCompactMenu(colorScheme),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final payload = service.createEmergencyPayload(
            role: 'admin',
            busId: 'control-room',
            latitude: 28.6139,
            longitude: 77.2090,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Control SOS sent: ${payload['status']}')),
          );
        },
        icon: const Icon(Icons.warning_amber_rounded),
        label: const Text('Control SOS'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showRail = constraints.maxWidth >= 900;

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
                        _buildHeroCard(
                          context,
                          routes.length,
                          activeRoutes,
                          avgRating,
                          analytics['count'].toString(),
                        ),
                        const SizedBox(height: 18),
                        if (!showRail) _buildTopSelector(colorScheme),
                        if (!showRail) const SizedBox(height: 18),
                        _buildPanelContent(context, routes, colorScheme),
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
      width: 108,
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
                Icons.admin_panel_settings_rounded,
                color: Color(0xFF271900),
                size: 30,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Admin',
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
                    icon: Icon(Icons.badge_outlined),
                    selectedIcon: Icon(Icons.badge_rounded),
                    label: Text('3'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.schedule_outlined),
                    selectedIcon: Icon(Icons.schedule_rounded),
                    label: Text('4'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.notifications_active_outlined),
                    selectedIcon: Icon(Icons.notifications_active_rounded),
                    label: Text('5'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights_rounded),
                    label: Text('6'),
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
    final items = _adminPanels();
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
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFF271900),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Admin Sequence',
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
    final items = _adminPanels();
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
              width: 126,
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
    int totalBuses,
    int activeRoutes,
    String avgRating,
    String feedbackCount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

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
            children: [
              _statusPill('Control Room', colorScheme.primary),
              _statusPill(
                'Emergency ${emergencyControlEnabled ? 'ON' : 'OFF'}',
                emergencyControlEnabled
                    ? const Color(0xFF26A69A)
                    : colorScheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Transport Oversight & Operations',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Same structured layout as driver/conductor with side-sequence control panels.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                context,
                icon: Icons.directions_bus_rounded,
                label: 'Total Buses',
                value: '$totalBuses',
                accentColor: colorScheme.primary,
              ),
              _metricCard(
                context,
                icon: Icons.alt_route_rounded,
                label: 'Active Routes',
                value: '$activeRoutes',
                accentColor: colorScheme.secondary,
              ),
              _metricCard(
                context,
                icon: Icons.star_rounded,
                label: 'Avg Rating',
                value: avgRating,
                accentColor: colorScheme.tertiary,
              ),
              _metricCard(
                context,
                icon: Icons.reviews_rounded,
                label: 'Feedback',
                value: feedbackCount,
                accentColor: const Color(0xFF90CAF9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent(
    BuildContext context,
    List<dynamic> routes,
    ColorScheme colorScheme,
  ) {
    switch (selectedPanel) {
      case 0:
        return _buildOverviewPanel(context, routes, colorScheme);
      case 1:
        return _buildRoutePanel(context, colorScheme);
      case 2:
        return _buildDriverPanel(context, colorScheme);
      case 3:
        return _buildSchedulePanel(context, colorScheme);
      case 4:
        return _buildAlertsPanel(context, colorScheme);
      case 5:
        return _buildAnalyticsPanel(context, colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewPanel(
    BuildContext context,
    List<dynamic> routes,
    ColorScheme colorScheme,
  ) {
    final delayedBuses = service.notifications.value
        .where((n) => n.title.toLowerCase().contains('delay'))
        .length;
    final crowdedBuses = routes.where((r) => service.isCrowded(r.id)).length;
    final fleet = service.fleetManagementSnapshot(
      totalBuses: routes.length,
      activeBuses: routes.where((r) => r.isActive).length,
      delayedBuses: delayedBuses,
      crowdedBuses: crowdedBuses,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '1. Dashboard Overview',
          'Core transport status and quick actions.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoBanner(
                  context,
                  icon: Icons.people_alt_rounded,
                  title: 'Passenger Panel Access',
                  subtitle: 'Open passenger view directly from control room.',
                  accentColor: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/passenger'),
                        icon: const Icon(Icons.people_rounded),
                        label: const Text('Passenger View'),
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
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Top Routes Snapshot',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                ...routes.take(4).map(
                      (r) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.route_rounded,
                            color: colorScheme.primary),
                        title: Text(
                            '${r.routeNumber} • ${r.source} -> ${r.destination}'),
                        subtitle: Text(
                          'ETA: ${r.estimatedMinutes} min • Fare: Rs ${r.fare}',
                        ),
                      ),
                    ),
                const Divider(height: 22),
                _infoBanner(
                  context,
                  icon: Icons.insights_rounded,
                  title: 'Fleet AI Snapshot',
                  subtitle:
                      'Efficiency: ${fleet.routeEfficiency.toStringAsFixed(1)}% • Delays: ${fleet.delayedBuses} • Driver Score: ${fleet.avgDriverScore.toStringAsFixed(1)}',
                  accentColor: colorScheme.tertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoutePanel(BuildContext context, ColorScheme colorScheme) {
    final recommended = service.optimizeRouteReinforcement(
      routes: BusRoutesRepository.allRoutes.take(15).toList(),
      trafficFactor: 0.25,
      closureRisk: rlClosureRisk,
      congestionLevel: rlCongestionLevel,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '2. Route Monitoring',
          'Add/remove routes and monitor live activity.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: routeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Add Bus Route',
                    hintText: 'e.g. 555 (City A->City B)',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final value = routeNameController.text.trim();
                      if (value.isEmpty) return;
                      setState(() {
                        managedRoutes.insert(0, value);
                        routeNameController.clear();
                      });
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Route'),
                  ),
                ),
                const SizedBox(height: 8),
                ...managedRoutes.take(6).map(
                      (routeItem) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.alt_route_rounded,
                            color: colorScheme.primary),
                        title: Text(routeItem),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() => managedRoutes.remove(routeItem));
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    ),
                const Divider(height: 22),
                Text(
                  'AI Route Re-Assignment',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Closure Risk: ${(rlClosureRisk * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Slider(
                  value: rlClosureRisk,
                  min: 0,
                  max: 1,
                  onChanged: (value) {
                    setState(() => rlClosureRisk = value);
                  },
                ),
                Text(
                  'Congestion Level: ${(rlCongestionLevel * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Slider(
                  value: rlCongestionLevel,
                  min: 0,
                  max: 1,
                  onChanged: (value) {
                    setState(() => rlCongestionLevel = value);
                  },
                ),
                _infoBanner(
                  context,
                  icon: Icons.auto_awesome_rounded,
                  title: 'Recommended Route (RL)',
                  subtitle:
                      '${recommended.routeNumber} • ${recommended.source} -> ${recommended.destination}',
                  accentColor: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverPanel(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '3. Driver Monitoring',
          'Track status and fatigue risk indicators.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...mockDrivers.map(
                  (d) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(Icons.badge_rounded, color: colorScheme.primary),
                    ),
                    title: Text('${d['id']} • ${d['name']}'),
                    subtitle: Text('Status: ${d['status']}'),
                    trailing: Text('${d['fatigue']}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulePanel(BuildContext context, ColorScheme colorScheme) {
    final predictedDemand = service.predictPassengerDemand(
      hour: demandHour,
      isWeekend: demandWeekend,
      historicalAvg: 42,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '4. Schedule Management',
          'Maintain and review schedule entries.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: scheduleController,
                  decoration: const InputDecoration(
                    labelText: 'Add Bus Schedule',
                    hintText: 'e.g. 420 - 06:45 PM',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final value = scheduleController.text.trim();
                      if (value.isEmpty) return;
                      setState(() {
                        managedSchedules.insert(0, value);
                        scheduleController.clear();
                      });
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: const Text('Add Schedule'),
                  ),
                ),
                const SizedBox(height: 8),
                ...managedSchedules.take(6).map(
                      (s) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.access_time_rounded,
                            color: colorScheme.primary),
                        title: Text(s),
                      ),
                    ),
                const Divider(height: 22),
                Text(
                  'Demand Forecast Planning',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hour: $demandHour:00',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Slider(
                  value: demandHour.toDouble(),
                  min: 0,
                  max: 23,
                  divisions: 23,
                  onChanged: (value) {
                    setState(() => demandHour = value.round());
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Weekend Demand Mode'),
                  value: demandWeekend,
                  onChanged: (value) {
                    setState(() => demandWeekend = value);
                  },
                ),
                _infoBanner(
                  context,
                  icon: Icons.trending_up_rounded,
                  title: 'Predicted Passenger Demand',
                  subtitle: '$predictedDemand passengers expected',
                  accentColor: colorScheme.tertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsPanel(BuildContext context, ColorScheme colorScheme) {
    final routeForAlerts = BusRoutesRepository.getRouteById(broadcastRouteId) ??
        BusRoutesRepository.allRoutes.first;
    final dynamicDelay = service.predictiveDelayDetection(
      route: routeForAlerts,
      congestion: rlCongestionLevel,
      weatherSeverity: 0.2,
      accidentReported: rlClosureRisk > 0.65,
    );
    final smartAlerts = service.smartPassengerAlerts(
      routeNumber: routeForAlerts.routeNumber,
      etaMinutes: routeForAlerts.estimatedMinutes,
      predictedDelay: dynamicDelay,
      routeChanged: broadcastRouteChanged,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '5. Alerts & Reports',
          'Notification feed, delay checks, and report generation.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ValueListenableBuilder<List<AppNotification>>(
                  valueListenable: service.notifications,
                  builder: (_, items, __) {
                    if (items.isEmpty) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Waiting for incoming alerts...'),
                      );
                    }

                    return Column(
                      children: items.take(5).map((item) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.notifications_active_rounded,
                              color: colorScheme.primary),
                          title: Text(item.title),
                          subtitle: Text(item.message),
                        );
                      }).toList(),
                    );
                  },
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Emergency Alerts',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Switch(
                      value: emergencyControlEnabled,
                      onChanged: (value) {
                        setState(() => emergencyControlEnabled = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final analytics = service.feedbackAnalytics();
                      final demand = service.predictPassengerDemand(
                        hour: DateTime.now().hour,
                        isWeekend: DateTime.now().weekday >= 6,
                        historicalAvg: 42,
                      );

                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Transport Report'),
                            content: Text(
                              'Routes: ${managedRoutes.length}\n'
                              'Schedules: ${managedSchedules.length}\n'
                              'Feedback Avg: ${(analytics['averageRating'] as double).toStringAsFixed(1)}\n'
                              'Predicted Demand: $demand passengers',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Generate Report & Statistics'),
                  ),
                ),
                const Divider(height: 24),
                DropdownButtonFormField<String>(
                  key: ValueKey(broadcastRouteId),
                  initialValue: broadcastRouteId,
                  decoration: const InputDecoration(
                    labelText: 'Smart Passenger Broadcast Route',
                  ),
                  items: BusRoutesRepository.allRoutes
                      .take(20)
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(
                            '${r.routeNumber} • ${r.source} -> ${r.destination}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => broadcastRouteId = value);
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Route Change Notice'),
                  value: broadcastRouteChanged,
                  onChanged: (value) {
                    setState(() => broadcastRouteChanged = value);
                  },
                ),
                _infoBanner(
                  context,
                  icon: Icons.campaign_rounded,
                  title: 'Smart Passenger Alert Bundle',
                  subtitle:
                      'Predicted delay: $dynamicDelay min • ${smartAlerts.length} alerts ready',
                  accentColor: colorScheme.primary,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/admin-analytics'),
                    icon: const Icon(Icons.insights_rounded),
                    label: const Text('Open Route Analytics Dashboard'),
                  ),
                ),
                const SizedBox(height: 8),
                ...smartAlerts.map(
                  (line) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.bolt_rounded),
                    title: Text(line),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsPanel(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '6. Route Analytics',
          'Compute and review occupancy, peak-hour, trip duration, and utilization metrics.',
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
                  icon: Icons.insights_rounded,
                  title: 'Admin Analytics Dashboard',
                  subtitle:
                      'Reads telemetry/trips/tickets and writes route summaries to analytics/{routeId}.',
                  accentColor: colorScheme.tertiary,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/admin-analytics'),
                    icon: const Icon(Icons.bar_chart_rounded),
                    label: const Text('Open Analytics Charts'),
                  ),
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
      width: 180,
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

  List<_AdminPanel> _adminPanels() {
    return const [
      _AdminPanel(
        title: 'Dashboard Overview',
        shortTitle: 'Overview',
        subtitle: 'System health and quick actions',
        icon: Icons.dashboard_outlined,
      ),
      _AdminPanel(
        title: 'Route Monitoring',
        shortTitle: 'Routes',
        subtitle: 'Manage and monitor routes',
        icon: Icons.route_outlined,
      ),
      _AdminPanel(
        title: 'Driver Monitoring',
        shortTitle: 'Drivers',
        subtitle: 'Status and fatigue checks',
        icon: Icons.badge_outlined,
      ),
      _AdminPanel(
        title: 'Schedule Management',
        shortTitle: 'Schedule',
        subtitle: 'Control bus timings',
        icon: Icons.schedule_outlined,
      ),
      _AdminPanel(
        title: 'Alerts & Reports',
        shortTitle: 'Alerts',
        subtitle: 'Notifications and analytics',
        icon: Icons.notifications_active_outlined,
      ),
      _AdminPanel(
        title: 'Route Analytics',
        shortTitle: 'Analytics',
        subtitle: 'Charts and KPI metrics',
        icon: Icons.insights_outlined,
      ),
    ];
  }
}

class _AdminPanel {
  final String title;
  final String shortTitle;
  final String subtitle;
  final IconData icon;

  const _AdminPanel({
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.icon,
  });
}
