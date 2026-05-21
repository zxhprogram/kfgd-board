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
  final parsedProIds = signal<List<String>>([]);
  final duplicateInFileCount = signal(0);
  final alreadyImportedCount = signal(0);
  final pendingImportProIds = signal<List<String>>([]);
  final isParsing = signal(false);
  final isImporting = signal(false);
  final errorMessage = signal<String?>(null);
  final lastResult = signal<ImportBusinessOrdersResponse?>(null);

  late final parsedCount = computed(() => parsedProIds.value.length);
  late final pendingImportCount = computed(
    () => pendingImportProIds.value.length,
  );
  late final canImport = computed(
    () => pendingImportProIds.value.isNotEmpty && !isImporting.value,
  );

  Future<void> setParsedProIds({
    required String fileName,
    required List<String> proIds,
    required int duplicateCount,
  }) async {
    isParsing.value = true;
    errorMessage.value = null;
    lastResult.value = null;
    try {
      selectedFileName.value = fileName;
      parsedProIds.value = proIds;
      duplicateInFileCount.value = duplicateCount;
      final existing = await _orderStore.loadAllProIds();
      final pending = proIds
          .where((proId) => !existing.contains(proId))
          .toList();
      alreadyImportedCount.value = proIds.length - pending.length;
      pendingImportProIds.value = pending;
    } catch (error) {
      errorMessage.value = ApiException.from(error).message;
    } finally {
      isParsing.value = false;
    }
  }

  Future<void> importPending() async {
    if (pendingImportProIds.value.isEmpty) {
      return;
    }
    isImporting.value = true;
    errorMessage.value = null;
    try {
      final result = await _api.importBusinessOrders(pendingImportProIds.value);
      lastResult.value = result;
      pendingImportProIds.value = const [];
      alreadyImportedCount.value = parsedProIds.value.length;
      await _orderStore.loadPage(pageNo: 1);
    } catch (error) {
      errorMessage.value = ApiException.from(error).message;
    } finally {
      isImporting.value = false;
    }
  }

  void reset() {
    selectedFileName.value = null;
    parsedProIds.value = const [];
    duplicateInFileCount.value = 0;
    alreadyImportedCount.value = 0;
    pendingImportProIds.value = const [];
    errorMessage.value = null;
    lastResult.value = null;
  }
}
