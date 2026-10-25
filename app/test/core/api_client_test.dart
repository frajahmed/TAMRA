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

  test('searchFoods sends q and limit and returns the results', () async {
    final adapter = FakeAdapter(
      200,
      '{"count": 1, "next": null, "previous": null, '
      '"results": [{"id": "f1", "name": "Apfel", "kcal": "52.00"}]}',
    );
    final results = await _client(adapter).searchFoods('apfel');
    expect(results.single['name'], 'Apfel');
    expect(adapter.lastRequest?.path, '/api/v1/foods/');
    expect(adapter.lastRequest?.queryParameters['q'], 'apfel');
    expect(adapter.lastRequest?.queryParameters['limit'], 30);
    expect(adapter.lastRequest?.queryParameters.containsKey('country'), isFalse);
  });

  test('foodByBarcode turns 404 into ApiError', () async {
    final adapter = FakeAdapter(404, '{"code": "not_found", "message": "Not found."}');
    await expectLater(
      _client(adapter).foodByBarcode('4000417025005'),
      throwsA(isA<ApiError>().having((error) => error.statusCode, 'statusCode', 404)),
    );
    expect(adapter.lastRequest?.path, '/api/v1/foods/barcode/4000417025005/');
  });

  test('createFood posts the data', () async {
    final adapter = FakeAdapter(201, '{"id": "f2", "name": "Brot"}');
    final food = await _client(adapter).createFood({'name': 'Brot', 'kcal': 250});
    expect(food['id'], 'f2');
    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, '/api/v1/foods/');
  });
}
