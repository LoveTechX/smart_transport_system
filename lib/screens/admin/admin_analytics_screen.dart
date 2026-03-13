import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/transport_analytics_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final TransportAnalyticsService _analyticsService =
      TransportAnalyticsService();

  bool _isComputing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _refreshAnalytics();
  }

  Future<void> _refreshAnalytics() async {
    if (_isComputing) {
      return;
    }

    setState(() {
      _isComputing = true;
      _statusMessage = null;
    });

    try {
      final results = await _analyticsService.recomputeAndPersistAllRoutes();
      if (!mounted) {
        return;
      }
      setState(() {
        _isComputing = false;
        _statusMessage = 'Analytics updated for ${results.length} routes.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isComputing = false;
        _statusMessage = 'Failed to compute analytics. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Transport Analytics'),
        actions: [
          IconButton(
            tooltip: 'Recompute analytics',
            onPressed: _refreshAnalytics,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<RouteAnalyticsData>>(
        stream: _analyticsService.watchRouteAnalytics(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AnalyticsErrorState(onRetry: _refreshAnalytics);
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final analytics = snapshot.data!;
          if (analytics.isEmpty) {
            return _AnalyticsEmptyState(
              isBusy: _isComputing,
              message: _statusMessage,
              onRefresh: _refreshAnalytics,
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshAnalytics,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderCard(context, colorScheme, analytics),
                const SizedBox(height: 12),
                _ChartCard(
                  title: 'Average Occupancy by Route',
                  subtitle: 'Passenger load percentage across routes',
                  child: _RouteBarChart(
                    items: analytics,
                    valueOf: (item) => item.averageOccupancy,
                    valueSuffix: '%',
                    barColor: colorScheme.primary,
                    maxY: 100,
                  ),
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  title: 'Bus Utilization by Route',
                  subtitle: 'Active buses / assigned buses percentage',
                  child: _RouteBarChart(
                    items: analytics,
                    valueOf: (item) => item.utilization,
                    valueSuffix: '%',
                    barColor: colorScheme.tertiary,
                    maxY: 100,
                  ),
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  title: 'Average Trip Duration by Route',
                  subtitle: 'Mean trip time in minutes',
                  child: _RouteBarChart(
                    items: analytics,
                    valueOf: (item) => item.averageTripDuration,
                    valueSuffix: ' min',
                    barColor: colorScheme.secondary,
                    maxY: _maxDuration(analytics),
                  ),
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  title: 'Peak Passenger Hour by Route',
                  subtitle: 'Highest ticket activity hour (0-23)',
                  child: _PeakHourLineChart(items: analytics),
                ),
                const SizedBox(height: 12),
                _buildRouteTable(context, analytics),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    ColorScheme colorScheme,
    List<RouteAnalyticsData> items,
  ) {
    final avgOccupancy =
        items.fold<double>(0, (sum, item) => sum + item.averageOccupancy) /
            items.length;
    final avgUtilization =
        items.fold<double>(0, (sum, item) => sum + item.utilization) /
            items.length;
    final avgDuration =
        items.fold<double>(0, (sum, item) => sum + item.averageTripDuration) /
            items.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryChip(
                  label: 'Routes',
                  value: '${items.length}',
                  color: colorScheme.primary,
                ),
                _SummaryChip(
                  label: 'Avg Occupancy',
                  value: '${avgOccupancy.toStringAsFixed(1)}%',
                  color: colorScheme.tertiary,
                ),
                _SummaryChip(
                  label: 'Avg Utilization',
                  value: '${avgUtilization.toStringAsFixed(1)}%',
                  color: colorScheme.secondary,
                ),
                _SummaryChip(
                  label: 'Avg Trip Duration',
                  value: '${avgDuration.toStringAsFixed(1)} min',
                  color: const Color(0xFF90CAF9),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_isComputing) const LinearProgressIndicator(minHeight: 3),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_statusMessage!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteTable(
      BuildContext context, List<RouteAnalyticsData> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route Analytics Snapshot',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alt_route_rounded),
                title: Text(item.routeId),
                subtitle: Text(
                  'Peak: ${_formatHour(item.peakHour)} | Duration: ${item.averageTripDuration.toStringAsFixed(1)} min',
                ),
                trailing: Text(
                  '${item.averageOccupancy.toStringAsFixed(1)}% / ${item.utilization.toStringAsFixed(1)}%',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _maxDuration(List<RouteAnalyticsData> items) {
    final peak = items.fold<double>(0, (max, item) {
      return item.averageTripDuration > max ? item.averageTripDuration : max;
    });

    if (peak <= 0) {
      return 10;
    }

    return peak * 1.2;
  }

  String _formatHour(int hour) {
    final start = hour.toString().padLeft(2, '0');
    final end = ((hour + 1) % 24).toString().padLeft(2, '0');
    return '$start:00-$end:00';
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

class _RouteBarChart extends StatelessWidget {
  const _RouteBarChart({
    required this.items,
    required this.valueOf,
    required this.valueSuffix,
    required this.barColor,
    required this.maxY,
  });

  final List<RouteAnalyticsData> items;
  final double Function(RouteAnalyticsData item) valueOf;
  final String valueSuffix;
  final Color barColor;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final limited = items.take(10).toList(growable: false);

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 1 : maxY,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = limited[group.x.toInt()];
              final value = valueOf(item).toStringAsFixed(1);
              return BarTooltipItem(
                '${item.routeId}\n$value$valueSuffix',
                Theme.of(context).textTheme.bodySmall!,
              );
            },
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(limited.length, (index) {
          final item = limited[index];
          final value = valueOf(item);
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                width: 16,
                color: barColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= limited.length) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    limited[index].routeId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PeakHourLineChart extends StatelessWidget {
  const _PeakHourLineChart({required this.items});

  final List<RouteAnalyticsData> items;

  @override
  Widget build(BuildContext context) {
    final limited = items.take(10).toList(growable: false);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 23,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final item = limited[spot.x.toInt()];
              final hour = item.peakHour.toString().padLeft(2, '0');
              return LineTooltipItem(
                '${item.routeId}\n$hour:00',
                Theme.of(context).textTheme.bodySmall!,
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 3,
            color: Theme.of(context).colorScheme.primary,
            dotData: const FlDotData(show: true),
            spots: List.generate(
              limited.length,
              (index) => FlSpot(
                index.toDouble(),
                limited[index].peakHour.toDouble(),
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 4,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= limited.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    limited[index].routeId,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsErrorState extends StatelessWidget {
  const _AnalyticsErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

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
            const Text(
              'Failed to load analytics stream.',
              textAlign: TextAlign.center,
            ),
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

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState({
    required this.isBusy,
    required this.message,
    required this.onRefresh,
  });

  final bool isBusy;
  final String? message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy) const CircularProgressIndicator(),
            if (!isBusy) const Icon(Icons.insights_outlined, size: 38),
            const SizedBox(height: 12),
            Text(
              message ??
                  'No route analytics found. Tap refresh to compute now.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Recompute Analytics'),
            ),
          ],
        ),
      ),
    );
  }
}
