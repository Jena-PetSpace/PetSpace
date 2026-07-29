import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/place_search/place_search_query.dart';
import 'package:meong_nyang_diary/core/place_search/saved_place_local_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const legacyIds = <String>['legacy-1', 'legacy-2'];
  const place = PlaceSearchItem(
    providerPlaceId: 'legacy-1',
    name: '튼튼 동물병원',
    category: '동물병원',
    address: '서울',
    phone: '',
    latitude: 37.5,
    longitude: 127,
    placeUrl: '',
  );

  Future<SharedPreferences> preferences({
    Map<String, Object> values = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('loads unresolved legacy ids without changing the legacy key', () async {
    final prefs = await preferences(
      values: <String, Object>{
        SavedPlaceLocalDataSource.legacyKey: legacyIds,
      },
    );
    final source = SavedPlaceLocalDataSource(preferences: prefs);

    final catalog = source.load();

    expect(catalog.unresolvedLegacyIds, legacyIds.toSet());
    expect(
      prefs.getStringList(SavedPlaceLocalDataSource.legacyKey),
      legacyIds,
    );
  });

  test('promotes rediscovered legacy id and is idempotent', () async {
    final prefs = await preferences(
      values: <String, Object>{
        SavedPlaceLocalDataSource.legacyKey: legacyIds,
      },
    );
    final source = SavedPlaceLocalDataSource(preferences: prefs);
    final initial = source.load();

    final promoted =
        await source.promote(initial, const <PlaceSearchItem>[place]);
    final repeated =
        await source.promote(promoted, const <PlaceSearchItem>[place]);

    expect(promoted.snapshots.keys, contains('legacy-1'));
    expect(promoted.unresolvedLegacyIds, <String>{'legacy-2'});
    expect(repeated.snapshots.keys, promoted.snapshots.keys);
    expect(
      prefs.getStringList(SavedPlaceLocalDataSource.legacyKey),
      legacyIds,
    );
  });

  test('unsave tombstones legacy id and re-save removes tombstone', () async {
    final prefs = await preferences(
      values: <String, Object>{
        SavedPlaceLocalDataSource.legacyKey: legacyIds,
      },
    );
    final source = SavedPlaceLocalDataSource(preferences: prefs);
    final promoted =
        await source.promote(source.load(), const <PlaceSearchItem>[place]);

    final removed = await source.remove(promoted, 'legacy-1');
    final saved = await source.save(removed, place);

    expect(removed.favoriteIds, isNot(contains('legacy-1')));
    expect(removed.removedLegacyIds, contains('legacy-1'));
    expect(saved.favoriteIds, contains('legacy-1'));
    expect(saved.removedLegacyIds, isNot(contains('legacy-1')));
    expect(
      prefs.getStringList(SavedPlaceLocalDataSource.legacyKey),
      legacyIds,
    );
  });

  test('restores snapshot offline and deduplicates by id', () async {
    final prefs = await preferences(
      values: <String, Object>{
        SavedPlaceLocalDataSource.legacyKey: legacyIds,
      },
    );
    final source = SavedPlaceLocalDataSource(preferences: prefs);
    var catalog = source.load();
    catalog = await source.save(catalog, place);
    catalog = await source.save(catalog, place);

    final reloaded = source.load();

    expect(reloaded.snapshots, hasLength(1));
    expect(reloaded.orderedSnapshots.single.item.name, place.name);
  });

  test('corrupt and higher schema envelopes are read-only', () async {
    for (final raw in <String>[
      '{broken',
      jsonEncode(<String, Object?>{
        'schemaVersion': SavedPlaceLocalDataSource.schemaVersion,
        'snapshots': <Object?>[
          <String, Object?>{
            'providerPlaceId': 'broken',
            'latitude': 200,
            'longitude': 127,
            'savedAt': DateTime.utc(2026).toIso8601String(),
          },
        ],
        'unresolvedLegacyIds': <String>[],
        'removedLegacyIds': <String>[],
      }),
      jsonEncode(<String, Object?>{
        'schemaVersion': SavedPlaceLocalDataSource.schemaVersion,
        'snapshots': <Object?>[],
        'unresolvedLegacyIds': <Object?>['legacy-1', 3],
        'removedLegacyIds': <String>[],
      }),
      jsonEncode(<String, Object?>{
        'schemaVersion': SavedPlaceLocalDataSource.schemaVersion + 1,
        'snapshots': <Object?>[],
      }),
    ]) {
      final prefs = await preferences(
        values: <String, Object>{
          SavedPlaceLocalDataSource.legacyKey: legacyIds,
          SavedPlaceLocalDataSource.envelopeKey: raw,
        },
      );
      final source = SavedPlaceLocalDataSource(preferences: prefs);
      final catalog = source.load();

      expect(catalog.canWrite, isFalse);
      await expectLater(
        source.save(catalog, place),
        throwsA(isA<SavedPlaceWriteException>()),
      );
      expect(prefs.getString(SavedPlaceLocalDataSource.envelopeKey), raw);
    }
  });

  test('failed write rolls back caller-visible and persisted state', () async {
    final prefs = await preferences(
      values: <String, Object>{
        SavedPlaceLocalDataSource.legacyKey: legacyIds,
      },
    );
    final source = SavedPlaceLocalDataSource(
      preferences: prefs,
      writer: (_, __) async => false,
    );
    final catalog = source.load();

    await expectLater(
      source.save(catalog, place),
      throwsA(isA<SavedPlaceWriteException>()),
    );

    expect(catalog.snapshots, isEmpty);
    expect(
      prefs.getString(SavedPlaceLocalDataSource.envelopeKey),
      isNull,
    );
    expect(
      prefs.getStringList(SavedPlaceLocalDataSource.legacyKey),
      legacyIds,
    );
  });

  test('failed promotion keeps unresolved legacy state intact', () async {
    final prefs = await preferences(
      values: <String, Object>{
        SavedPlaceLocalDataSource.legacyKey: legacyIds,
      },
    );
    final source = SavedPlaceLocalDataSource(
      preferences: prefs,
      writer: (_, __) async => false,
    );
    final catalog = source.load();

    await expectLater(
      source.promote(catalog, const <PlaceSearchItem>[place]),
      throwsA(isA<SavedPlaceWriteException>()),
    );

    expect(catalog.snapshots, isEmpty);
    expect(catalog.unresolvedLegacyIds, legacyIds.toSet());
    expect(
      prefs.getString(SavedPlaceLocalDataSource.envelopeKey),
      isNull,
    );
  });

  test('failed removal keeps snapshot and persisted envelope intact', () async {
    final prefs = await preferences();
    final writable = SavedPlaceLocalDataSource(preferences: prefs);
    await writable.save(writable.load(), place);
    final before = prefs.getString(SavedPlaceLocalDataSource.envelopeKey);

    final failing = SavedPlaceLocalDataSource(
      preferences: prefs,
      writer: (_, __) async => false,
    );
    final catalog = failing.load();

    await expectLater(
      failing.remove(catalog, place.providerPlaceId),
      throwsA(isA<SavedPlaceWriteException>()),
    );

    expect(catalog.snapshots.keys, contains(place.providerPlaceId));
    expect(
      prefs.getString(SavedPlaceLocalDataSource.envelopeKey),
      before,
    );
  });
}
