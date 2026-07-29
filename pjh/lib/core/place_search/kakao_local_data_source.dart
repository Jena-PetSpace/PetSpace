import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'place_search_query.dart';

enum KakaoLocalFailureKind {
  unauthorized,
  rateLimit,
  timeout,
  offline,
  server,
  invalidPayload,
}

class KakaoLocalSearchException implements Exception {
  const KakaoLocalSearchException(this.kind, {this.statusCode});

  final KakaoLocalFailureKind kind;
  final int? statusCode;

  @override
  String toString() {
    final status = statusCode == null ? '' : ', status=$statusCode';
    return 'KakaoLocalSearchException(${kind.name}$status)';
  }
}

class KakaoLocalDataSource {
  KakaoLocalDataSource({
    required http.Client client,
    required String apiKey,
    this.timeout = const Duration(seconds: 10),
  })  : _client = client,
        _apiKey = apiKey;

  static final Uri _endpoint =
      Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json');

  final http.Client _client;
  final String _apiKey;
  final Duration timeout;

  Future<PlaceSearchPage> search(PlaceSearchQuery query) async {
    final queryParameters = <String, String>{
      'query': query.keyword.trim(),
      'x': query.longitude.toString(),
      'y': query.latitude.toString(),
      'sort': 'distance',
      'page': query.page.toString(),
      'size': query.size.toString(),
    };
    final radiusM = query.radiusM;
    if (radiusM != null) {
      queryParameters['radius'] = radiusM.toString();
    }
    final uri = _endpoint.replace(
      queryParameters: queryParameters,
    );

    late final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: <String, String>{'Authorization': 'KakaoAK $_apiKey'},
      ).timeout(timeout);
    } on TimeoutException {
      throw const KakaoLocalSearchException(KakaoLocalFailureKind.timeout);
    } on IOException {
      throw const KakaoLocalSearchException(KakaoLocalFailureKind.offline);
    } on http.ClientException {
      throw const KakaoLocalSearchException(KakaoLocalFailureKind.offline);
    } catch (_) {
      throw const KakaoLocalSearchException(
        KakaoLocalFailureKind.invalidPayload,
      );
    }

    try {
      return _parseResponse(response);
    } on KakaoLocalSearchException {
      rethrow;
    } on FormatException {
      throw const KakaoLocalSearchException(
        KakaoLocalFailureKind.invalidPayload,
      );
    } catch (_) {
      throw const KakaoLocalSearchException(
        KakaoLocalFailureKind.invalidPayload,
      );
    }
  }

  PlaceSearchPage _parseResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw KakaoLocalSearchException(
        KakaoLocalFailureKind.unauthorized,
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 429) {
      throw const KakaoLocalSearchException(
        KakaoLocalFailureKind.rateLimit,
        statusCode: 429,
      );
    }
    if (response.statusCode >= 500) {
      throw KakaoLocalSearchException(
        KakaoLocalFailureKind.server,
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw KakaoLocalSearchException(
        KakaoLocalFailureKind.invalidPayload,
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const KakaoLocalSearchException(
        KakaoLocalFailureKind.invalidPayload,
      );
    }
    final documents = decoded['documents'];
    final meta = decoded['meta'];
    if (documents is! List || meta is! Map<String, dynamic>) {
      throw const KakaoLocalSearchException(
        KakaoLocalFailureKind.invalidPayload,
      );
    }
    final isEnd = meta['is_end'];
    final pageableCount = meta['pageable_count'];
    if (isEnd is! bool || pageableCount is! num) {
      throw const KakaoLocalSearchException(
        KakaoLocalFailureKind.invalidPayload,
      );
    }

    final items = <PlaceSearchItem>[];
    for (final document in documents) {
      if (document is! Map) continue;
      final json = document.cast<String, dynamic>();
      final id = json['id'] as String? ?? '';
      final latitude = double.tryParse(json['y'] as String? ?? '');
      final longitude = double.tryParse(json['x'] as String? ?? '');
      if (id.isEmpty ||
          latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        continue;
      }
      final roadAddress = json['road_address_name'] as String? ?? '';
      items.add(
        PlaceSearchItem(
          providerPlaceId: id,
          name: json['place_name'] as String? ?? '',
          category: json['category_name'] as String? ?? '',
          address: roadAddress.isNotEmpty
              ? roadAddress
              : json['address_name'] as String? ?? '',
          phone: json['phone'] as String? ?? '',
          latitude: latitude,
          longitude: longitude,
          placeUrl: json['place_url'] as String? ?? '',
          distanceM: int.tryParse(json['distance'] as String? ?? ''),
        ),
      );
    }
    return PlaceSearchPage(
      items: List<PlaceSearchItem>.unmodifiable(items),
      isEnd: isEnd,
      pageableCount: pageableCount.toInt(),
    );
  }
}
