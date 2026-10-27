import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/token_storage.dart';
import '../config.dart';
import 'auth_interceptor.dart';

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

  /// True when the server was not reached (offline, timeout), not for API errors.
  bool get isNetworkError => code == 'network_error';

  /// The first message of every field error, for showing under a form.
  List<String> get fieldMessages => [
        for (final value in fields.values)
          if (value is List && value.isNotEmpty) value.first.toString() else value.toString(),
      ];

  @override
  String toString() => 'ApiError($code, $statusCode): $message';
}

/// Access and refresh token pair.
class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});

  final String access;
  final String refresh;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        access: json['access'] as String,
        refresh: json['refresh'] as String,
      );
}

/// The only place where the app talks HTTP to the TAMRA API.
/// Features call methods here (or in repositories that use it), never Dio directly.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiError.fromDio(error);
    }
  }

  Map<String, dynamic> _map(Response<Map<String, dynamic>> response) =>
      response.data ?? const <String, dynamic>{};

  /// GET /api/v1/health/ → true when the server answers {"status": "ok"}.
  Future<bool> health() => _call(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/health/');
        return response.data?['status'] == 'ok';
      });

  // --- Auth -----------------------------------------------------------------

  /// POST /auth/register/ → tokens of the new account.
  Future<AuthTokens> register(String email, String password) => _call(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/auth/register/',
          data: {'email': email, 'password': password},
        );
        return AuthTokens.fromJson(_map(response));
      });

  /// POST /auth/login/ → access and refresh token.
  Future<AuthTokens> login(String email, String password) => _call(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/auth/login/',
          data: {'email': email, 'password': password},
        );
        return AuthTokens.fromJson(_map(response));
      });

  /// POST /auth/logout/ → the refresh token is blacklisted on the server.
  Future<void> logout(String refreshToken) => _call(() async {
        await _dio.post<dynamic>('/api/v1/auth/logout/', data: {'refresh': refreshToken});
      });

  // --- Profile and consents ---------------------------------------------------

  /// GET /me/profile/ → body data, targets and settings.
  Future<Map<String, dynamic>> getProfile() => _call(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/v1/me/profile/');
        return _map(response);
      });

  /// PATCH /me/profile/ → the saved profile with recalculated targets.
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> changes) =>
      _call(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          '/api/v1/me/profile/',
          data: changes,
        );
        return _map(response);
      });

  /// GET /me/consents/ → all consents of the user.
  Future<List<Map<String, dynamic>>> listConsents() => _call(() async {
        final response = await _dio.get<List<dynamic>>('/api/v1/me/consents/');
        return [
          for (final item in response.data ?? const <dynamic>[])
            if (item is Map<String, dynamic>) item,
        ];
      });

  /// POST /me/consents/ → stores a consent of [type] in [version].
  Future<void> giveConsent(String type, String version) => _call(() async {
        await _dio.post<dynamic>(
          '/api/v1/me/consents/',
          data: {'type': type, 'version': version},
        );
      });

  /// POST `/me/consents/<type>/withdraw/` → the consent is marked as withdrawn.
  Future<void> withdrawConsent(String type) => _call(() async {
        await _dio.post<dynamic>('/api/v1/me/consents/${Uri.encodeComponent(type)}/withdraw/');
      });

  /// GET `/me/export/` → all personal data as JSON text (GDPR Art. 15 and 20).
  Future<String> exportData() => _call(() async {
        final response = await _dio.get<String>(
          '/api/v1/me/export/',
          options: Options(responseType: ResponseType.plain),
        );
        return response.data ?? '{}';
      });

  /// DELETE `/me/` with the password → account and all data are deleted for good.
  Future<void> deleteAccount(String password) => _call(() async {
        await _dio.delete<dynamic>('/api/v1/me/', data: {'password': password});
      });

  // --- Foods ----------------------------------------------------------------

  /// GET /api/v1/foods/?q= → the `results` of the first page.
  Future<List<Map<String, dynamic>>> searchFoods(
    String query, {
    String? country,
    int limit = 30,
  }) =>
      _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/v1/foods/',
          queryParameters: {
            'q': query,
            'limit': limit,
            if (country != null && country.isNotEmpty) 'country': country,
          },
        );
        final results = _map(response)['results'];
        return [
          if (results is List)
            for (final item in results)
              if (item is Map<String, dynamic>) item,
        ];
      });

  /// GET `/foods/barcode/<code>/` → the food; [ApiError] with status 404 when unknown.
  Future<Map<String, dynamic>> foodByBarcode(String barcode) => _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/v1/foods/barcode/${Uri.encodeComponent(barcode)}/',
        );
        return _map(response);
      });

  /// GET `/foods/<id>/` → one food.
  Future<Map<String, dynamic>> foodById(String id) => _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/v1/foods/${Uri.encodeComponent(id)}/',
        );
        return _map(response);
      });

  /// POST /foods/ → creates an own food and returns it.
  Future<Map<String, dynamic>> createFood(Map<String, dynamic> data) => _call(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/foods/', data: data);
        return _map(response);
      });

  // --- Diary ----------------------------------------------------------------

  /// GET `/diary/?date=` → all entries of one day.
  Future<List<Map<String, dynamic>>> listDiary(String date) => _call(() async {
        final response = await _dio.get<List<dynamic>>(
          '/api/v1/diary/',
          queryParameters: {'date': date},
        );
        return [
          for (final item in response.data ?? const <dynamic>[])
            if (item is Map<String, dynamic>) item,
        ];
      });

  /// GET `/diary/summary/?date=` → totals, targets and the energy unit of one day.
  Future<Map<String, dynamic>> diarySummary(String date) => _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/v1/diary/summary/',
          queryParameters: {'date': date},
        );
        return _map(response);
      });

  /// POST `/diary/` → the saved entry with the nutrient snapshot.
  Future<Map<String, dynamic>> createDiaryEntry(Map<String, dynamic> data) => _call(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/diary/', data: data);
        return _map(response);
      });

  /// PATCH `/diary/<id>/` → the changed entry (amount or meal).
  Future<Map<String, dynamic>> updateDiaryEntry(String id, Map<String, dynamic> changes) =>
      _call(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          '/api/v1/diary/${Uri.encodeComponent(id)}/',
          data: changes,
        );
        return _map(response);
      });

  /// DELETE `/diary/<id>/` → the entry is removed (soft delete on the server).
  Future<void> deleteDiaryEntry(String id) => _call(() async {
        await _dio.delete<dynamic>('/api/v1/diary/${Uri.encodeComponent(id)}/');
      });

  /// POST `/diary/copy/` → copies a day (or one meal) to another day; returns the count.
  Future<int> copyDiary(Map<String, dynamic> body) => _call(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/v1/diary/copy/', data: body);
        final copied = _map(response)['copied'];
        return copied is int ? copied : 0;
      });

  // --- Weight and water -------------------------------------------------------

  /// GET `/weight/?from=&to=` → weights, newest first.
  Future<List<Map<String, dynamic>>> listWeights({String? from, String? to}) =>
      _call(() async {
        final response = await _dio.get<List<dynamic>>(
          '/api/v1/weight/',
          queryParameters: {if (from != null) 'from': from, if (to != null) 'to': to},
        );
        return _list(response.data);
      });

  /// POST `/weight/` → saves the weight of a day (a second POST for the same day updates it).
  Future<Map<String, dynamic>> saveWeight(String date, double weightKg) => _call(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/weight/',
          data: {'date': date, 'weight_kg': weightKg.toStringAsFixed(1)},
        );
        return _map(response);
      });

  /// DELETE `/weight/<id>/`.
  Future<void> deleteWeight(String id) => _call(() async {
        await _dio.delete<dynamic>('/api/v1/weight/${Uri.encodeComponent(id)}/');
      });

  /// GET `/water/?date=` → water entries of one day, newest first.
  Future<List<Map<String, dynamic>>> listWater(String date) => _call(() async {
        final response = await _dio.get<List<dynamic>>(
          '/api/v1/water/',
          queryParameters: {'date': date},
        );
        return _list(response.data);
      });

  /// POST `/water/` → one glass or bottle.
  Future<Map<String, dynamic>> addWater(String date, int amountMl) => _call(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/water/',
          data: {'date': date, 'amount_ml': amountMl},
        );
        return _map(response);
      });

  /// DELETE `/water/<id>/`.
  Future<void> deleteWater(String id) => _call(() async {
        await _dio.delete<dynamic>('/api/v1/water/${Uri.encodeComponent(id)}/');
      });

  // --- Statistics -------------------------------------------------------------

  /// GET `/stats/summary/?from=&to=` → totals per day, averages and weight change.
  Future<Map<String, dynamic>> statsSummary(String from, String to) => _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/v1/stats/summary/',
          queryParameters: {'from': from, 'to': to},
        );
        return _map(response);
      });

  List<Map<String, dynamic>> _list(List<dynamic>? data) => [
        for (final item in data ?? const <dynamic>[])
          if (item is Map<String, dynamic>) item,
      ];
}

BaseOptions _baseOptions() => BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );

/// HTTP client with base URL, timeouts and automatic token refresh ([AuthInterceptor]).
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      plainDio: Dio(_baseOptions()),
      onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired(),
    ),
  );
  return dio;
});

/// The [ApiClient] used by all repositories.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
