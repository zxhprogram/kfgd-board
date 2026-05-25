import 'package:signals/signals.dart';

import '../../../core/config/app_config.dart';
import '../../../core/http/api_exception.dart';
import '../data/business_order_api.dart';
import '../data/business_order_models.dart';

class BusinessOrderStore {
  BusinessOrderStore(this._api);

  final BusinessOrderApi _api;

  final orders = signal<List<BusinessOrderItem>>([]);
  final pageNo = signal(1);
  final pageSize = signal(AppConfig.defaultPageSize);
  final total = signal(0);
  final isLoading = signal(false);
  final errorMessage = signal<String?>(null);
  final proIdFilter = signal('');
  final isSyncing = signal(false);
  final syncCompletedCount = signal(0);
  final syncTotalCount = signal(0);

  late final totalPages = computed(() {
    final size = pageSize.value;
    if (size <= 0) {
      return 1;
    }
    final pages = (total.value / size).ceil();
    return pages < 1 ? 1 : pages;
  });

  late final hasPreviousPage = computed(() => pageNo.value > 1);
  late final hasNextPage = computed(() => pageNo.value < totalPages.value);

  Future<void> loadPage({int? pageNo, int? pageSize, String? proId}) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final filter = proId ?? proIdFilter.value;
      if (proId != null) {
        proIdFilter.value = proId;
      }
      final page = await _api.listBusinessOrders(
        pageNo: pageNo ?? this.pageNo.value,
        pageSize: pageSize ?? this.pageSize.value,
        proId: filter.isNotEmpty ? filter : null,
      );
      orders.value = page.items;
      this.pageNo.value = page.pageNo;
      this.pageSize.value = page.pageSize;
      total.value = page.total;
    } catch (error) {
      errorMessage.value = ApiException.from(error).message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() {
    return loadPage(pageNo: pageNo.value, pageSize: pageSize.value);
  }

  Future<void> syncAll() async {
    isSyncing.value = true;
    syncCompletedCount.value = 0;
    syncTotalCount.value = 0;
    errorMessage.value = null;
    try {
      const batchSize = 50;
      var currentPage = 1;
      while (true) {
        final result = await _api.syncBusinessOrders(
          pageNo: currentPage,
          pageSize: batchSize,
        );
        final synced = (result['synced'] as num?)?.toInt() ?? 0;
        final total = (result['total'] as num?)?.toInt() ?? 0;
        syncTotalCount.value = total;
        syncCompletedCount.value += synced;
        if (syncCompletedCount.value >= total || synced == 0) {
          break;
        }
        currentPage++;
      }
      await loadPage(pageNo: 1);
    } catch (error) {
      errorMessage.value = ApiException.from(error).message;
    } finally {
      isSyncing.value = false;
    }
  }

  Future<Set<String>> loadAllProIds() async {
    final result = <String>{};
    var currentPage = 1;
    const size = AppConfig.maxPageSize;
    while (true) {
      final page = await _api.listBusinessOrders(
        pageNo: currentPage,
        pageSize: size,
      );
      result.addAll(page.items.map((item) => item.proId));
      if (result.length >= page.total || page.items.isEmpty) {
        return result;
      }
      currentPage++;
    }
  }
}
