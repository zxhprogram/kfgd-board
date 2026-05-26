import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../app/dependencies.dart';
import '../widgets/flow_trend_chart.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      overviewStore.loadFlowTrend();
    });
  }

  String? _dateTimeToDateString(DateTime? dt) {
    if (dt == null) return null;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} 00:00:00';
  }

  void _applyFilter() {
    overviewStore.loadFlowTrend();
  }

  void _clearFilter() {
    overviewStore.startTimeFromFilter.value = null;
    overviewStore.startTimeToFilter.value = null;
    overviewStore.loadFlowTrend();
  }

  @override
  Widget build(BuildContext context) {
    final store = overviewStore;
    final data = store.flowTrend.watch(context);
    final loading = store.isLoading.watch(context);
    final error = store.errorMessage.watch(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '数据总览',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const Gap(8),
          const Text('工单流转趋势：按日期统计流转到"待处理（属地开发组分析）"节点的工单数量。'),
          const Gap(16),
          Row(
            children: [
              const Text('开始时间：'),
              const Gap(8),
              DatePicker(
                value: store.startTimeFromFilter.watch(context) != null
                    ? DateTime.tryParse(store.startTimeFromFilter.value!)
                    : null,
                onChanged: (dt) {
                  store.startTimeFromFilter.value = _dateTimeToDateString(dt);
                },
                placeholder: const Text('从'),
              ),
              const Gap(4),
              const Text('~'),
              const Gap(4),
              DatePicker(
                value: store.startTimeToFilter.watch(context) != null
                    ? DateTime.tryParse(store.startTimeToFilter.value!)
                    : null,
                onChanged: (dt) {
                  final str = _dateTimeToDateString(dt);
                  if (str != null) {
                    store.startTimeToFilter.value = str.replaceFirst('00:00:00', '23:59:59');
                  } else {
                    store.startTimeToFilter.value = null;
                  }
                },
                placeholder: const Text('到'),
              ),
              const Gap(8),
              Button.primary(onPressed: _applyFilter, child: const Text('查询')),
              const Gap(8),
              Button.outline(onPressed: _clearFilter, child: const Text('清除')),
            ],
          ),
          const Gap(24),
          if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.destructive,
                  ),
                ),
              ),
            ),
          if (loading)
            const Padding(padding: EdgeInsets.all(16), child: Text('加载中...')),
          if (!loading && data.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(height: 400, child: FlowTrendChart(data: data)),
              ),
            ),
          if (!loading && data.isEmpty && error == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂无趋势数据'),
              ),
            ),
        ],
      ),
    );
  }
}
