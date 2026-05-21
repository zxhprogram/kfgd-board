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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      businessOrderStore.loadPage();
    });
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
