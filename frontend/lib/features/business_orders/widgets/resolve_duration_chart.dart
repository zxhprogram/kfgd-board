import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../data/business_order_models.dart';

class ResolveDurationChart extends StatelessWidget {
  const ResolveDurationChart({super.key, required this.data});

  final List<DurationBucket> data;

  static const _allLabels = ['<24h', '24-48h', '48-120h', '>120h'];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('暂无解决时长数据'));
    }

    final labelToCount = <String, double>{};
    for (final item in data) {
      labelToCount[item.label] = item.count.toDouble();
    }

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < _allLabels.length; i++) {
      final count = labelToCount[_allLabels[i]] ?? 0;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count,
              width: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      );
    }

    final maxY = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxY + 1).toDouble(),
        barGroups: bars,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('解决时长'),
            axisNameSize: 24,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _allLabels.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _allLabels[index],
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('工单数'),
            axisNameSize: 24,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = groupIndex < _allLabels.length
                  ? _allLabels[groupIndex]
                  : '';
              return BarTooltipItem(
                '$label\n${rod.toY.toInt()} 条',
                const TextStyle(fontSize: 12),
              );
            },
          ),
        ),
      ),
    );
  }
}
