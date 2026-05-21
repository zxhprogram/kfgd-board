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

  Future<void> loadPage({int? pageNo, int? pageSize}) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final page = await _api.listBusinessOrders(
        pageNo: pageNo ?? this.pageNo.value,
        pageSize: pageSize ?? this.pageSize.value,
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
