import 'package:dio/dio.dart';

import '../../../core/http/api_exception.dart';
import 'business_order_models.dart';

class BusinessOrderApi {
  const BusinessOrderApi(this._dio);

  final Dio _dio;

  Future<ImportBusinessOrdersResponse> importBusinessOrders(
    List<BusinessOrderImportItem> orders,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/business-orders/import',
        data: {'orders': orders.map((order) => order.toJson()).toList()},
      );
      return ImportBusinessOrdersResponse.fromJson(response.data ?? const {});
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<BusinessOrderPage> listBusinessOrders({
    required int pageNo,
    required int pageSize,
    String? proId,
    int? proState,
    String? startTimeFrom,
    String? startTimeTo,
    String? resolveTimeFrom,
    String? resolveTimeTo,
  }) async {
    try {
      final params = <String, dynamic>{'pageNo': pageNo, 'pageSize': pageSize};
      if (proId != null && proId.isNotEmpty) {
        params['proId'] = proId;
      }
      if (proState != null) {
        params['proState'] = proState;
      }
      if (startTimeFrom != null && startTimeFrom.isNotEmpty) {
        params['startTimeFrom'] = startTimeFrom;
      }
      if (startTimeTo != null && startTimeTo.isNotEmpty) {
        params['startTimeTo'] = startTimeTo;
      }
      if (resolveTimeFrom != null && resolveTimeFrom.isNotEmpty) {
        params['resolveTimeFrom'] = resolveTimeFrom;
      }
      if (resolveTimeTo != null && resolveTimeTo.isNotEmpty) {
        params['resolveTimeTo'] = resolveTimeTo;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/business-orders',
        queryParameters: params,
      );
      return BusinessOrderPage.fromJson(response.data ?? const {});
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<List<DailyCount>> getFlowTrend({
    String? taskStateName,
    String? startTimeFrom,
    String? startTimeTo,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (taskStateName != null && taskStateName.isNotEmpty) {
        params['taskStateName'] = taskStateName;
      }
      if (startTimeFrom != null && startTimeFrom.isNotEmpty) {
        params['startTimeFrom'] = startTimeFrom;
      }
      if (startTimeTo != null && startTimeTo.isNotEmpty) {
        params['startTimeTo'] = startTimeTo;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/business-orders/flow-trend',
        queryParameters: params,
      );
      final items = (response.data?['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map((item) => DailyCount.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<Map<String, dynamic>> syncBusinessOrders({
    required int pageNo,
    required int pageSize,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/business-orders/sync',
        queryParameters: {'pageNo': pageNo, 'pageSize': pageSize},
      );
      return response.data ?? const {};
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<List<DurationBucket>> getResolveDurationDistribution({
    String? startTimeFrom,
    String? startTimeTo,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (startTimeFrom != null && startTimeFrom.isNotEmpty) {
        params['startTimeFrom'] = startTimeFrom;
      }
      if (startTimeTo != null && startTimeTo.isNotEmpty) {
        params['startTimeTo'] = startTimeTo;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/business-orders/resolve-duration-distribution',
        queryParameters: params,
      );
      final items = (response.data?['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map((item) => DurationBucket.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<BusinessOrderItem> getBusinessOrderDetail(String proId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/business-orders/$proId',
      );
      return BusinessOrderItem.fromJson(response.data ?? const {});
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<List<BusinessOrderItem>> getChildOrders(String proId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/business-orders/$proId/children',
      );
      final items = (response.data?['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map((item) => BusinessOrderItem.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (error) {
      throw ApiException.from(error);
    }
  }
}
