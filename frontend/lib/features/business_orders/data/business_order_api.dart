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
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/business-orders',
        queryParameters: {'pageNo': pageNo, 'pageSize': pageSize},
      );
      return BusinessOrderPage.fromJson(response.data ?? const {});
    } catch (error) {
      throw ApiException.from(error);
    }
  }
}
