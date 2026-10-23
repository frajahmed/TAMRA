import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';

/// Error in the API's uniform format: {"code", "message", "fields"}.
class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.fields = const {},
    this.statusCode,
  });

  final String code;
  final String message;
  final Map<String, dynamic> fields;
  final int? statusCode;

  factory ApiError.fromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final fields = data['fields'];
      return ApiError(
        code: data['code']?.toString() ?? 'error',
        message: data['message']?.toString() ?? 'Error',
        fields: fields is Map<String, dynamic> ? fields : const {},
        statusCode: error.response?.statusCode,
      );
    }
    return ApiError(
      code: 'network_error',
      message: error.message ?? 'Network error',
      statusCode: error.response?.statusCode,
    );
  }

  @override
  String toString() => 'ApiError($code, $statusCode): $message';
}

/// The only place where the app talks HTTP to the TAMRA API.
/// Features call methods here (or in repositories that use it), never Dio directly.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  /// GET /api/v1/health/ → true when the server answers {"status": "ok"}.
  Future<bool> health() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/v1/health/');
      return response.data?['status'] == 'ok';
    } on DioException catch (error) {
      throw ApiError.fromDio(error);
    }
  }
}

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
