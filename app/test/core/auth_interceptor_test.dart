import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/api/auth_interceptor.dart';
import 'package:tamra_app/core/auth/token_storage.dart';

/// Fake server: answers by path and Authorization header. No network.
class FakeServer implements HttpClientAdapter {
  FakeServer({this.refreshWorks = true});

  final bool refreshWorks;
  final List<String> log = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'];
    log.add('${options.path} $auth');

    if (options.path == '/api/v1/auth/refresh/') {
      return refreshWorks
          ? _json(200, {'access': 'new-access', 'refresh': 'new-refresh'})
          : _json(401,
              {'code': 'token_not_valid', 'message': 'expired', 'fields': {}});
    }
    if (auth == 'Bearer new-access') {
      return _json(200, {'ok': true});
    }
    return _json(
        401, {'code': 'token_not_valid', 'message': 'expired', 'fields': {}});
  }

  ResponseBody _json(int status, Map<String, dynamic> body) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeServer server;
  late MemoryTokenStorage storage;
  late int expiredCalls;

  Dio dio() {
    final plain = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    final main = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    main.interceptors.add(
      AuthInterceptor(
        storage: storage,
        plainDio: plain,
        onSessionExpired: () => expiredCalls++,
      ),
    );
    return main;
  }

  setUp(() {
    storage = MemoryTokenStorage(access: 'old-access', refresh: 'old-refresh');
    expiredCalls = 0;
  });

  test('adds the bearer token, refreshes once on 401 and repeats the request',
      () async {
    server = FakeServer();
    final response =
        await dio().get<Map<String, dynamic>>('/api/v1/me/profile/');

    expect(response.data, {'ok': true});
    expect(storage.access, 'new-access');
    expect(storage.refresh, 'new-refresh');
    expect(server.log, [
      '/api/v1/me/profile/ Bearer old-access',
      '/api/v1/auth/refresh/ null',
      '/api/v1/me/profile/ Bearer new-access',
    ]);
    expect(expiredCalls, 0);
  });

  test('failed refresh clears tokens and reports an expired session', () async {
    server = FakeServer(refreshWorks: false);

    await expectLater(
      dio().get<dynamic>('/api/v1/me/profile/'),
      throwsA(isA<DioException>()),
    );
    expect(storage.access, isNull);
    expect(expiredCalls, 1);
  });

  test('public endpoints are sent without a token', () async {
    server = FakeServer();
    await expectLater(
      dio().post<dynamic>('/api/v1/auth/login/',
          data: {'email': 'a', 'password': 'b'}),
      throwsA(isA<DioException>()),
    );
    expect(server.log, ['/api/v1/auth/login/ null']);
    expect(expiredCalls, 0);
  });

  test('isPublic recognises auth endpoints', () {
    expect(AuthInterceptor.isPublic('/api/v1/auth/register/'), isTrue);
    expect(AuthInterceptor.isPublic('/api/v1/me/profile/'), isFalse);
  });
}
