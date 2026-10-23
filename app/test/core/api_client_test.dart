import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/api/api_client.dart';

/// Answers every request with a fixed status and JSON body. No network.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.statusCode, this.body);

  final int statusCode;
  final String body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  return ApiClient(dio);
}

void main() {
  test('health returns true for {"status": "ok"}', () async {
    final adapter = FakeAdapter(200, '{"status": "ok"}');
    expect(await _client(adapter).health(), isTrue);
    expect(adapter.lastRequest?.path, '/api/v1/health/');
  });

  test('health returns false for any other status', () async {
    expect(await _client(FakeAdapter(200, '{"status": "down"}')).health(), isFalse);
  });

  test('API errors are parsed into ApiError', () async {
    final adapter = FakeAdapter(
      400,
      '{"code": "validation_error", "message": "Invalid input.", '
      '"fields": {"email": ["Required."]}}',
    );
    await expectLater(
      _client(adapter).health(),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', 'validation_error')
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.fields['email'], 'fields.email', ['Required.']),
      ),
    );
  });
}
