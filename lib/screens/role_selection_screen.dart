import 'package:flutter/material.dart';

import 'auth/conductor_login.dart';
import 'auth/driver_login.dart';
import 'auth/passenger_login.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Widget roleButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget screen,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => screen),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, size: 28, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
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
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.18),
                      colorScheme.secondary.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/app_logo_bus.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Smart Transport Hub',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Bus-line inspired access screen with route-focused dashboards for passengers, drivers, conductors, and control staff.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Live routes')),
                        Chip(label: Text('Smart ticketing')),
                        Chip(label: Text('Traffic insights')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Choose your access lane',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Pick the dashboard that matches your role in the transport system.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              roleButton(
                context,
                'Passenger',
                'Track buses, manage tickets, and receive live alerts.',
                Icons.person,
                const PassengerLoginScreen(),
                colorScheme.primary,
              ),
              roleButton(
                context,
                'Driver',
                'Navigation, route control, and live operating tools.',
                Icons.drive_eta,
                const DriverLoginScreen(),
                const Color(0xFFE53935),
              ),
              roleButton(
                context,
                'Conductor',
                'Boarding, ticket validation, and rider coordination.',
                Icons.confirmation_number,
                const ConductorLoginScreen(),
                const Color(0xFF26A69A),
              ),
              roleButton(
                context,
                'Admin',
                'Control center analytics and transport operations.',
                Icons.admin_panel_settings,
                const _AdminRedirectScreen(),
                const Color(0xFF90A4AE),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminRedirectScreen extends StatelessWidget {
  const _AdminRedirectScreen();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/admin-role-management');
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
