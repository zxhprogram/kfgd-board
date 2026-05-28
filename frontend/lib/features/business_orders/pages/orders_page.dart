import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../app/dependencies.dart';
import '../data/business_order_models.dart';
import '../widgets/business_order_table.dart';
import '../widgets/order_detail_drawer.dart';
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

  void _clearFilter() {
    _proIdController.clear();
    businessOrderStore.proStateFilter.value = null;
    businessOrderStore.startTimeFromFilter.value = null;
    businessOrderStore.startTimeToFilter.value = null;
    businessOrderStore.resolveTimeFromFilter.value = null;
    businessOrderStore.resolveTimeToFilter.value = null;
    businessOrderStore.loadPage(pageNo: 1, proId: '');
  }

  Future<void> _onRowDoubleTap(BusinessOrderItem item) async {
    try {
      final detail = await businessOrderApi.getBusinessOrderDetail(item.proId);
      final childOrders = await businessOrderApi.getChildOrders(item.proId);
      if (!mounted) return;
      showOrderDetailDrawer(context, order: detail, childOrders: childOrders);
    } catch (_) {
      if (!mounted) return;
      showOrderDetailDrawer(context, order: item, childOrders: const []);
    }
  }

  String? _dateTimeToDateString(DateTime? dt) {
    if (dt == null) return null;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} 00:00:00';
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
              Button.outline(
                onPressed: store.isSyncing.watch(context)
                    ? null
                    : store.syncAll,
                child: store.isSyncing.watch(context)
                    ? Text(
                        '同步中 ${store.syncCompletedCount.watch(context)}/${store.syncTotalCount.watch(context)}',
                      )
                    : const Text('重新同步'),
              ),
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
              const Text('工单编号：'),
              const Gap(8),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _proIdController,
                  placeholder: const Text('输入 proId 关键字'),
                  onSubmitted: (_) => _applyFilter(),
                ),
              ),
              const Gap(16),
              const Text('状态：'),
              const Gap(8),
              SizedBox(
                width: 160,
                child: Select<int?>(
                  value: store.proStateFilter.watch(context),
                  onChanged: (v) {
                    store.proStateFilter.value = v;
                  },
                  placeholder: const Text('全部'),
                  itemBuilder: (context, value) {
                    const labels = {
                      1: '待处理',
                      61: '已处理待确认',
                      7: '已关闭',
                    };
                    return Text(labels[value] ?? value.toString());
                  },
                  popup: (context) {
                    return SelectGroup(
                      children: [
                        SelectItem(value: null, builder: (_) => const Text('全部')),
                        SelectItem(value: 1, builder: (_) => const Text('待处理')),
                        SelectItem(value: 61, builder: (_) => const Text('已处理待确认')),
                        SelectItem(value: 7, builder: (_) => const Text('已关闭')),
                      ],
                    );
                  },
                ),
              ),
              const Gap(16),
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
              const Gap(16),
              const Text('解决时间：'),
              const Gap(8),
              DatePicker(
                value: store.resolveTimeFromFilter.watch(context) != null
                    ? DateTime.tryParse(store.resolveTimeFromFilter.value!)
                    : null,
                onChanged: (dt) {
                  store.resolveTimeFromFilter.value = _dateTimeToDateString(dt);
                },
                placeholder: const Text('从'),
              ),
              const Gap(4),
              const Text('~'),
              const Gap(4),
              DatePicker(
                value: store.resolveTimeToFilter.watch(context) != null
                    ? DateTime.tryParse(store.resolveTimeToFilter.value!)
                    : null,
                onChanged: (dt) {
                  final str = _dateTimeToDateString(dt);
                  if (str != null) {
                    store.resolveTimeToFilter.value = str.replaceFirst('00:00:00', '23:59:59');
                  } else {
                    store.resolveTimeToFilter.value = null;
                  }
                },
                placeholder: const Text('到'),
              ),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              Button.primary(onPressed: _applyFilter, child: const Text('查询')),
              const Gap(8),
              Button.outline(onPressed: _clearFilter, child: const Text('清除')),
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
                child: BusinessOrderTable(items: orders, onRowTap: _onRowDoubleTap),
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
