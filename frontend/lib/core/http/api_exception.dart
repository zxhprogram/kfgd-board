import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;

  static ApiException from(Object error) {
    if (error is ApiException) {
      return error;
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        return ApiException(data['error'].toString());
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return const ApiException('请求超时，请稍后重试');
      }
      if (error.response?.statusCode != null) {
        return ApiException('请求失败：HTTP ${error.response!.statusCode}');
      }
      return const ApiException('无法连接后端服务，请确认 backend 已启动');
    }
    return ApiException(error.toString());
  }
}
