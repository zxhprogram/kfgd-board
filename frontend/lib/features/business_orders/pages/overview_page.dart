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
