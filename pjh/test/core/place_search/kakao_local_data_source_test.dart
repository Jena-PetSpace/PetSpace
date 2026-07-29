import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meong_nyang_diary/core/place_search/kakao_local_data_source.dart';
import 'package:meong_nyang_diary/core/place_search/place_search_query.dart';

void main() {
  const apiKey = 'test-secret-key';

  PlaceSearchQuery query({int page = 1}) => PlaceSearchQuery(
        originType: PlaceSearchOriginType.device,
        latitude: 37.5,
        longitude: 127,
        radiusM: 3000,
        category: 'hospital',
        keyword: '동물병원',
        page: page,
      );

  test('parses valid documents and prefers road address', () async {
    final source = KakaoLocalDataSource(
      client: MockClient(
        (_) async => http.Response(
          '''
          {
            "documents": [
              {
                "id": "p1",
                "place_name": "튼튼 동물병원",
                "category_name": "의료 > 동물병원",
                "road_address_name": "도로명 주소",
                "address_name": "지번 주소",
                "phone": "02-000-0000",
                "x": "127.01",
                "y": "37.51",
                "place_url": "https://place.example/p1",
                "distance": "120"
              }
            ],
            "meta": {"is_end": true, "pageable_count": 1}
          }
          ''',
          200,
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        ),
      ),
      apiKey: apiKey,
    );

    final page = await source.search(query());

    expect(page.isEnd, isTrue);
    expect(page.pageableCount, 1);
    expect(page.items, hasLength(1));
    expect(page.items.single.address, '도로명 주소');
    expect(page.items.single.distanceM, 120);
  });

  test('accepts an empty document list', () async {
    final source = KakaoLocalDataSource(
      client: MockClient(
        (_) async => http.Response(
          '{"documents":[],"meta":{"is_end":true,"pageable_count":0}}',
          200,
        ),
      ),
      apiKey: apiKey,
    );

    expect((await source.search(query())).items, isEmpty);
  });

  test('omits radius for unbounded location-picker searches', () async {
    late Uri requestedUri;
    final source = KakaoLocalDataSource(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          '{"documents":[],"meta":{"is_end":true,"pageable_count":0}}',
          200,
        );
      }),
      apiKey: apiKey,
    );

    await source.search(
      PlaceSearchQuery(
        originType: PlaceSearchOriginType.device,
        latitude: 37.5,
        longitude: 127,
        radiusM: null,
        category: 'location_picker',
        keyword: '부산역',
      ),
    );

    expect(requestedUri.queryParameters, isNot(contains('radius')));
    expect(requestedUri.queryParameters['sort'], 'distance');
  });

  test('decodes UTF-8 even when the response omits a charset', () async {
    final source = KakaoLocalDataSource(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            '{"documents":[{"id":"p1","place_name":"서울동물병원",'
            '"address_name":"서울","x":"127","y":"37"}],'
            '"meta":{"is_end":true,"pageable_count":1}}',
          ),
          200,
        ),
      ),
      apiKey: apiKey,
    );

    expect((await source.search(query())).items.single.name, '서울동물병원');
  });

  test('rejects a malformed payload', () async {
    final source = KakaoLocalDataSource(
      client: MockClient((_) async => http.Response('{"meta":{}}', 200)),
      apiKey: apiKey,
    );

    await expectLater(
      source.search(query()),
      throwsA(
        isA<KakaoLocalSearchException>().having(
          (error) => error.kind,
          'kind',
          KakaoLocalFailureKind.invalidPayload,
        ),
      ),
    );
  });

  test('maps malformed document field types to invalid payload', () async {
    final source = KakaoLocalDataSource(
      client: MockClient(
        (_) async => http.Response(
          '''
          {
            "documents": [{"id": 42, "x": "127", "y": "37"}],
            "meta": {"is_end": true, "pageable_count": 1}
          }
          ''',
          200,
        ),
      ),
      apiKey: apiKey,
    );

    await expectLater(
      source.search(query()),
      throwsA(
        isA<KakaoLocalSearchException>().having(
          (error) => error.kind,
          'kind',
          KakaoLocalFailureKind.invalidPayload,
        ),
      ),
    );
  });

  test('drops documents without stable ids or valid coordinates', () async {
    final source = KakaoLocalDataSource(
      client: MockClient(
        (_) async => http.Response(
          '''
          {
            "documents": [
              {"id":"","x":"127","y":"37"},
              {"id":"bad","x":"not-a-number","y":"37"},
              {"id":"good","place_name":"good","x":"127","y":"37"}
            ],
            "meta":{"is_end":true,"pageable_count":3}
          }
          ''',
          200,
        ),
      ),
      apiKey: apiKey,
    );

    final result = await source.search(query());

    expect(result.items.map((item) => item.providerPlaceId), <String>['good']);
  });

  for (final entry in <int, KakaoLocalFailureKind>{
    401: KakaoLocalFailureKind.unauthorized,
    403: KakaoLocalFailureKind.unauthorized,
    429: KakaoLocalFailureKind.rateLimit,
    500: KakaoLocalFailureKind.server,
  }.entries) {
    test('maps HTTP ${entry.key} to ${entry.value.name}', () async {
      final source = KakaoLocalDataSource(
        client:
            MockClient((_) async => http.Response('private body', entry.key)),
        apiKey: apiKey,
      );

      await expectLater(
        source.search(query()),
        throwsA(
          isA<KakaoLocalSearchException>().having(
            (error) => error.kind,
            'kind',
            entry.value,
          ),
        ),
      );
    });
  }

  test('maps timeout without exposing the request', () async {
    final source = KakaoLocalDataSource(
      client: MockClient((_) => Completer<http.Response>().future),
      apiKey: apiKey,
      timeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      source.search(query()),
      throwsA(
        isA<KakaoLocalSearchException>()
            .having(
              (error) => error.kind,
              'kind',
              KakaoLocalFailureKind.timeout,
            )
            .having(
              (error) => error.toString(),
              'sanitized text',
              isNot(contains(apiKey)),
            ),
      ),
    );
  });

  test('maps client failures without exposing URI or key', () async {
    final source = KakaoLocalDataSource(
      client: MockClient(
        (_) async => throw http.ClientException(
          'failed $apiKey',
          Uri.parse('https://private.example/?query=secret'),
        ),
      ),
      apiKey: apiKey,
    );

    try {
      await source.search(query());
      fail('expected failure');
    } on KakaoLocalSearchException catch (error) {
      expect(error.kind, KakaoLocalFailureKind.offline);
      expect(error.toString(), isNot(contains(apiKey)));
      expect(error.toString(), isNot(contains('secret')));
      expect(error.toString(), isNot(contains('private.example')));
    }
  });

  test('maps other IO failures to offline', () async {
    final source = KakaoLocalDataSource(
      client: MockClient((_) async => throw const TlsException('private')),
      apiKey: apiKey,
    );

    await expectLater(
      source.search(query()),
      throwsA(
        isA<KakaoLocalSearchException>().having(
          (error) => error.kind,
          'kind',
          KakaoLocalFailureKind.offline,
        ),
      ),
    );
  });

  test('sends bounded Kakao query parameters', () async {
    late Uri requestUri;
    late String? authorization;
    final source = KakaoLocalDataSource(
      client: MockClient((request) async {
        requestUri = request.url;
        authorization = request.headers['Authorization'];
        return http.Response(
          '{"documents":[],"meta":{"is_end":true,"pageable_count":0}}',
          200,
        );
      }),
      apiKey: apiKey,
    );

    await source.search(query(page: 2));

    expect(requestUri.queryParameters['query'], '동물병원');
    expect(requestUri.queryParameters['x'], '127.0');
    expect(requestUri.queryParameters['y'], '37.5');
    expect(requestUri.queryParameters['radius'], '3000');
    expect(requestUri.queryParameters['page'], '2');
    expect(requestUri.queryParameters['size'], '15');
    expect(requestUri.queryParameters['sort'], 'distance');
    expect(authorization, 'KakaoAK $apiKey');
  });
}
