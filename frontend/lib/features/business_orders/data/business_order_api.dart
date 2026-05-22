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
  }) async {
    try {
      final params = <String, dynamic>{'pageNo': pageNo, 'pageSize': pageSize};
      if (proId != null && proId.isNotEmpty) {
        params['proId'] = proId;
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
}
