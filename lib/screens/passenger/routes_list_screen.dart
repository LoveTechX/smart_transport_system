import 'package:flutter/material.dart';
import '../../models/bus_route.dart';
import '../../models/bus_routes_repository.dart';
import 'track_bus_screen.dart';

class RoutesListScreen extends StatefulWidget {
  const RoutesListScreen({super.key});

  @override
  State<RoutesListScreen> createState() => _RoutesListScreenState();
}

class _RoutesListScreenState extends State<RoutesListScreen> {
  late List<BusRoute> filteredRoutes;
  String _searchQuery = '';
  String? _filterOperator;
  String? _filterBusType;
  double _maxFare = 500;
  double _maxDistance = 100;

  @override
  void initState() {
    super.initState();
    filteredRoutes = BusRoutesRepository.allRoutes;
  }

  void _applyFilters() {
    filteredRoutes = BusRoutesRepository.allRoutes.where((route) {
      final matchSearch = _searchQuery.isEmpty ||
          route.routeNumber.contains(_searchQuery) ||
          route.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          route.source.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          route.destination.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchOperator =
          _filterOperator == null || route.operator == _filterOperator;

      final matchBusType =
          _filterBusType == null || route.busType == _filterBusType;

      final matchFare = route.fare <= _maxFare;
      final matchDistance = route.distance <= _maxDistance;

      return matchSearch &&
          matchOperator &&
          matchBusType &&
          matchFare &&
          matchDistance;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    _applyFilters();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bus Routes'),
        elevation: 0,
        backgroundColor: const Color(0xFF0F1624),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF151D2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: Color(0xFFE7ECF3)),
                decoration: InputDecoration(
                  hintText: 'Search route number or location...',
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.primary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  'Bus Type',
                  _filterBusType,
                  [
                    'AC Bus',
                    'Non-AC',
                    'AC Deluxe',
                    'AC Minibus',
                    'Standard Bus',
                    'AC Volvo',
                    'Premium Luxury',
                    'Cargo Van',
                    'Rapid Response',
                    'Electric Bus'
                  ],
                  (value) => setState(() => _filterBusType = value),
                  colorScheme,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Operator',
                  _filterOperator,
                  [
                    'Metro Transport',
                    'City Buses',
                    'Green Transport',
                    'Tech Express',
                    'Student Transport',
                    'Medical Transport',
                    'Mall Transport',
                    'Regional Transport'
                  ],
                  (value) => setState(() => _filterOperator = value),
                  colorScheme,
                ),
              ],
            ),
          ),

          // Routes Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredRoutes.length} Routes Available',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _filterOperator = null;
                    _filterBusType = null;
                    _maxFare = 500;
                    _maxDistance = 100;
                  }),
                  child: Text(
                    'Clear Filters',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // Routes List
          Expanded(
            child: filteredRoutes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No routes found',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try adjusting your search filters',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 12,
                    ),
                    itemCount: filteredRoutes.length,
                    itemBuilder: (context, index) {
                      final route = filteredRoutes[index];
                      return _routeCard(route, colorScheme, context);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    String? selected,
    List<String> options,
    Function(String?) onSelected,
    ColorScheme colorScheme,
  ) {
    return PopupMenuButton(
      onSelected: (value) {
        if (value == selected) {
          onSelected(null); // Toggle off
        } else {
          onSelected(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Text('All'),
        ),
        ...options.map((option) => PopupMenuItem(
              value: option,
              child: Text(option),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF151D2C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected != null
                ? colorScheme.primary
                : colorScheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Text(
              selected ?? label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected != null
                        ? colorScheme.primary
                        : Colors.grey[400],
                  ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: selected != null ? colorScheme.primary : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeCard(
    BusRoute route,
    ColorScheme colorScheme,
    BuildContext context,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF151D2C),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrackBusScreen(routeId: route.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route ${route.routeNumber}',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          route.name,
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: route.isActive
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      route.isActive ? 'Active' : 'Inactive',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: route.isActive ? Colors.green : Colors.grey,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Route Path
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.source,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 11,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '↓',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: colorScheme.primary,
                                  ),
                        ),
                        Text(
                          route.destination,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 11,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Distance, Duration, Fare
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoChip(
                    Icons.straighten,
                    '${route.distance} km',
                    colorScheme,
                    context,
                  ),
                  _infoChip(
                    Icons.schedule,
                    '${route.estimatedMinutes} mins',
                    colorScheme,
                    context,
                  ),
                  _infoChip(
                    Icons.currency_rupee,
                    '₹${route.fare}',
                    colorScheme,
                    context,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Bus Type & Operator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.directions_bus,
                            size: 14, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            route.busType,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontSize: 11,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      route.operator,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Stops Count & Track Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.stop_circle,
                        size: 14,
                        color: colorScheme.primary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${route.stops.length} stops',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TrackBusScreen(routeId: route.id),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.map,
                                  size: 14, color: Color(0xFF0D111A)),
                              const SizedBox(width: 4),
                              Text(
                                'Track',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontSize: 11,
                                      color: const Color(0xFF0D111A),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(
    IconData icon,
    String text,
    ColorScheme colorScheme,
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(height: 2),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}
