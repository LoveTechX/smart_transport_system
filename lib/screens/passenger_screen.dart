import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bus_routes_repository.dart';
import '../services/smart_transport_ai_service.dart';

class PassengerScreen extends StatelessWidget {
  const PassengerScreen({super.key});

  Future<void> _triggerSos(BuildContext context) async {
    final service = SmartTransportAIService.instance;
    final selected = BusRoutesRepository.allRoutes.first;

    double latitude = 28.6139;
    double longitude = 77.2090;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      latitude = position.latitude;
      longitude = position.longitude;
    } catch (_) {}

    final payload = service.createEmergencyPayload(
      role: 'passenger',
      busId: selected.id,
      latitude: latitude,
      longitude: longitude,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SOS sent (${payload['status']}) • Bus ${payload['busId']}',
          ),
        ),
      );
    }
  }

  Widget _navTile(
      BuildContext context, IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }

  Widget _quickCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required String route,
      required Color accentColor}) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Open',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: accentColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricChip(BuildContext context,
      {required IconData icon,
      required String label,
      required String value,
      required Color accentColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151F29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3948)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.labelMedium),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _quickCall(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final ok = await canLaunchUrl(uri);
    if (ok) {
      await launchUrl(uri);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calling not supported on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalRoutes = BusRoutesRepository.allRoutes.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passenger Command Center'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/chatbot'),
            icon: const Icon(Icons.smart_toy),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              ListTile(
                leading: Icon(Icons.directions_bus, color: colorScheme.primary),
                title: const Text('Passenger Navigation'),
                subtitle: const Text('Features arranged in sequence'),
              ),
              const Divider(),
              _navTile(context, Icons.location_on, '1. Live GPS Tracking',
                  '/trackbus'),
              _navTile(
                  context, Icons.alt_route, '2. Routes & Stops', '/routes'),
              _navTile(context, Icons.schedule, '3. Schedule', '/schedule'),
              _navTile(context, Icons.confirmation_number, '4. QR Ticketing',
                  '/tickets'),
              _navTile(context, Icons.notifications, '5. Real-Time Alerts',
                  '/alerts'),
              _navTile(context, Icons.auto_awesome, '6. AI Features',
                  '/ai-features'),
              _navTile(context, Icons.receipt, '7. Digital Ticket Booking',
                  '/tickets'),
              _navTile(context, Icons.event_seat, '8. Smart Seat Availability',
                  '/tickets'),
              _navTile(
                  context, Icons.mic, '9. Voice Assistant', '/ai-features'),
              _navTile(context, Icons.offline_bolt, '10. Offline Mode',
                  '/ai-features'),
              _navTile(context, Icons.feedback, '11. Feedback & Ratings',
                  '/ai-features'),
              _navTile(context, Icons.receipt, '12. My Tickets', '/mytickets'),
              _navTile(context, Icons.history, '13. History', '/history'),
              _navTile(context, Icons.person, '14. Profile', '/profile'),
              _navTile(context, Icons.help, '15. Help', '/help'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _triggerSos(context),
        icon: const Icon(Icons.warning),
        label: const Text('SOS'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF10161D),
              colorScheme.surface,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.18),
                    colorScheme.secondary.withValues(alpha: 0.18),
                    const Color(0xFF16202A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Passenger Command Center',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'A cleaner bus-network dashboard for live tracking, route discovery, AI ETA, tickets, and safety tools.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _metricChip(
                        context,
                        icon: Icons.alt_route,
                        label: 'Active routes',
                        value: '$totalRoutes',
                        accentColor: colorScheme.primary,
                      ),
                      _metricChip(
                        context,
                        icon: Icons.access_time_filled_rounded,
                        label: 'AI ETA',
                        value: 'Live',
                        accentColor: colorScheme.secondary,
                      ),
                      _metricChip(
                        context,
                        icon: Icons.notifications_active,
                        label: 'Alerts',
                        value: 'Real-time',
                        accentColor: colorScheme.tertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Travel Preferences',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Keep the dashboard tailored to your language before you start tracking buses.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<String>(
                      valueListenable:
                          SmartTransportAIService.instance.selectedLanguage,
                      builder: (_, language, __) {
                        return DropdownButtonFormField<String>(
                          key: ValueKey(language),
                          initialValue: language,
                          decoration: const InputDecoration(
                            labelText: 'Multi-language Support',
                          ),
                          items: SmartTransportAIService.instance
                              .supportedLanguages()
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              SmartTransportAIService
                                  .instance.selectedLanguage.value = value;
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _quickCard(
              context,
              title: 'Live GPS Bus Tracking',
              subtitle: 'Track current bus movement and ETA on map.',
              icon: Icons.location_searching,
              route: '/trackbus',
              accentColor: colorScheme.primary,
            ),
            _quickCard(
              context,
              title: 'AI Arrival Prediction',
              subtitle: 'Traffic + historical delay based prediction.',
              icon: Icons.analytics,
              route: '/ai-features',
              accentColor: colorScheme.secondary,
            ),
            _quickCard(
              context,
              title: 'QR Ticket & Seat Availability',
              subtitle: 'Generate secure QR ticket and check live seats.',
              icon: Icons.qr_code_2,
              route: '/tickets',
              accentColor: colorScheme.tertiary,
            ),
            _quickCard(
              context,
              title: 'Real-Time Notifications',
              subtitle: 'Arrival, delay and route-change alerts.',
              icon: Icons.notifications_active,
              route: '/alerts',
              accentColor: const Color(0xFFFF8A65),
            ),
            _quickCard(
              context,
              title: 'Nearby Stops & Route Search',
              subtitle:
                  'Use GPS to detect nearest stop and search routes/stops.',
              icon: Icons.near_me,
              route: '/routes',
              accentColor: const Color(0xFF64B5F6),
            ),
            _quickCard(
              context,
              title: 'Feedback, Voice & Offline',
              subtitle:
                  'Feedback analytics, voice assistant and offline route info.',
              icon: Icons.record_voice_over,
              route: '/ai-features',
              accentColor: const Color(0xFFAED581),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Safety & Quick Call',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _quickCall(context, '100'),
                            icon: const Icon(Icons.local_police),
                            label: const Text('Police'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _quickCall(context, '108'),
                            icon: const Icon(Icons.emergency),
                            label: const Text('Ambulance'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
