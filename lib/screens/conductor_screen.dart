import 'package:flutter/material.dart';

import '../models/bus_routes_repository.dart';
import '../services/smart_transport_ai_service.dart';

class ConductorScreen extends StatefulWidget {
  const ConductorScreen({super.key});

  @override
  State<ConductorScreen> createState() => _ConductorScreenState();
}

class _ConductorScreenState extends State<ConductorScreen> {
  final service = SmartTransportAIService.instance;
  final qrController = TextEditingController();
  final walkInPassengerController =
      TextEditingController(text: 'Walk-in Passenger');
  final voiceCommandController = TextEditingController();

  String routeId = BusRoutesRepository.allRoutes.first.id;
  String verifyResult = 'Waiting for scan';
  String voiceResult = 'Ask about arrival, seat, route, or SOS';
  int seatToToggle = 1;
  int onboardPassengers = 18;
  int seatedPassengers = 14;
  bool abruptMotion = false;
  bool harshBraking = false;
  int selectedPanel = 0;

  @override
  void dispose() {
    qrController.dispose();
    walkInPassengerController.dispose();
    voiceCommandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final route = BusRoutesRepository.getRouteById(routeId) ??
        BusRoutesRepository.allRoutes.first;
    final tickets = service.ticketsForRoute(route.id);
    final report = service.ticketReport(route.id);
    final crowdPercentage = service.crowdPercentage(route.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conductor Command Center'),
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
            role: 'conductor',
            busId: route.id,
            latitude: 28.6139,
            longitude: 77.2090,
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
                        _buildHeroCard(context, route, report, crowdPercentage),
                        const SizedBox(height: 18),
                        if (!showRail) _buildTopSelector(colorScheme),
                        if (!showRail) const SizedBox(height: 18),
                        _buildPanelContent(
                          context,
                          route,
                          tickets,
                          report,
                          crowdPercentage,
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
                Icons.confirmation_number_rounded,
                color: Color(0xFF271900),
                size: 30,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Conductor',
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
                    icon: Icon(Icons.qr_code_scanner_outlined),
                    selectedIcon: Icon(Icons.qr_code_scanner_rounded),
                    label: Text('1'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.event_seat_outlined),
                    selectedIcon: Icon(Icons.event_seat_rounded),
                    label: Text('2'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: Text('3'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.groups_2_outlined),
                    selectedIcon: Icon(Icons.groups_2_rounded),
                    label: Text('4'),
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
    final items = _panels();
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
                  Icons.confirmation_number_rounded,
                  color: Color(0xFF271900),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Conductor Sequence',
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
    final items = _panels();
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
    dynamic route,
    Map<String, dynamic> report,
    int crowdPercentage,
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
              _statusPill('Route ${route.routeNumber}', colorScheme.primary),
              _statusPill(
                service.isCrowded(route.id) ? 'Crowded' : 'Balanced',
                service.isCrowded(route.id)
                    ? colorScheme.secondary
                    : colorScheme.tertiary,
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
            'Ticket control, seat updates, and crowd handling are now arranged in the same side-sequence style as the driver dashboard.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                context,
                icon: Icons.confirmation_number_rounded,
                label: 'Tickets',
                value: '${report['tickets']}',
                accentColor: colorScheme.primary,
              ),
              _metricCard(
                context,
                icon: Icons.event_seat_rounded,
                label: 'Seats Free',
                value: '${service.availableSeats(route.id)}',
                accentColor: colorScheme.tertiary,
              ),
              _metricCard(
                context,
                icon: Icons.groups_2_rounded,
                label: 'Crowd Level',
                value: '$crowdPercentage%',
                accentColor: colorScheme.secondary,
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
    List<dynamic> tickets,
    Map<String, dynamic> report,
    int crowdPercentage,
    ColorScheme colorScheme,
  ) {
    switch (selectedPanel) {
      case 0:
        return _buildTicketPanel(context, route, colorScheme);
      case 1:
        return _buildSeatPanel(context, route, colorScheme);
      case 2:
        return _buildPassengerPanel(
            context, route, tickets, report, colorScheme);
      case 3:
        return _buildCrowdPanel(context, route, crowdPercentage, colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTicketPanel(
    BuildContext context,
    dynamic route,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '1. QR Verification',
          'Verify tickets or issue a new pass for walk-in passengers.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(routeId),
                  initialValue: routeId,
                  decoration: const InputDecoration(labelText: 'Current Route'),
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
                    setState(() => routeId = value ?? routeId);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: qrController,
                  decoration: const InputDecoration(
                    labelText: 'Scan/Enter QR Ticket ID',
                    hintText: 'TKT-xxxxxxxxxxxx-12',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final ok = service.verifyQrTicket(qrController.text);
                      setState(() {
                        verifyResult =
                            ok ? 'Ticket Verified' : 'Invalid Ticket';
                      });
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan & Verify'),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: walkInPassengerController,
                  decoration: const InputDecoration(
                    labelText: 'Generate New Ticket - Passenger Name',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final ticket = service.generateQrTicket(
                        passengerName:
                            walkInPassengerController.text.trim().isEmpty
                                ? 'Walk-in Passenger'
                                : walkInPassengerController.text.trim(),
                        routeId: route.id,
                        seatNumber: seatToToggle,
                      );
                      setState(() {
                        verifyResult = 'Ticket generated: ${ticket.ticketId}';
                      });
                    },
                    icon: const Icon(Icons.add_card_rounded),
                    label: const Text('Generate New Ticket'),
                  ),
                ),
                const SizedBox(height: 14),
                _infoBanner(
                  context,
                  icon: Icons.verified_rounded,
                  title: 'Verification Result',
                  subtitle: verifyResult,
                  accentColor: verifyResult.contains('Invalid')
                      ? colorScheme.secondary
                      : colorScheme.primary,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: voiceCommandController,
                  decoration: const InputDecoration(
                    labelText: 'Voice Assistant Command',
                    hintText: 'e.g. arrival, seat status, route, SOS',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final input = voiceCommandController.text.trim();
                      if (input.isEmpty) return;
                      setState(() {
                        voiceResult = service.processVoiceCommand(input);
                      });
                    },
                    icon: const Icon(Icons.keyboard_voice_rounded),
                    label: const Text('Run Voice Assistant'),
                  ),
                ),
                const SizedBox(height: 10),
                _infoBanner(
                  context,
                  icon: Icons.record_voice_over_rounded,
                  title: 'Assistant Response',
                  subtitle: voiceResult,
                  accentColor: colorScheme.tertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeatPanel(
    BuildContext context,
    dynamic route,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '2. Seat Control',
          'Update occupied and available seats with quick actions.',
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
                        icon: Icons.airline_seat_recline_normal_rounded,
                        label: 'Occupied',
                        value: '${service.occupiedSeats(route.id)} / 40',
                        accentColor: colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metricCard(
                        context,
                        icon: Icons.event_seat_rounded,
                        label: 'Available',
                        value: '${service.availableSeats(route.id)} / 40',
                        accentColor: colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Selected Seat: $seatToToggle',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: seatToToggle.toDouble(),
                  min: 1,
                  max: 40,
                  divisions: 39,
                  onChanged: (value) {
                    setState(() => seatToToggle = value.round());
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          service.occupySeat(route.id, seatToToggle);
                          setState(() {});
                        },
                        icon: const Icon(Icons.person_rounded),
                        label: const Text('Mark Occupied'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          service.vacateSeat(route.id, seatToToggle);
                          setState(() {});
                        },
                        icon: const Icon(Icons.event_seat_rounded),
                        label: const Text('Mark Available'),
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

  Widget _buildPassengerPanel(
    BuildContext context,
    dynamic route,
    List<dynamic> tickets,
    Map<String, dynamic> report,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '3. Passenger Desk',
          'Live tickets, trip reports, and recent ticket activity.',
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
                  icon: Icons.receipt_long_rounded,
                  title: 'Trip Ticket Report',
                  subtitle:
                      'Tickets: ${report['tickets']} • Seats: ${report['uniqueSeats']} • Revenue: ₹${report['estimatedRevenue']}',
                  accentColor: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Passenger Ticket List',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (tickets.isEmpty)
                  const Text('No passenger tickets yet for this route.')
                else
                  ...tickets.take(6).map(
                        (ticket) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.confirmation_number_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                          title: Text(ticket.ticketId),
                          subtitle: Text(
                            '${ticket.passengerName} • Seat ${ticket.seatNumber}',
                          ),
                        ),
                      ),
                const Divider(height: 24),
                Text(
                  'Ticket History Tracking',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...service.getTripHistory().take(4).map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.history_rounded),
                        title: Text('${item['type'] ?? item['status']}'),
                        subtitle: Text(
                            '${item['ticketId'] ?? item['routeId'] ?? ''}'),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCrowdPanel(
    BuildContext context,
    dynamic route,
    int crowdPercentage,
    ColorScheme colorScheme,
  ) {
    final vision = service.analyzeComputerVisionSignals(
      onboardPassengers: onboardPassengers,
      seatedPassengers: seatedPassengers,
      abruptMotion: abruptMotion,
      harshBraking: harshBraking,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          '4. Crowd Detection',
          'Crowd level alerts and route-side operating signals.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metricCard(
                  context,
                  icon: Icons.groups_2_rounded,
                  label: 'Crowd Level',
                  value: '$crowdPercentage%',
                  accentColor: service.isCrowded(route.id)
                      ? colorScheme.secondary
                      : colorScheme.tertiary,
                ),
                const SizedBox(height: 16),
                _infoBanner(
                  context,
                  icon: service.isCrowded(route.id)
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
                  title: service.isCrowded(route.id)
                      ? 'Overcrowding Alert'
                      : 'Safe Threshold',
                  subtitle: service.isCrowded(route.id)
                      ? 'Alert sent to authorities: bus overcrowded'
                      : 'Bus crowd is under the safe threshold.',
                  accentColor: service.isCrowded(route.id)
                      ? colorScheme.secondary
                      : colorScheme.tertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Onboard Passengers: $onboardPassengers',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: onboardPassengers.toDouble(),
                  min: 0,
                  max: 60,
                  onChanged: (value) {
                    setState(() {
                      onboardPassengers = value.round();
                      if (seatedPassengers > onboardPassengers) {
                        seatedPassengers = onboardPassengers;
                      }
                    });
                  },
                ),
                Text(
                  'Seated Passengers: $seatedPassengers',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: seatedPassengers.toDouble(),
                  min: 0,
                  max: onboardPassengers.toDouble(),
                  onChanged: (value) {
                    setState(() => seatedPassengers = value.round());
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Abrupt Motion Detected'),
                  value: abruptMotion,
                  onChanged: (value) => setState(() => abruptMotion = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Harsh Braking Detected'),
                  value: harshBraking,
                  onChanged: (value) => setState(() => harshBraking = value),
                ),
                _infoBanner(
                  context,
                  icon: vision['safetyFlag'] == true
                      ? Icons.report_problem_rounded
                      : Icons.shield_rounded,
                  title: 'AI Safety Vision',
                  subtitle:
                      'State: ${vision['crowdState']} • Standing: ${vision['standingPassengers']} • Risk: ${vision['accidentRisk']}',
                  accentColor: vision['safetyFlag'] == true
                      ? colorScheme.secondary
                      : colorScheme.primary,
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

  List<_ConductorPanel> _panels() {
    return const [
      _ConductorPanel(
        title: 'QR Verification',
        shortTitle: 'Verify',
        subtitle: 'Scan or issue tickets',
        icon: Icons.qr_code_scanner_outlined,
      ),
      _ConductorPanel(
        title: 'Seat Control',
        shortTitle: 'Seats',
        subtitle: 'Manage occupancy',
        icon: Icons.event_seat_outlined,
      ),
      _ConductorPanel(
        title: 'Passenger Desk',
        shortTitle: 'Desk',
        subtitle: 'Tickets and reports',
        icon: Icons.receipt_long_outlined,
      ),
      _ConductorPanel(
        title: 'Crowd Detection',
        shortTitle: 'Crowd',
        subtitle: 'Monitor crowd load',
        icon: Icons.groups_2_outlined,
      ),
    ];
  }
}

class _ConductorPanel {
  final String title;
  final String shortTitle;
  final String subtitle;
  final IconData icon;

  const _ConductorPanel({
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.icon,
  });
}
