import 'package:flutter/material.dart';

import '../../services/smart_transport_ai_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final service = SmartTransportAIService.instance;

  @override
  void initState() {
    super.initState();
    service.startNotificationFeed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Real-Time Notifications')),
      body: ValueListenableBuilder<List<AppNotification>>(
        valueListenable: service.notifications,
        builder: (_, alerts, __) {
          if (alerts.isEmpty) {
            return const Center(child: Text('Waiting for live alerts...'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (_, index) {
              final item = alerts[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: Theme.of(context).cardColor,
                leading: const Icon(Icons.notifications_active),
                title: Text(item.title),
                subtitle: Text(item.message),
                trailing: Text(
                  '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: alerts.length,
          );
        },
      ),
    );
  }
}
