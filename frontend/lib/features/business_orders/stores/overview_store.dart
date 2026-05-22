import 'package:signals/signals.dart';

import '../../../core/http/api_exception.dart';
import '../data/business_order_api.dart';
import '../data/business_order_models.dart';

class OverviewStore {
  OverviewStore(this._api);

  final BusinessOrderApi _api;

  final flowTrend = signal<List<DailyCount>>([]);
  final isLoading = signal(false);
  final errorMessage = signal<String?>(null);

  Future<void> loadFlowTrend({String? taskStateName}) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      flowTrend.value = await _api.getFlowTrend(taskStateName: taskStateName);
    } catch (error) {
      errorMessage.value = ApiException.from(error).message;
    } finally {
      isLoading.value = false;
    }
  }
}
