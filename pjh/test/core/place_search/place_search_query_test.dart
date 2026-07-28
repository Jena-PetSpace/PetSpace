import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/place_search/place_search_query.dart';

void main() {
  test('validates Kakao paging and radius bounds', () {
    PlaceSearchQuery valid() => PlaceSearchQuery(
          originType: PlaceSearchOriginType.device,
          latitude: 37.5,
          longitude: 127,
          radiusM: 3000,
          category: 'hospital',
          keyword: '동물병원',
        );

    expect(valid().nextPage().page, 2);
    expect(
      () => valid().copyWith(page: 4),
      throwsArgumentError,
    );
    expect(
      () => valid().copyWith(size: 16),
      throwsArgumentError,
    );
    expect(
      () => valid().copyWith(radiusM: 20001),
      throwsArgumentError,
    );
    expect(valid().copyWith(clearRadius: true).radiusM, isNull);
  });

  test('retains origin across category and radius changes', () {
    final query = PlaceSearchQuery(
      originType: PlaceSearchOriginType.mapCenter,
      latitude: 37.51,
      longitude: 127.01,
      radiusM: 1000,
      category: 'hospital',
      keyword: '동물병원',
    );

    final changed = query.copyWith(
      radiusM: 5000,
      category: 'cafe',
      keyword: '반려동물카페',
    );

    expect(changed.originType, PlaceSearchOriginType.mapCenter);
    expect(changed.latitude, query.latitude);
    expect(changed.longitude, query.longitude);
  });

  test('generation rejects an older response after a newer search', () {
    final generation = PlaceSearchGeneration();
    final a = generation.begin();
    final b = generation.begin();

    expect(generation.isCurrent(b), isTrue);
    expect(generation.isCurrent(a), isFalse);
  });

  test('paging stops at provider, page, and unique-result budgets', () {
    expect(
      shouldFetchNextPlacePage(
        page: 1,
        pageSize: 15,
        isEnd: false,
        pageableCount: 45,
        uniqueCount: 15,
      ),
      isTrue,
    );
    for (final stop in <bool>[
      shouldFetchNextPlacePage(
        page: 1,
        pageSize: 15,
        isEnd: true,
        pageableCount: 45,
        uniqueCount: 15,
      ),
      shouldFetchNextPlacePage(
        page: 3,
        pageSize: 15,
        isEnd: false,
        pageableCount: 45,
        uniqueCount: 29,
      ),
      shouldFetchNextPlacePage(
        page: 2,
        pageSize: 15,
        isEnd: false,
        pageableCount: 30,
        uniqueCount: 29,
      ),
      shouldFetchNextPlacePage(
        page: 2,
        pageSize: 15,
        isEnd: false,
        pageableCount: 45,
        uniqueCount: 30,
      ),
    ]) {
      expect(stop, isFalse);
    }
  });

  for (final radius in <int>[1000, 3000, 5000]) {
    test('re-search threshold is strict at 30% for radius $radius', () {
      const latitude = 37.5;
      const longitude = 127.0;
      final threshold = radius * 0.3;
      const degreesPerMeter = 1 / 111195.0;

      expect(
        shouldShowResearch(
          searchLatitude: latitude,
          searchLongitude: longitude,
          cameraLatitude: latitude + (threshold - 1) * degreesPerMeter,
          cameraLongitude: longitude,
          radiusM: radius,
        ),
        isFalse,
      );
      expect(
        shouldShowResearch(
          searchLatitude: latitude,
          searchLongitude: longitude,
          cameraLatitude: latitude + threshold * degreesPerMeter,
          cameraLongitude: longitude,
          radiusM: radius,
        ),
        isFalse,
      );
      expect(
        shouldShowResearch(
          searchLatitude: latitude,
          searchLongitude: longitude,
          cameraLatitude: latitude + (threshold + 2) * degreesPerMeter,
          cameraLongitude: longitude,
          radiusM: radius,
        ),
        isTrue,
      );
    });
  }

  test('reconciles explicit and nullable camera movement origins', () {
    final now = DateTime.utc(2026, 7, 28, 12);
    final pending = PendingProgrammaticMove(
      token: 3,
      latitude: 37.5,
      longitude: 127,
      issuedAt: now.subtract(const Duration(seconds: 1)),
    );

    expect(
      resolveCameraMove(
        movedBy: 'programmatic',
        latitude: 0,
        longitude: 0,
        now: now,
        latestMoveToken: 3,
        pending: pending,
      ).disposition,
      CameraMoveDisposition.programmatic,
    );
    expect(
      resolveCameraMove(
        movedBy: 'gesture',
        latitude: 37.5,
        longitude: 127,
        now: now,
        latestMoveToken: 3,
        pending: pending,
      ).disposition,
      CameraMoveDisposition.user,
    );
    for (final movedBy in <String?>[null, 'unknown']) {
      final matching = resolveCameraMove(
        movedBy: movedBy,
        latitude: 37.5001,
        longitude: 127,
        now: now,
        latestMoveToken: 3,
        pending: pending,
      );
      expect(matching.disposition, CameraMoveDisposition.programmatic);
      expect(matching.consumePending, isTrue);

      final nonMatching = resolveCameraMove(
        movedBy: movedBy,
        latitude: 37.51,
        longitude: 127,
        now: now,
        latestMoveToken: 3,
        pending: pending,
      );
      expect(nonMatching.disposition, CameraMoveDisposition.user);
      expect(nonMatching.consumePending, isFalse);
    }
  });

  test('keeps an eligible pending move after unrelated nullable event', () {
    final now = DateTime.utc(2026, 7, 28, 12);
    final pending = PendingProgrammaticMove(
      token: 4,
      latitude: 37.5,
      longitude: 127,
      issuedAt: now.subtract(const Duration(seconds: 1)),
    );

    final unrelated = resolveCameraMove(
      movedBy: null,
      latitude: 37.51,
      longitude: 127,
      now: now,
      latestMoveToken: 4,
      pending: pending,
    );
    final matching = resolveCameraMove(
      movedBy: null,
      latitude: 37.5001,
      longitude: 127,
      now: now.add(const Duration(milliseconds: 100)),
      latestMoveToken: 4,
      pending: pending,
    );

    expect(unrelated.disposition, CameraMoveDisposition.user);
    expect(unrelated.consumePending, isFalse);
    expect(matching.disposition, CameraMoveDisposition.programmatic);
    expect(matching.consumePending, isTrue);
  });

  test('explicit movement origins always consume pending state', () {
    final now = DateTime.utc(2026, 7, 28, 12);
    final pending = PendingProgrammaticMove(
      token: 3,
      latitude: 37.5,
      longitude: 127,
      issuedAt: now,
    );

    for (final movedBy in <String>['programmatic', 'gesture']) {
      expect(
        resolveCameraMove(
          movedBy: movedBy,
          latitude: 37.5,
          longitude: 127,
          now: now,
          latestMoveToken: 3,
          pending: pending,
        ).consumePending,
        isTrue,
      );
    }
  });

  test('expires and supersedes pending programmatic moves', () {
    final now = DateTime.utc(2026, 7, 28, 12);
    final stale = PendingProgrammaticMove(
      token: 2,
      latitude: 37.5,
      longitude: 127,
      issuedAt: now.subtract(const Duration(seconds: 5)),
    );
    final superseded = PendingProgrammaticMove(
      token: 2,
      latitude: 37.5,
      longitude: 127,
      issuedAt: now,
    );

    expect(
      resolveCameraMove(
        movedBy: null,
        latitude: 37.5,
        longitude: 127,
        now: now,
        latestMoveToken: 2,
        pending: stale,
      ).disposition,
      CameraMoveDisposition.user,
    );
    expect(
      resolveCameraMove(
        movedBy: null,
        latitude: 37.5,
        longitude: 127,
        now: now,
        latestMoveToken: 3,
        pending: superseded,
      ).disposition,
      CameraMoveDisposition.user,
    );
  });

  test('merges by id and sorts by distance then stable id', () {
    const a = PlaceSearchItem(
      providerPlaceId: 'a',
      name: 'A',
      category: '',
      address: '',
      phone: '',
      latitude: 37.5,
      longitude: 127,
      placeUrl: '',
      distanceM: 200,
    );
    const b = PlaceSearchItem(
      providerPlaceId: 'b',
      name: 'B',
      category: '',
      address: '',
      phone: '',
      latitude: 37.5,
      longitude: 127,
      placeUrl: '',
      distanceM: 100,
    );

    final merged = mergePlaceSearchItems(
      <PlaceSearchItem>[a, b, a],
      originLatitude: 37.5,
      originLongitude: 127,
    );

    expect(
      merged.map((item) => item.providerPlaceId),
      <String>['b', 'a'],
    );
  });

  test('manual query remains independent of a category label', () {
    final query = PlaceSearchQuery(
      originType: PlaceSearchOriginType.manual,
      latitude: 37.5,
      longitude: 127,
      radiusM: 3000,
      category: '',
      keyword: '24시 응급',
    );

    expect(query.originType, PlaceSearchOriginType.manual);
    expect(query.category, isEmpty);
    expect(query.keyword, '24시 응급');
  });

  test('manual search preserves category unless favorites is active', () {
    expect(
      manualSearchCategoryIndex(
        currentCategoryIndex: 3,
        currentIsFavoriteTab: false,
      ),
      3,
    );
    expect(
      manualSearchCategoryIndex(
        currentCategoryIndex: 0,
        currentIsFavoriteTab: true,
      ),
      1,
    );
  });
}
