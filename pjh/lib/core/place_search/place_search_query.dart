import 'dart:math' as math;

enum PlaceSearchOriginType { device, mapCenter, manual, fallback }

class PlaceSearchOrigin {
  PlaceSearchOrigin({
    required this.type,
    required this.latitude,
    required this.longitude,
  }) {
    _validateCoordinates(latitude, longitude);
  }

  final PlaceSearchOriginType type;
  final double latitude;
  final double longitude;

  PlaceSearchOrigin copyWith({
    PlaceSearchOriginType? type,
    double? latitude,
    double? longitude,
  }) {
    return PlaceSearchOrigin(
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class PlaceSearchQuery {
  PlaceSearchQuery({
    required this.originType,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.category,
    required this.keyword,
    this.page = 1,
    this.size = 15,
  }) {
    _validateCoordinates(latitude, longitude);
    if (radiusM != null && (radiusM! < 1 || radiusM! > 20000)) {
      throw ArgumentError.value(radiusM, 'radiusM', 'must be 1..20000');
    }
    if (size < 1 || size > 15) {
      throw ArgumentError.value(size, 'size', 'must be 1..15');
    }
    if (page < 1 || page > 3 || page * size > 45) {
      throw ArgumentError.value(
        page,
        'page',
        'must be 1..3 and page * size must be <= 45',
      );
    }
    if (keyword.trim().isEmpty) {
      throw ArgumentError.value(keyword, 'keyword', 'must not be empty');
    }
  }

  final PlaceSearchOriginType originType;
  final double latitude;
  final double longitude;
  final int? radiusM;
  final String category;
  final String keyword;
  final int page;
  final int size;

  PlaceSearchOrigin get origin => PlaceSearchOrigin(
        type: originType,
        latitude: latitude,
        longitude: longitude,
      );

  PlaceSearchQuery copyWith({
    PlaceSearchOriginType? originType,
    double? latitude,
    double? longitude,
    int? radiusM,
    bool clearRadius = false,
    String? category,
    String? keyword,
    int? page,
    int? size,
  }) {
    return PlaceSearchQuery(
      originType: originType ?? this.originType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusM: clearRadius ? null : radiusM ?? this.radiusM,
      category: category ?? this.category,
      keyword: keyword ?? this.keyword,
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

  PlaceSearchQuery nextPage() => copyWith(page: page + 1);
}

class PlaceSearchItem {
  const PlaceSearchItem({
    this.provider = 'kakao',
    required this.providerPlaceId,
    required this.name,
    required this.category,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.placeUrl,
    this.distanceM,
  });

  final String provider;
  final String providerPlaceId;
  final String name;
  final String category;
  final String address;
  final String phone;
  final double latitude;
  final double longitude;
  final String placeUrl;
  final int? distanceM;

  PlaceSearchItem copyWith({
    int? distanceM,
    bool clearDistance = false,
  }) {
    return PlaceSearchItem(
      provider: provider,
      providerPlaceId: providerPlaceId,
      name: name,
      category: category,
      address: address,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      placeUrl: placeUrl,
      distanceM: clearDistance ? null : distanceM ?? this.distanceM,
    );
  }
}

class PlaceSearchPage {
  const PlaceSearchPage({
    required this.items,
    required this.isEnd,
    required this.pageableCount,
  });

  final List<PlaceSearchItem> items;
  final bool isEnd;
  final int pageableCount;
}

class PlaceSearchGeneration {
  int _value = 0;

  int get current => _value;

  int begin() => ++_value;

  bool isCurrent(int token) => token == _value;
}

int manualSearchCategoryIndex({
  required int currentCategoryIndex,
  required bool currentIsFavoriteTab,
  int fallbackCategoryIndex = 1,
}) {
  return currentIsFavoriteTab ? fallbackCategoryIndex : currentCategoryIndex;
}

enum CameraMoveDisposition { programmatic, user }

class PendingProgrammaticMove {
  const PendingProgrammaticMove({
    required this.token,
    required this.latitude,
    required this.longitude,
    required this.issuedAt,
  });

  final int token;
  final double latitude;
  final double longitude;
  final DateTime issuedAt;
}

class CameraMoveResolution {
  const CameraMoveResolution({
    required this.disposition,
    required this.consumePending,
  });

  final CameraMoveDisposition disposition;
  final bool consumePending;
}

CameraMoveResolution resolveCameraMove({
  required String? movedBy,
  required double latitude,
  required double longitude,
  required DateTime now,
  required int latestMoveToken,
  PendingProgrammaticMove? pending,
  double epsilonM = 40,
  Duration lifetime = const Duration(seconds: 4),
}) {
  if (movedBy == 'programmatic') {
    return const CameraMoveResolution(
      disposition: CameraMoveDisposition.programmatic,
      consumePending: true,
    );
  }
  if (movedBy == 'gesture') {
    return const CameraMoveResolution(
      disposition: CameraMoveDisposition.user,
      consumePending: true,
    );
  }

  final isEligiblePending = pending != null &&
      pending.token == latestMoveToken &&
      !now.isBefore(pending.issuedAt) &&
      now.difference(pending.issuedAt) <= lifetime;
  final isMatchingPending = isEligiblePending &&
      distanceMeters(
            latitude,
            longitude,
            pending.latitude,
            pending.longitude,
          ) <=
          epsilonM;

  return CameraMoveResolution(
    disposition: isMatchingPending
        ? CameraMoveDisposition.programmatic
        : CameraMoveDisposition.user,
    consumePending:
        isMatchingPending || (pending != null && !isEligiblePending),
  );
}

bool shouldShowResearch({
  required double searchLatitude,
  required double searchLongitude,
  required double cameraLatitude,
  required double cameraLongitude,
  required int radiusM,
}) {
  return distanceMeters(
        searchLatitude,
        searchLongitude,
        cameraLatitude,
        cameraLongitude,
      ) >
      radiusM * 0.3;
}

bool shouldFetchNextPlacePage({
  required int page,
  required int pageSize,
  required bool isEnd,
  required int pageableCount,
  required int uniqueCount,
  int maxPages = 3,
  int maxUnique = 30,
}) {
  if (page < 1 ||
      pageSize < 1 ||
      maxPages < 1 ||
      maxUnique < 1 ||
      pageableCount < 0 ||
      uniqueCount < 0) {
    throw ArgumentError('paging values must be non-negative and bounded');
  }
  return page < maxPages &&
      !isEnd &&
      page * pageSize < pageableCount &&
      uniqueCount < maxUnique;
}

List<PlaceSearchItem> mergePlaceSearchItems(
  Iterable<PlaceSearchItem> items, {
  required double originLatitude,
  required double originLongitude,
  int limit = 30,
}) {
  final byId = <String, PlaceSearchItem>{};
  for (final item in items) {
    if (item.providerPlaceId.isEmpty) continue;
    byId.putIfAbsent(item.providerPlaceId, () {
      final distance = item.distanceM ??
          distanceMeters(
            originLatitude,
            originLongitude,
            item.latitude,
            item.longitude,
          ).round();
      return item.copyWith(distanceM: distance);
    });
  }
  final merged = byId.values.toList()
    ..sort((a, b) {
      final byDistance =
          (a.distanceM ?? 0x7fffffff).compareTo(b.distanceM ?? 0x7fffffff);
      if (byDistance != 0) return byDistance;
      return a.providerPlaceId.compareTo(b.providerPlaceId);
    });
  if (merged.length <= limit) return merged;
  return merged.take(limit).toList(growable: false);
}

double distanceMeters(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  const earthRadiusM = 6371000.0;
  final lat1 = _toRadians(latitudeA);
  final lat2 = _toRadians(latitudeB);
  final deltaLat = _toRadians(latitudeB - latitudeA);
  final deltaLng = _toRadians(longitudeB - longitudeA);
  final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(deltaLng / 2) *
          math.sin(deltaLng / 2);
  final bounded = a.clamp(0.0, 1.0);
  return earthRadiusM *
      2 *
      math.atan2(math.sqrt(bounded), math.sqrt(1 - bounded));
}

double _toRadians(double degrees) => degrees * math.pi / 180;

void _validateCoordinates(double latitude, double longitude) {
  if (!latitude.isFinite || latitude < -90 || latitude > 90) {
    throw ArgumentError.value(latitude, 'latitude', 'must be -90..90');
  }
  if (!longitude.isFinite || longitude < -180 || longitude > 180) {
    throw ArgumentError.value(longitude, 'longitude', 'must be -180..180');
  }
}
