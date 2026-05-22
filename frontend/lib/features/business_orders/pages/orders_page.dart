import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../app/dependencies.dart';
import '../widgets/business_order_table.dart';
import '../widgets/pagination_bar.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _proIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _proIdController.text = businessOrderStore.proIdFilter.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      businessOrderStore.loadPage();
    });
  }

  @override
  void dispose() {
    _proIdController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    businessOrderStore.loadPage(pageNo: 1, proId: _proIdController.text);
  }

  @override
  Widget build(BuildContext context) {
    final store = businessOrderStore;
    final orders = store.orders.watch(context);
    final pageNo = store.pageNo.watch(context);
    final total = store.total.watch(context);
    final loading = store.isLoading.watch(context);
    final error = store.errorMessage.watch(context);
    final totalPages = store.totalPages.watch(context);
    final hasPrevious = store.hasPreviousPage.watch(context);
    final hasNext = store.hasNextPage.watch(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '数据列表',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gap(8),
                    Text('查看已经导入并保存到 SQLite 的工单数据。'),
                  ],
                ),
              ),
              Button.outline(onPressed: store.refresh, child: const Text('刷新')),
              const Gap(8),
              Button.primary(
                onPressed: () => context.go('/import'),
                child: const Text('导入数据'),
              ),
            ],
          ),
          const Gap(16),
          Row(
            children: [
              const Text('工单编号筛选：'),
              const Gap(8),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _proIdController,
                  placeholder: const Text('输入 proId 关键字'),
                  onSubmitted: (_) => _applyFilter(),
                ),
              ),
              const Gap(8),
              Button.primary(onPressed: _applyFilter, child: const Text('查询')),
              const Gap(8),
              Button.outline(
                onPressed: () {
                  _proIdController.clear();
                  store.loadPage(pageNo: 1, proId: '');
                },
                child: const Text('清除'),
              ),
            ],
          ),
          const Gap(16),
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
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BusinessOrderTable(items: orders),
              ),
            ),
          ),
          const Gap(16),
          PaginationBar(
            pageNo: pageNo,
            totalPages: totalPages,
            total: total,
            hasPreviousPage: hasPrevious,
            hasNextPage: hasNext,
            onPrevious: () => store.loadPage(pageNo: pageNo - 1),
            onNext: () => store.loadPage(pageNo: pageNo + 1),
          ),
        ],
      ),
    );
  }
}
