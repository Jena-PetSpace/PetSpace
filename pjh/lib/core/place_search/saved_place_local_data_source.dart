import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'place_search_query.dart';

enum SavedPlaceStorageState { writable, corrupt, unsupportedVersion }

class SavedPlaceWriteException implements Exception {
  const SavedPlaceWriteException();

  @override
  String toString() => 'SavedPlaceWriteException';
}

class SavedPlaceSnapshot {
  const SavedPlaceSnapshot({
    required this.item,
    required this.savedAt,
  });

  final PlaceSearchItem item;
  final DateTime savedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'provider': item.provider,
        'providerPlaceId': item.providerPlaceId,
        'name': item.name,
        'category': item.category,
        'address': item.address,
        'phone': item.phone,
        'latitude': item.latitude,
        'longitude': item.longitude,
        'placeUrl': item.placeUrl,
        'savedAt': savedAt.toUtc().toIso8601String(),
      };

  static SavedPlaceSnapshot? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<String, dynamic>();
    final id = json['providerPlaceId'] as String? ?? '';
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final savedAt = DateTime.tryParse(json['savedAt'] as String? ?? '');
    if (id.isEmpty ||
        latitude is! num ||
        longitude is! num ||
        savedAt == null ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return SavedPlaceSnapshot(
      item: PlaceSearchItem(
        provider: json['provider'] as String? ?? 'kakao',
        providerPlaceId: id,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
        placeUrl: json['placeUrl'] as String? ?? '',
      ),
      savedAt: savedAt.toUtc(),
    );
  }
}

class SavedPlaceCatalog {
  SavedPlaceCatalog({
    required this.snapshots,
    required this.unresolvedLegacyIds,
    required this.removedLegacyIds,
    required this.legacyIds,
    required this.storageState,
  });

  final Map<String, SavedPlaceSnapshot> snapshots;
  final Set<String> unresolvedLegacyIds;
  final Set<String> removedLegacyIds;
  final Set<String> legacyIds;
  final SavedPlaceStorageState storageState;

  bool get canWrite => storageState == SavedPlaceStorageState.writable;

  Set<String> get favoriteIds => <String>{
        ...snapshots.keys,
        ...unresolvedLegacyIds,
      }..removeAll(removedLegacyIds);

  List<SavedPlaceSnapshot> get orderedSnapshots {
    final values = snapshots.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return values;
  }
}

typedef SavedPlaceWriter = Future<bool> Function(String key, String value);

class SavedPlaceLocalDataSource {
  SavedPlaceLocalDataSource({
    required SharedPreferences preferences,
    SavedPlaceWriter? writer,
  })  : _preferences = preferences,
        _writer = writer ?? preferences.setString;

  static const int schemaVersion = 1;
  static const String legacyKey = 'hospital_search_favorites';
  static const String envelopeKey = 'hospital_search_saved_places_v2';

  final SharedPreferences _preferences;
  final SavedPlaceWriter _writer;

  SavedPlaceCatalog load() {
    final legacyIds =
        (_preferences.getStringList(legacyKey) ?? const <String>[]).toSet();
    final raw = _preferences.getString(envelopeKey);
    if (raw == null) {
      return SavedPlaceCatalog(
        snapshots: <String, SavedPlaceSnapshot>{},
        unresolvedLegacyIds: Set<String>.from(legacyIds),
        removedLegacyIds: <String>{},
        legacyIds: legacyIds,
        storageState: SavedPlaceStorageState.writable,
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _readOnlyLegacy(legacyIds, SavedPlaceStorageState.corrupt);
      }
      final version = decoded['schemaVersion'];
      if (version is! int) {
        return _readOnlyLegacy(legacyIds, SavedPlaceStorageState.corrupt);
      }
      if (version > schemaVersion) {
        return _readOnlyLegacy(
          legacyIds,
          SavedPlaceStorageState.unsupportedVersion,
        );
      }
      if (version != schemaVersion) {
        return _readOnlyLegacy(legacyIds, SavedPlaceStorageState.corrupt);
      }

      final snapshots = <String, SavedPlaceSnapshot>{};
      final rawSnapshots = decoded['snapshots'];
      if (rawSnapshots is! List) {
        return _readOnlyLegacy(legacyIds, SavedPlaceStorageState.corrupt);
      }
      for (final value in rawSnapshots) {
        final snapshot = SavedPlaceSnapshot.fromJson(value);
        if (snapshot == null) {
          return _readOnlyLegacy(legacyIds, SavedPlaceStorageState.corrupt);
        }
        snapshots[snapshot.item.providerPlaceId] = snapshot;
      }
      final unresolved = _tryStringSet(decoded['unresolvedLegacyIds']);
      final removed = _tryStringSet(decoded['removedLegacyIds']);
      if (unresolved == null || removed == null) {
        return _readOnlyLegacy(legacyIds, SavedPlaceStorageState.corrupt);
      }
      unresolved.addAll(
        legacyIds.where((id) => !snapshots.containsKey(id)),
      );
      unresolved.removeAll(snapshots.keys);
      unresolved.removeAll(removed);

      return SavedPlaceCatalog(
        snapshots: snapshots,
        unresolvedLegacyIds: unresolved,
        removedLegacyIds: removed,
        legacyIds: legacyIds,
        storageState: SavedPlaceStorageState.writable,
      );
    } catch (_) {
      return _readOnlyLegacy(legacyIds, SavedPlaceStorageState.corrupt);
    }
  }

  Future<SavedPlaceCatalog> promote(
    SavedPlaceCatalog catalog,
    Iterable<PlaceSearchItem> visibleItems, {
    DateTime? now,
  }) async {
    _ensureWritable(catalog);
    final snapshots = Map<String, SavedPlaceSnapshot>.from(catalog.snapshots);
    final unresolved = Set<String>.from(catalog.unresolvedLegacyIds);
    final promotedAt = (now ?? DateTime.now()).toUtc();
    for (final item in visibleItems) {
      if (unresolved.remove(item.providerPlaceId)) {
        snapshots[item.providerPlaceId] =
            SavedPlaceSnapshot(item: item, savedAt: promotedAt);
      }
    }
    final next = _copy(
      catalog,
      snapshots: snapshots,
      unresolvedLegacyIds: unresolved,
    );
    if (_sameContent(catalog, next)) return catalog;
    await _persist(next);
    return next;
  }

  Future<SavedPlaceCatalog> save(
    SavedPlaceCatalog catalog,
    PlaceSearchItem item, {
    DateTime? now,
  }) async {
    _ensureWritable(catalog);
    final snapshots = Map<String, SavedPlaceSnapshot>.from(catalog.snapshots)
      ..[item.providerPlaceId] = SavedPlaceSnapshot(
        item: item,
        savedAt: (now ?? DateTime.now()).toUtc(),
      );
    final unresolved = Set<String>.from(catalog.unresolvedLegacyIds)
      ..remove(item.providerPlaceId);
    final removed = Set<String>.from(catalog.removedLegacyIds)
      ..remove(item.providerPlaceId);
    final next = _copy(
      catalog,
      snapshots: snapshots,
      unresolvedLegacyIds: unresolved,
      removedLegacyIds: removed,
    );
    await _persist(next);
    return next;
  }

  Future<SavedPlaceCatalog> remove(
    SavedPlaceCatalog catalog,
    String providerPlaceId,
  ) async {
    _ensureWritable(catalog);
    final snapshots = Map<String, SavedPlaceSnapshot>.from(catalog.snapshots)
      ..remove(providerPlaceId);
    final unresolved = Set<String>.from(catalog.unresolvedLegacyIds)
      ..remove(providerPlaceId);
    final removed = Set<String>.from(catalog.removedLegacyIds);
    if (catalog.legacyIds.contains(providerPlaceId)) {
      removed.add(providerPlaceId);
    }
    final next = _copy(
      catalog,
      snapshots: snapshots,
      unresolvedLegacyIds: unresolved,
      removedLegacyIds: removed,
    );
    await _persist(next);
    return next;
  }

  SavedPlaceCatalog _readOnlyLegacy(
    Set<String> legacyIds,
    SavedPlaceStorageState state,
  ) {
    return SavedPlaceCatalog(
      snapshots: <String, SavedPlaceSnapshot>{},
      unresolvedLegacyIds: Set<String>.from(legacyIds),
      removedLegacyIds: <String>{},
      legacyIds: legacyIds,
      storageState: state,
    );
  }

  SavedPlaceCatalog _copy(
    SavedPlaceCatalog source, {
    Map<String, SavedPlaceSnapshot>? snapshots,
    Set<String>? unresolvedLegacyIds,
    Set<String>? removedLegacyIds,
  }) {
    return SavedPlaceCatalog(
      snapshots:
          snapshots ?? Map<String, SavedPlaceSnapshot>.from(source.snapshots),
      unresolvedLegacyIds:
          unresolvedLegacyIds ?? Set<String>.from(source.unresolvedLegacyIds),
      removedLegacyIds:
          removedLegacyIds ?? Set<String>.from(source.removedLegacyIds),
      legacyIds: Set<String>.from(source.legacyIds),
      storageState: source.storageState,
    );
  }

  Future<void> _persist(SavedPlaceCatalog catalog) async {
    final payload = jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'snapshots': catalog.orderedSnapshots
          .map((snapshot) => snapshot.toJson())
          .toList(),
      'unresolvedLegacyIds': catalog.unresolvedLegacyIds.toList()..sort(),
      'removedLegacyIds': catalog.removedLegacyIds.toList()..sort(),
    });
    try {
      final saved = await _writer(envelopeKey, payload);
      if (!saved) throw const SavedPlaceWriteException();
    } catch (_) {
      throw const SavedPlaceWriteException();
    }
  }

  void _ensureWritable(SavedPlaceCatalog catalog) {
    if (!catalog.canWrite) throw const SavedPlaceWriteException();
  }

  static Set<String>? _tryStringSet(Object? value) {
    if (value is! List || value.any((entry) => entry is! String)) return null;
    return value.cast<String>().toSet();
  }

  static bool _sameContent(
    SavedPlaceCatalog first,
    SavedPlaceCatalog second,
  ) {
    return _setEquals(first.unresolvedLegacyIds, second.unresolvedLegacyIds) &&
        _setEquals(first.removedLegacyIds, second.removedLegacyIds) &&
        _setEquals(first.snapshots.keys.toSet(), second.snapshots.keys.toSet());
  }

  static bool _setEquals(Set<String> first, Set<String> second) {
    return first.length == second.length && first.containsAll(second);
  }
}
