import 'package:signals/signals.dart';

import '../../../core/http/api_exception.dart';
import '../data/business_order_api.dart';
import '../data/business_order_models.dart';
import 'business_order_store.dart';

class ImportStore {
  ImportStore(this._api, this._orderStore);

  final BusinessOrderApi _api;
  final BusinessOrderStore _orderStore;

  final selectedFileName = signal<String?>(null);
  final parsedOrders = signal<List<BusinessOrderImportItem>>([]);
  final duplicateInFileCount = signal(0);
  final alreadyImportedCount = signal(0);
  final pendingImportOrders = signal<List<BusinessOrderImportItem>>([]);
  final isParsing = signal(false);
  final isImporting = signal(false);
  final importTotalCount = signal(0);
  final importCompletedCount = signal(0);
  final importSuccessCount = signal(0);
  final errorMessage = signal<String?>(null);
  final lastResult = signal<ImportBusinessOrdersResponse?>(null);

  late final parsedCount = computed(() => parsedOrders.value.length);
  late final pendingImportCount = computed(
    () => pendingImportOrders.value.length,
  );
  late final canImport = computed(
    () => pendingImportOrders.value.isNotEmpty && !isImporting.value,
  );
  late final importProgress = computed(() {
    if (importTotalCount.value == 0) {
      return 0.0;
    }
    return importCompletedCount.value / importTotalCount.value;
  });

  Future<void> setParsedOrders({
    required String fileName,
    required List<BusinessOrderImportItem> orders,
    required int duplicateCount,
  }) async {
    isParsing.value = true;
    errorMessage.value = null;
    lastResult.value = null;
    try {
      selectedFileName.value = fileName;
      parsedOrders.value = orders;
      duplicateInFileCount.value = duplicateCount;
      final existing = await _orderStore.loadAllProIds();
      final pending = orders
          .where((order) => !existing.contains(order.proId))
          .toList();
      alreadyImportedCount.value = orders.length - pending.length;
      pendingImportOrders.value = pending;
    } catch (error) {
      errorMessage.value = ApiException.from(error).message;
    } finally {
      isParsing.value = false;
    }
  }

  Future<void> importPending() async {
    final orders = pendingImportOrders.value;
    if (orders.isEmpty) {
      return;
    }
    isImporting.value = true;
    importTotalCount.value = orders.length;
    importCompletedCount.value = 0;
    importSuccessCount.value = 0;
    errorMessage.value = null;
    lastResult.value = null;
    try {
      for (final order in orders) {
        final result = await _api.importBusinessOrders([order]);
        importCompletedCount.value += 1;
        importSuccessCount.value += result.imported;
      }
      lastResult.value = ImportBusinessOrdersResponse(
        requested: importTotalCount.value,
        imported: importSuccessCount.value,
      );
      pendingImportOrders.value = const [];
      alreadyImportedCount.value = parsedOrders.value.length;
      await _orderStore.loadPage(pageNo: 1);
    } catch (error) {
      errorMessage.value = ApiException.from(error).message;
    } finally {
      isImporting.value = false;
    }
  }

  void reset() {
    selectedFileName.value = null;
    parsedOrders.value = const [];
    duplicateInFileCount.value = 0;
    alreadyImportedCount.value = 0;
    pendingImportOrders.value = const [];
    importTotalCount.value = 0;
    importCompletedCount.value = 0;
    importSuccessCount.value = 0;
    errorMessage.value = null;
    lastResult.value = null;
  }
}
