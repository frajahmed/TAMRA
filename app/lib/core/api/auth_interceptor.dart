import 'package:dio/dio.dart';

import '../auth/token_storage.dart';

/// Adds the access token to every request and renews it once on 401.
///
/// - Auth endpoints (login, register, refresh) are sent without a token.
/// - On 401: one refresh with the stored refresh token, then the original
///   request is repeated. If the refresh fails, the tokens are cleared and
///   [onSessionExpired] is called (the app shows the login screen).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.plainDio,
    required this.onSessionExpired,
  });

  final TokenStorage storage;

  /// A Dio without this interceptor, used for the refresh call and the retry.
  final Dio plainDio;
  final void Function() onSessionExpired;

  static const _retriedKey = 'tamra_retried';
  static const _publicPaths = [
    '/api/v1/auth/login/',
    '/api/v1/auth/register/',
    '/api/v1/auth/refresh/',
    '/api/v1/health/',
  ];

  static bool isPublic(String path) => _publicPaths.any(path.endsWith);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!isPublic(options.path)) {
      final access = await storage.readAccess();
      if (access != null) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    if (!isUnauthorized || isPublic(options.path) || options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }

    final refresh = await storage.readRefresh();
    if (refresh == null) {
      await _expire();
      handler.next(err);
      return;
    }

    try {
      final response = await plainDio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh/',
        data: {'refresh': refresh},
      );
      final data = response.data ?? const <String, dynamic>{};
      final newAccess = data['access'] as String;
      final newRefresh = (data['refresh'] as String?) ?? refresh;
      await storage.save(access: newAccess, refresh: newRefresh);

      options.headers['Authorization'] = 'Bearer $newAccess';
      options.extra[_retriedKey] = true;
      final retried = await plainDio.fetch<dynamic>(options);
      handler.resolve(retried);
    } on DioException {
      await _expire();
      handler.next(err);
    }
  }

  Future<void> _expire() async {
    await storage.clear();
    onSessionExpired();
  }
}
