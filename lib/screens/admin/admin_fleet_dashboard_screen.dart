import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/fleet_alert_service.dart';
import 'admin_alerts_screen.dart';

class AdminFleetDashboardScreen extends StatefulWidget {
  const AdminFleetDashboardScreen({super.key});

  @override
  State<AdminFleetDashboardScreen> createState() =>
      _AdminFleetDashboardScreenState();
}

class _AdminFleetDashboardScreenState extends State<AdminFleetDashboardScreen> {
  static const LatLng _fallbackCenter = LatLng(28.6139, 77.2090);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FleetAlertService _alertService = FleetAlertService();

  GoogleMapController? _mapController;
  bool _cameraInitialized = false;
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _alertService.start();
  }

  @override
  void dispose() {
    _alertService.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Fleet Monitoring'),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('alerts').snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Fleet Alerts',
                    icon: const Icon(Icons.notifications_rounded),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminAlertsScreen(),
                      ),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('telemetry').snapshots(),
        builder: (context, telemetrySnapshot) {
          if (telemetrySnapshot.hasError) {
            return _ErrorState(
              message: 'Failed to load telemetry data.',
              onRetry: () => setState(() {}),
            );
          }

          if (!telemetrySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final buses = telemetrySnapshot.data!.docs
              .map(_telemetryFromDoc)
              .whereType<_TelemetryBus>()
              .toList(growable: false);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('trips').snapshots(),
            builder: (context, tripSnapshot) {
              if (tripSnapshot.hasError) {
                return _ErrorState(
                  message: 'Failed to load trip occupancy data.',
                  onRetry: () => setState(() {}),
                );
              }

              final tripByVehicle = <String, _TripOccupancy>{};
              for (final doc in tripSnapshot.data?.docs ?? const []) {
                final trip = _tripFromDoc(doc);
                if (trip != null) {
                  tripByVehicle[trip.vehicleId] = trip;
                }
              }

              if (_selectedVehicleId != null &&
                  buses.every((bus) => bus.vehicleId != _selectedVehicleId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _selectedVehicleId = null);
                  }
                });
              }

              _maybeInitializeCamera(buses);

              final markers = _buildMarkers(
                buses: buses,
                tripByVehicle: tripByVehicle,
              );

              final selectedBus = buses.cast<_TelemetryBus?>().firstWhere(
                  (bus) => bus?.vehicleId == _selectedVehicleId,
                  orElse: () => null);
              final selectedTrip = selectedBus == null
                  ? null
                  : tripByVehicle[selectedBus.vehicleId];

              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _fallbackCenter,
                      zoom: 11,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _maybeInitializeCamera(buses);
                    },
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    markers: markers,
                  ),
                  if (buses.isEmpty)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Card(
                        color: colorScheme.surface.withValues(alpha: 0.94),
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'No telemetry records yet. Bus markers will appear automatically when data is available.',
                          ),
                        ),
                      ),
                    ),
                  if (selectedBus != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _BusDetailPanel(
                        vehicleId: selectedBus.vehicleId,
                        routeId: selectedTrip?.routeId,
                        occupancy: selectedTrip?.currentOccupancy,
                        availableSeats: selectedTrip?.availableSeats,
                        verifiedTicketCount: selectedTrip?.verifiedTicketCount,
                        speedKmh: selectedBus.speedKmh,
                        updatedAt: selectedBus.updatedAt,
                        onClose: () =>
                            setState(() => _selectedVehicleId = null),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _maybeInitializeCamera(List<_TelemetryBus> buses) {
    if (_cameraInitialized || _mapController == null || buses.isEmpty) {
      return;
    }

    _cameraInitialized = true;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(buses.first.latitude, buses.first.longitude),
          zoom: 13,
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers({
    required List<_TelemetryBus> buses,
    required Map<String, _TripOccupancy> tripByVehicle,
  }) {
    return buses.map((bus) {
      final trip = tripByVehicle[bus.vehicleId];
      final occupancyText =
          trip?.currentOccupancy?.toString() ?? 'unknown occupancy';
      final isSelected = bus.vehicleId == _selectedVehicleId;

      return Marker(
        markerId: MarkerId(bus.vehicleId),
        position: LatLng(bus.latitude, bus.longitude),
        rotation: bus.heading,
        flat: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: bus.vehicleId,
          snippet:
              'Speed ${bus.speedKmh.toStringAsFixed(1)} km/h | Occupancy $occupancyText',
        ),
        onTap: () {
          setState(() {
            _selectedVehicleId = bus.vehicleId;
          });
        },
      );
    }).toSet();
  }

  _TelemetryBus? _telemetryFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }

    final latitude = _toDouble(data['latitude']);
    final longitude = _toDouble(data['longitude']);
    if (latitude == null || longitude == null) {
      return null;
    }

    return _TelemetryBus(
      vehicleId: doc.id,
      latitude: latitude,
      longitude: longitude,
      speedKmh: _toDouble(data['speed']) ?? 0,
      heading: _normalizeHeading(_toDouble(data['heading']) ?? 0),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  _TripOccupancy? _tripFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }

    final vehicleId = data['vehicleId']?.toString().trim();
    if (vehicleId == null || vehicleId.isEmpty) {
      return null;
    }

    return _TripOccupancy(
      vehicleId: vehicleId,
      routeId: data['routeId']?.toString(),
      currentOccupancy: _toInt(data['currentOccupancy']),
      availableSeats: _toInt(data['availableSeats']),
      verifiedTicketCount: _toInt(data['verifiedTicketCount']),
    );
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  int? _toInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  double _normalizeHeading(double heading) {
    final normalized = heading % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }
}

class _TelemetryBus {
  const _TelemetryBus({
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.heading,
    required this.updatedAt,
  });

  final String vehicleId;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double heading;
  final DateTime? updatedAt;
}

class _TripOccupancy {
  const _TripOccupancy({
    required this.vehicleId,
    required this.routeId,
    required this.currentOccupancy,
    required this.availableSeats,
    required this.verifiedTicketCount,
  });

  final String vehicleId;
  final String? routeId;
  final int? currentOccupancy;
  final int? availableSeats;
  final int? verifiedTicketCount;
}

class _BusDetailPanel extends StatelessWidget {
  const _BusDetailPanel({
    required this.vehicleId,
    required this.routeId,
    required this.occupancy,
    required this.availableSeats,
    required this.verifiedTicketCount,
    required this.speedKmh,
    required this.updatedAt,
    required this.onClose,
  });

  final String vehicleId;
  final String? routeId;
  final int? occupancy;
  final int? availableSeats;
  final int? verifiedTicketCount;
  final double speedKmh;
  final DateTime? updatedAt;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus_filled, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vehicleId,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DetailRow(label: 'Route', value: routeId ?? '--'),
            _DetailRow(label: 'Occupancy', value: _displayInt(occupancy)),
            _DetailRow(
              label: 'Available Seats',
              value: _displayInt(availableSeats),
            ),
            _DetailRow(
              label: 'Verified Tickets',
              value: _displayInt(verifiedTicketCount),
            ),
            _DetailRow(
                label: 'Speed', value: '${speedKmh.toStringAsFixed(1)} km/h'),
            _DetailRow(
              label: 'Last Update',
              value: _formatDateTime(updatedAt),
            ),
          ],
        ),
      ),
    );
  }

  static String _displayInt(int? value) => value?.toString() ?? '--';

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '--';
    }

    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');

    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute:$second';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
