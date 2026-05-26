import 'package:signals/signals.dart';

import '../../../core/http/api_exception.dart';
import '../data/business_order_api.dart';
import '../data/business_order_models.dart';

class OverviewStore {
  OverviewStore(this._api);

  final BusinessOrderApi _api;

  final flowTrend = signal<List<DailyCount>>([]);
  final resolveDurationData = signal<List<DurationBucket>>([]);
  final isLoading = signal(false);
  final errorMessage = signal<String?>(null);
  final startTimeFromFilter = signal<String?>(null);
  final startTimeToFilter = signal<String?>(null);

  Future<void> loadFlowTrend({
    String? taskStateName,
    String? startTimeFrom,
    String? startTimeTo,
  }) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      if (startTimeFrom != null) {
        startTimeFromFilter.value = startTimeFrom;
      }
      if (startTimeTo != null) {
        startTimeToFilter.value = startTimeTo;
      }
      flowTrend.value = await _api.getFlowTrend(
        taskStateName: taskStateName,
        startTimeFrom: startTimeFromFilter.value,
        startTimeTo: startTimeToFilter.value,
      );
    } catch (error) {
      errorMessage.value = ApiException.from(error).message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadResolveDuration() async {
    try {
      resolveDurationData.value = await _api.getResolveDurationDistribution(
        startTimeFrom: startTimeFromFilter.value,
        startTimeTo: startTimeToFilter.value,
      );
    } catch (error) {
      errorMessage.value = ApiException.from(error).message;
    }
  }
}
