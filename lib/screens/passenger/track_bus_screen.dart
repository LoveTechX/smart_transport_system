import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/bus_route.dart';
import '../../models/bus_routes_repository.dart';

class TrackBusScreen extends StatefulWidget {
  final String? routeId;

  const TrackBusScreen({super.key, this.routeId});

  @override
  State<TrackBusScreen> createState() => _TrackBusScreenState();
}

class _TrackBusScreenState extends State<TrackBusScreen> {
  GoogleMapController? mapController;
  BusRoute? selectedRoute;
  MapType _mapType = MapType.normal;
  final Set<Marker> _routeMarkers = {};
  Set<Polyline> polylines = {};
  LatLng? currentLocation;
  bool _isLoading = true;
  bool _mapReady = false;
  double _tilt = 0.0;
  double _bearing = 0.0;
  double _zoom = 14.0;
  Timer? _busAnimationTimer;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _telemetryStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _etaStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _routeHeatmapStream;
  Map<String, String> _heatmapSegments = {};
  String? _lastTelemetrySignature;

  final ValueNotifier<_LiveTelemetryState> _liveTelemetryNotifier =
      ValueNotifier<_LiveTelemetryState>(const _LiveTelemetryState());
  final ValueNotifier<_EtaDisplayState> _etaNotifier =
      ValueNotifier<_EtaDisplayState>(const _EtaDisplayState());

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Load route data
    if (widget.routeId != null) {
      selectedRoute = BusRoutesRepository.getRouteById(widget.routeId!);
    } else {
      selectedRoute = BusRoutesRepository.allRoutes.first;
    }

    // Get current location
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentLocation = LatLng(position.latitude, position.longitude);
    } catch (_) {
      currentLocation = LatLng(28.6139, 77.2090); // Default to Delhi
    }

    _configureTelemetryStream();
    _updateRouteOverlays();
    setState(() => _isLoading = false);
  }

  void _configureTelemetryStream() {
    final vehicleId = selectedRoute?.id ?? widget.routeId;
    if (vehicleId == null || vehicleId.trim().isEmpty) {
      _telemetryStream = null;
      _etaStream = null;
      _etaNotifier.value = const _EtaDisplayState(
        statusMessage: 'ETA prediction is unavailable for this route.',
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;
    _telemetryStream =
        firestore.collection('telemetry').doc(vehicleId.trim()).snapshots();
    _etaStream = firestore.collection('etas').doc(vehicleId.trim()).snapshots();
    _routeHeatmapStream = firestore
        .collection('routeCrowdHeatmap')
        .doc(selectedRoute?.id ?? widget.routeId)
        .snapshots();
  }

  void _updateRouteOverlays() {
    if (selectedRoute == null) return;

    _routeMarkers.clear();
    polylines.clear();
    final stops = selectedRoute!.stops;

    // Start marker (green)
    if (stops.isNotEmpty) {
      _routeMarkers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(stops.first.latitude, stops.first.longitude),
          infoWindow: InfoWindow(
            title: 'Start: ${stops.first.stopName}',
            snippet: 'Route starts here',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // Stop markers (blue)
    for (int i = 1; i < stops.length - 1; i++) {
      final stop = stops[i];
      _routeMarkers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(stop.latitude, stop.longitude),
          infoWindow: InfoWindow(
            title: stop.stopName,
            snippet: 'ETA: ${stop.arrivalMinutes} mins',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // End marker (red)
    if (stops.isNotEmpty) {
      _routeMarkers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(stops.last.latitude, stops.last.longitude),
          infoWindow: InfoWindow(
            title: 'End: ${stops.last.stopName}',
            snippet: 'Route ends here',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Draw per-segment polylines coloured by crowd heatmap
    for (int i = 0; i < stops.length - 1; i++) {
      final stopA = stops[i];
      final stopB = stops[i + 1];
      final segmentId = '${stopA.id}_to_${stopB.id}';
      print('Generated segmentId: $segmentId');
      final crowdLevel = _heatmapSegments[segmentId];
      final segmentColor = crowdLevel != null
          ? _colorForCrowd(crowdLevel)
          : const Color(0xFFFFC107);
      polylines.add(
        Polyline(
          polylineId: PolylineId(segmentId),
          points: [
            LatLng(stopA.latitude, stopA.longitude),
            LatLng(stopB.latitude, stopB.longitude),
          ],
          color: segmentColor,
          width: 6,
          geodesic: true,
        ),
      );
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    _mapReady = true;
    if (selectedRoute != null && selectedRoute!.stops.isNotEmpty) {
      _fitRouteBounds();
    }
  }

  void _fitRouteBounds() {
    if (!_mapReady || mapController == null) return;
    if (selectedRoute == null || selectedRoute!.stops.isEmpty) return;

    final stops = selectedRoute!.stops;
    double minLat = stops.first.latitude;
    double maxLat = stops.first.latitude;
    double minLng = stops.first.longitude;
    double maxLng = stops.first.longitude;

    for (final stop in stops) {
      minLat = minLat > stop.latitude ? stop.latitude : minLat;
      maxLat = maxLat < stop.latitude ? stop.latitude : maxLat;
      minLng = minLng > stop.longitude ? stop.longitude : minLng;
      maxLng = maxLng < stop.longitude ? stop.longitude : maxLng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  void _updateCamera() {
    if (!_mapReady || mapController == null) return;
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentLocation ?? const LatLng(28.6139, 77.2090),
          zoom: _zoom,
          tilt: _tilt,
          bearing: _bearing,
        ),
      ),
    );
  }

  void _scheduleTelemetryProcessing(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _processTelemetrySnapshot(snapshot);
    });
  }

  void _processTelemetrySnapshot(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.hasError) {
      _liveTelemetryNotifier.value = _liveTelemetryNotifier.value.copyWith(
        statusMessage: 'Telemetry stream error.',
      );
      return;
    }

    final document = snapshot.data;
    if (document == null) {
      return;
    }

    if (!document.exists) {
      _busAnimationTimer?.cancel();
      _lastTelemetrySignature = null;
      _liveTelemetryNotifier.value = const _LiveTelemetryState(
        statusMessage: 'No live telemetry available for this vehicle yet.',
      );
      return;
    }

    final data = document.data();
    if (data == null) {
      return;
    }

    final latitude = _asDouble(data['latitude']);
    final longitude = _asDouble(data['longitude']);

    if (latitude == null || longitude == null) {
      _liveTelemetryNotifier.value = _liveTelemetryNotifier.value.copyWith(
        statusMessage: 'Telemetry coordinates are missing.',
      );
      return;
    }

    final speedKmh = _asDouble(data['speedKmh']) ?? 0.0;
    final heading = _normalizeHeading(_asDouble(data['heading']) ?? 0.0);
    final updatedAt = _asDateTime(data['updatedAt']) ??
        _asDateTime(data['timestamp']) ??
        DateTime.now();

    final signature =
        '${latitude.toStringAsFixed(6)}|${longitude.toStringAsFixed(6)}|${speedKmh.toStringAsFixed(2)}|${heading.toStringAsFixed(1)}|${updatedAt.millisecondsSinceEpoch}';
    if (_lastTelemetrySignature == signature) {
      return;
    }
    _lastTelemetrySignature = signature;

    final nextPosition = LatLng(latitude, longitude);

    final from = _liveTelemetryNotifier.value.position;

    if (from == null) {
      _liveTelemetryNotifier.value = _liveTelemetryNotifier.value.copyWith(
        position: nextPosition,
        speedKmh: speedKmh,
        heading: heading,
        lastUpdated: updatedAt,
        statusMessage: null,
      );
      return;
    }

    _animateBusMarker(
      from: from,
      to: nextPosition,
      speedKmh: speedKmh,
      heading: heading,
      lastUpdated: updatedAt,
    );
  }

  void _scheduleEtaProcessing(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _processEtaSnapshot(snapshot);
    });
  }

  void _processEtaSnapshot(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.hasError) {
      _etaNotifier.value = _etaNotifier.value.copyWith(
        statusMessage: 'ETA stream error.',
      );
      return;
    }

    final document = snapshot.data;
    if (document == null) {
      return;
    }

    if (!document.exists) {
      _etaNotifier.value = const _EtaDisplayState(
        statusMessage: 'Waiting for ETA prediction...',
      );
      return;
    }

    final data = document.data();
    if (data == null) {
      return;
    }

    final nextStopId = data['nextStopId']?.toString();
    final predictedArrival = _asDateTime(data['predictedArrival']);

    if (nextStopId == null || nextStopId.isEmpty || predictedArrival == null) {
      _etaNotifier.value = const _EtaDisplayState(
        statusMessage: 'ETA payload is incomplete.',
      );
      return;
    }

    _etaNotifier.value = _EtaDisplayState(
      nextStopId: nextStopId,
      nextStopName: _stopNameById(nextStopId) ?? nextStopId,
      predictedArrival: predictedArrival,
      confidence: _asDouble(data['confidence']) ?? 0.0,
      distanceMeters: _asDouble(data['distanceMeters']),
      usedFallbackSpeed: data['usedFallbackSpeed'] == true,
    );
  }

  Color _colorForCrowd(String level) {
    switch (level) {
      case 'LOW':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'HIGH':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  void _scheduleHeatmapProcessing(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _processHeatmapSnapshot(snapshot);
    });
  }

  void _processHeatmapSnapshot(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.hasError || snapshot.data == null) return;
    final document = snapshot.data!;
    if (!document.exists) {
      if (_heatmapSegments.isNotEmpty) {
        _heatmapSegments = {};
        _updateRouteOverlays();
        setState(() {});
      }
      return;
    }
    final data = document.data();
    if (data == null) return;
    final raw = data['segments'];
    final Map<String, String> segments = raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v.toString()))
        : {};
    print('Heatmap segments from Firestore: $segments');
    if (segments.toString() == _heatmapSegments.toString()) return;
    _heatmapSegments = segments;
    _updateRouteOverlays();
    setState(() {});
  }

  String? _stopNameById(String stopId) {
    final route = selectedRoute;
    if (route == null) {
      return null;
    }

    for (final stop in route.stops) {
      if (stop.id == stopId) {
        return stop.stopName;
      }
    }
    return null;
  }

  void _animateBusMarker({
    required LatLng from,
    required LatLng to,
    required double speedKmh,
    required double heading,
    required DateTime lastUpdated,
  }) {
    _busAnimationTimer?.cancel();

    const totalSteps = 12;
    const frame = Duration(milliseconds: 75);
    var step = 0;

    _busAnimationTimer = Timer.periodic(frame, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      step += 1;
      final t = (step / totalSteps).clamp(0.0, 1.0);
      final interpolated = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );

      _liveTelemetryNotifier.value = _liveTelemetryNotifier.value.copyWith(
        position: interpolated,
        speedKmh: speedKmh,
        heading: heading,
        lastUpdated: lastUpdated,
        statusMessage: null,
      );

      if (step >= totalSteps) {
        timer.cancel();
      }
    });
  }

  Set<Marker> _markersWithLiveBus(_LiveTelemetryState liveState) {
    final markers = Set<Marker>.from(_routeMarkers);
    final position = liveState.position;

    if (position != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('live_bus'),
          position: position,
          rotation: liveState.heading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          infoWindow: InfoWindow(
            title: 'Live Bus',
            snippet: 'Speed ${liveState.speedKmh.toStringAsFixed(1)} km/h',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    return markers;
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  DateTime? _asDateTime(Object? value) {
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
    final mod = heading % 360;
    if (mod < 0) {
      return mod + 360;
    }
    return mod;
  }

  String _formatLastUpdate(DateTime? value) {
    if (value == null) {
      return '--';
    }

    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute:$second';
  }

  String _formatEtaTime(DateTime predictedArrival) {
    final local = predictedArrival.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatEtaCountdown(DateTime predictedArrival) {
    final remaining = predictedArrival.difference(DateTime.now());
    if (remaining.inSeconds <= 0) {
      return 'Arriving now';
    }
    if (remaining.inMinutes < 1) {
      return '< 1 min';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${remaining.inMinutes} min';
  }

  @override
  void dispose() {
    _busAnimationTimer?.cancel();
    _liveTelemetryNotifier.dispose();
    _etaNotifier.dispose();
    if (!kIsWeb && _mapReady) {
      mapController?.dispose();
    }
    mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showFixedSidePanel = screenWidth >= 980;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bus Tracking - ${selectedRoute?.routeNumber ?? "N/A"}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (selectedRoute != null)
              Text(
                '${selectedRoute!.source} → ${selectedRoute!.destination}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary.withValues(alpha: 0.8),
                    ),
              ),
          ],
        ),
        actions: [
          if (!showFixedSidePanel)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_open),
                tooltip: 'Map Features',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
        ],
      ),
      endDrawer: showFixedSidePanel
          ? null
          : Drawer(
              width: 340,
              child: SafeArea(
                child: _buildSidePanel(colorScheme, isDrawer: true),
              ),
            ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ValueListenableBuilder<_LiveTelemetryState>(
                        valueListenable: _liveTelemetryNotifier,
                        builder: (context, liveState, _) {
                          return GoogleMap(
                            onMapCreated: _onMapCreated,
                            initialCameraPosition: CameraPosition(
                              target: currentLocation ??
                                  const LatLng(28.6139, 77.2090),
                              zoom: _zoom,
                              tilt: _tilt,
                              bearing: _bearing,
                            ),
                            mapType: _mapType,
                            markers: _markersWithLiveBus(liveState),
                            polylines: polylines,
                            zoomControlsEnabled: false,
                            compassEnabled: true,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            buildingsEnabled: true,
                            trafficEnabled: false,
                          );
                        },
                      ),
                      if (_telemetryStream != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _telemetryStream,
                              builder: (context, snapshot) {
                                _scheduleTelemetryProcessing(snapshot);
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                      if (_etaStream != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _etaStream,
                              builder: (context, snapshot) {
                                _scheduleEtaProcessing(snapshot);
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                      if (_routeHeatmapStream != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _routeHeatmapStream,
                              builder: (context, snapshot) {
                                _scheduleHeatmapProcessing(snapshot);
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (showFixedSidePanel)
                  SizedBox(
                    width: 360,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B24),
                        border: Border(
                          left: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        child: _buildSidePanel(colorScheme),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSidePanel(ColorScheme colorScheme, {bool isDrawer = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route Control Panel',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Bus-line colors, route controls, and live stop navigation.',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.grey[400]),
          ),
          const SizedBox(height: 14),
          _stepHeader('1. Map Type'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _mapTypeButton('Normal', MapType.normal, colorScheme),
              _mapTypeButton('Satellite', MapType.satellite, colorScheme),
              _mapTypeButton('Hybrid', MapType.hybrid, colorScheme),
              _mapTypeButton('Terrain', MapType.terrain, colorScheme),
            ],
          ),
          const Divider(height: 20),
          _stepHeader('2. Route Information'),
          if (selectedRoute != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distance: ${selectedRoute!.distance.toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  'Duration: ${selectedRoute!.estimatedMinutes} mins',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  'Fare: ₹${selectedRoute!.fare}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: colorScheme.primary),
                ),
                Text(
                  'Operator: ${selectedRoute!.operator}',
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Type: ${selectedRoute!.busType}',
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          const Divider(height: 20),
          _stepHeader('3. Live Telemetry'),
          ValueListenableBuilder<_LiveTelemetryState>(
            valueListenable: _liveTelemetryNotifier,
            builder: (context, liveState, _) {
              if (liveState.statusMessage != null) {
                return Text(
                  liveState.statusMessage!,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.grey[400]),
                );
              }

              if (liveState.position == null) {
                return Text(
                  'Waiting for live telemetry...',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.grey[400]),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Speed: ${liveState.speedKmh.toStringAsFixed(1)} km/h',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    'Last Update: ${_formatLastUpdate(liveState.lastUpdated)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              );
            },
          ),
          const Divider(height: 20),
          const Divider(height: 20),
          _stepHeader('4. Predicted ETA'),
          ValueListenableBuilder<_EtaDisplayState>(
            valueListenable: _etaNotifier,
            builder: (context, etaState, _) {
              if (etaState.statusMessage != null) {
                return Text(
                  etaState.statusMessage!,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.grey[400]),
                );
              }

              if (etaState.predictedArrival == null) {
                return Text(
                  'ETA prediction unavailable.',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.grey[400]),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Stop: ${etaState.nextStopName ?? '--'}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    'Arrival: ${_formatEtaCountdown(etaState.predictedArrival!)} (${_formatEtaTime(etaState.predictedArrival!)})',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    'Confidence: ${(etaState.confidence * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (etaState.distanceMeters != null)
                    Text(
                      'Distance to next stop: ${(etaState.distanceMeters! / 1000).toStringAsFixed(2)} km',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  if (etaState.usedFallbackSpeed)
                    Text(
                      'Using fallback average route speed.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.amber[300],
                          ),
                    ),
                ],
              );
            },
          ),
          const Divider(height: 20),
          _stepHeader('5. 3D Camera Controls'),
          _sliderRow(
            label: 'Tilt',
            unit: '°',
            value: _tilt,
            min: 0,
            max: 60,
            colorScheme: colorScheme,
            onChanged: (value) {
              setState(() => _tilt = value);
              _updateCamera();
            },
          ),
          const SizedBox(height: 8),
          _sliderRow(
            label: 'Bearing',
            unit: '°',
            value: _bearing,
            min: 0,
            max: 360,
            colorScheme: colorScheme,
            onChanged: (value) {
              setState(() => _bearing = value);
              _updateCamera();
            },
          ),
          const SizedBox(height: 8),
          _sliderRow(
            label: 'Zoom',
            value: _zoom,
            min: 8,
            max: 20,
            colorScheme: colorScheme,
            decimals: 1,
            onChanged: (value) {
              setState(() => _zoom = value);
              _updateCamera();
            },
          ),
          const Divider(height: 20),
          _stepHeader('6. Route Stops'),
          if (selectedRoute != null)
            ...List.generate(selectedRoute!.stops.length, (index) {
              final stop = selectedRoute!.stops[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.18),
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                ),
                title: Text(
                  stop.stopName,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                subtitle: Text(
                  'ETA: ${stop.arrivalMinutes} min',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontSize: 10),
                ),
                onTap: () {
                  if (mapController == null) return;
                  mapController!.animateCamera(
                    CameraUpdate.newLatLng(
                      LatLng(stop.latitude, stop.longitude),
                    ),
                  );
                  if (isDrawer) Navigator.of(context).maybePop();
                },
              );
            }),
        ],
      ),
    );
  }

  Widget _stepHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    String unit = '',
    required double value,
    required double min,
    required double max,
    required ColorScheme colorScheme,
    required ValueChanged<double> onChanged,
    int decimals = 0,
  }) {
    final displayValue = value.toStringAsFixed(decimals);
    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(
            '$label: $displayValue$unit',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: colorScheme.primary,
            inactiveColor: colorScheme.primary.withValues(alpha: 0.2),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _mapTypeButton(String label, MapType type, ColorScheme colorScheme) {
    final isSelected = _mapType == type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _mapType = type),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.2)
                : const Color(0xFF1A232D),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSelected ? colorScheme.primary : Colors.grey[400],
                  fontSize: 11,
                ),
          ),
        ),
      ),
    );
  }
}

class _LiveTelemetryState {
  const _LiveTelemetryState({
    this.position,
    this.speedKmh = 0,
    this.heading = 0,
    this.lastUpdated,
    this.statusMessage,
  });

  final LatLng? position;
  final double speedKmh;
  final double heading;
  final DateTime? lastUpdated;
  final String? statusMessage;

  _LiveTelemetryState copyWith({
    LatLng? position,
    double? speedKmh,
    double? heading,
    DateTime? lastUpdated,
    String? statusMessage,
  }) {
    return _LiveTelemetryState(
      position: position ?? this.position,
      speedKmh: speedKmh ?? this.speedKmh,
      heading: heading ?? this.heading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      statusMessage: statusMessage,
    );
  }
}

class _EtaDisplayState {
  const _EtaDisplayState({
    this.nextStopId,
    this.nextStopName,
    this.predictedArrival,
    this.confidence = 0,
    this.distanceMeters,
    this.usedFallbackSpeed = false,
    this.statusMessage,
  });

  final String? nextStopId;
  final String? nextStopName;
  final DateTime? predictedArrival;
  final double confidence;
  final double? distanceMeters;
  final bool usedFallbackSpeed;
  final String? statusMessage;

  _EtaDisplayState copyWith({
    String? nextStopId,
    String? nextStopName,
    DateTime? predictedArrival,
    double? confidence,
    double? distanceMeters,
    bool? usedFallbackSpeed,
    String? statusMessage,
  }) {
    return _EtaDisplayState(
      nextStopId: nextStopId ?? this.nextStopId,
      nextStopName: nextStopName ?? this.nextStopName,
      predictedArrival: predictedArrival ?? this.predictedArrival,
      confidence: confidence ?? this.confidence,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      usedFallbackSpeed: usedFallbackSpeed ?? this.usedFallbackSpeed,
      statusMessage: statusMessage,
    );
  }
}
