import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/fleet_alert.dart';

/// Real-time alert feed for the admin dashboard.
///
/// Streams the `alerts` collection ordered by `timestamp` descending.
/// Each alert is shown as a colour-coded card.  Admins can dismiss
/// (delete) individual alerts with the trailing close button.
class AdminAlertsScreen extends StatelessWidget {
  const AdminAlertsScreen({super.key});

  static final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Alerts'),
        actions: [
          IconButton(
            tooltip: 'Dismiss all alerts',
            icon: const Icon(Icons.playlist_remove_rounded),
            onPressed: () => _confirmDismissAll(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('alerts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredMessage(
              icon: Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              message: 'Failed to load alerts.',
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data!.docs
              .map(FleetAlert.fromDoc)
              .whereType<FleetAlert>()
              .toList(growable: false);

          if (alerts.isEmpty) {
            return const _CenteredMessage(
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green,
              message: 'No active alerts. Fleet is operating normally.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _AlertCard(
                alert: alerts[index],
                onDismiss: () => _dismissAlert(alerts[index].alertId),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _dismissAlert(String alertId) {
    return _firestore
        .collection('alerts')
        .doc(alertId)
        .delete()
        .catchError((Object _) {});
  }

  Future<void> _confirmDismissAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dismiss all alerts?'),
        content: const Text(
          'All current alert documents will be deleted from Firestore. '
          'Active conditions will re-raise alerts automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dismiss all'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final snap = await _firestore.collection('alerts').get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

// ─── Alert card ─────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onDismiss});

  final FleetAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconAndColor(alert.severity, alert.type);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          alert.message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _SeverityChip(severity: alert.severity, color: color),
              const SizedBox(width: 8),
              Text(
                _formatTimestamp(alert.timestamp),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: 'Dismiss',
          icon: const Icon(Icons.close_rounded),
          iconSize: 18,
          onPressed: onDismiss,
        ),
      ),
    );
  }

  static (IconData, Color) _iconAndColor(
      AlertSeverity severity, FleetAlertType type) {
    // Colour is driven by severity; icon by type.
    final color = switch (severity) {
      AlertSeverity.critical => Colors.red,
      AlertSeverity.warning => Colors.orange,
      AlertSeverity.info => Colors.blue,
    };

    final icon = switch (type) {
      FleetAlertType.overspeed => Icons.speed_rounded,
      FleetAlertType.vehicleOffline => Icons.signal_wifi_off_rounded,
      FleetAlertType.crowdedBus => Icons.people_alt_rounded,
    };

    return (icon, color);
  }

  static String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} $h:$m:$s';
  }
}

// ─── Severity chip ───────────────────────────────────────────────────────────

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity, required this.color});

  final AlertSeverity severity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = switch (severity) {
      AlertSeverity.critical => 'CRITICAL',
      AlertSeverity.warning => 'WARNING',
      AlertSeverity.info => 'INFO',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Centred placeholder ─────────────────────────────────────────────────────

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
