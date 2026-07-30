part of 'hospital_search_page.dart';

extension _HospitalSearch on _HospitalSearchPageState {
  Future<void> _loadFavorites() async {
    final catalog = _savedPlaceStore.load();
    if (!mounted) return;
    setState(() {
      _savedCatalog = catalog;
      _savedPlaceView = _savedPlacesForOrigin(catalog);
    });
    if (_mapReady && _categories[_selectedCategory].isFavoriteTab) {
      await _enqueueVisibleMarkerApply(_searchGeneration.current);
    }
  }

  List<HospitalPlace> _savedPlacesForOrigin(SavedPlaceCatalog catalog) {
    return catalog.orderedSnapshots.map((snapshot) {
      final item = snapshot.item;
      final withDistance = _searchOrigin.type == PlaceSearchOriginType.fallback
          ? item.copyWith(clearDistance: true)
          : item.copyWith(
              distanceM: distanceMeters(
                _searchOrigin.latitude,
                _searchOrigin.longitude,
                item.latitude,
                item.longitude,
              ).round(),
            );
      return HospitalPlace.fromSearchItem(withDistance);
    }).toList(growable: false);
  }

  void _refreshSavedPlaceView(SavedPlaceCatalog catalog) {
    _savedCatalog = catalog;
    _savedPlaceView = _savedPlacesForOrigin(catalog);
  }

  Future<void> _initializeLocationWithoutPrompt({
    bool refreshSearch = true,
  }) async {
    if (!mounted) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _resolveFallbackIfNeeded(
          _LocationAccessState.serviceDisabled,
          refreshSearch: refreshSearch,
        );
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _resolveFallbackIfNeeded(
          _LocationAccessState.denied,
          refreshSearch: refreshSearch,
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _resolveFallbackIfNeeded(
          _LocationAccessState.deniedForever,
          refreshSearch: refreshSearch,
        );
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _resolveFallbackIfNeeded(
          _LocationAccessState.unavailable,
          refreshSearch: refreshSearch,
        );
        return;
      }
      if (!refreshSearch &&
          _locationState == _LocationAccessState.ready &&
          _position != null) {
        return;
      }
      await _readLocation(forceCurrent: false);
    } catch (_) {
      dev.log('위치 상태 확인 실패', name: 'HospitalSearch');
      _resolveFallbackIfNeeded(
        _LocationAccessState.unavailable,
        refreshSearch: refreshSearch,
      );
    }
  }

  void _resolveFallbackIfNeeded(
    _LocationAccessState state, {
    required bool refreshSearch,
  }) {
    if (!refreshSearch && _locationState == state) return;
    _resolveFallback(state);
  }

  Future<void> _handleLocationAction() async {
    switch (_locationState) {
      case _LocationAccessState.serviceDisabled:
        await Geolocator.openLocationSettings();
        return;
      case _LocationAccessState.deniedForever:
        await Geolocator.openAppSettings();
        return;
      case _LocationAccessState.checking:
        return;
      case _LocationAccessState.ready:
      case _LocationAccessState.denied:
      case _LocationAccessState.unavailable:
        await _requestLocationAndRefresh();
        return;
    }
  }

  Future<void> _requestLocationAndRefresh() async {
    if (!mounted) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _resolveFallback(_LocationAccessState.serviceDisabled);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _resolveFallback(_LocationAccessState.denied);
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _resolveFallback(_LocationAccessState.deniedForever);
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _resolveFallback(_LocationAccessState.unavailable);
        return;
      }
      await _readLocation(forceCurrent: true);
    } catch (_) {
      dev.log('위치 요청 실패', name: 'HospitalSearch');
      if (_position != null && mounted) {
        setState(() => _locationState = _LocationAccessState.ready);
        _showSnack('현재 위치를 새로 불러오지 못해 이전 위치를 유지합니다.');
        return;
      }
      _resolveFallback(_LocationAccessState.unavailable);
    }
  }

  Future<void> _readLocation({
    required bool forceCurrent,
  }) async {
    final Position? cached =
        forceCurrent ? null : await Geolocator.getLastKnownPosition();
    final position = cached ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
    if (!mounted) return;

    final origin = PlaceSearchOrigin(
      type: PlaceSearchOriginType.device,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final isFavoriteTab = _categories[_selectedCategory].isFavoriteTab;
    setState(() {
      _position = position;
      _cameraLat = position.latitude;
      _cameraLng = position.longitude;
      _locationState = _LocationAccessState.ready;
      _isFollowingLocation = true;
      _showReSearchButton = false;
      if (isFavoriteTab) {
        _searchOrigin = origin;
        final catalog = _savedCatalog;
        if (catalog != null) _refreshSavedPlaceView(catalog);
      }
    });

    if (_mapReady) {
      await _moveCameraProgrammatically(
        target: LatLng(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        zoomLevel: _radiusZoomLevels[_selectedRadiusIndex],
      );
    }
    if (!isFavoriteTab) {
      await _searchCategory(_selectedCategory, originOverride: origin);
    } else {
      await _enqueueVisibleMarkerApply(_searchGeneration.current);
    }
  }

  void _resolveFallback(_LocationAccessState state) {
    if (!mounted) return;
    final fallback = PlaceSearchOrigin(
      type: PlaceSearchOriginType.fallback,
      latitude: _defaultLat,
      longitude: _defaultLng,
    );
    final isFavoriteTab = _categories[_selectedCategory].isFavoriteTab;
    setState(() {
      _locationState = state;
      _position = null;
      _cameraLat = _defaultLat;
      _cameraLng = _defaultLng;
      _isFollowingLocation = false;
      _showReSearchButton = false;
      if (isFavoriteTab) {
        _searchOrigin = fallback;
        final catalog = _savedCatalog;
        if (catalog != null) _refreshSavedPlaceView(catalog);
      }
    });
    if (_mapReady) {
      unawaited(
        _moveCameraProgrammatically(
          target: const LatLng(
            latitude: _defaultLat,
            longitude: _defaultLng,
          ),
          zoomLevel: _radiusZoomLevels[_selectedRadiusIndex],
        ),
      );
    }
    if (isFavoriteTab) {
      if (_mapReady) {
        unawaited(_enqueueVisibleMarkerApply(_searchGeneration.current));
      }
    } else {
      unawaited(
        _searchCategory(_selectedCategory, originOverride: fallback),
      );
    }
  }

  Future<void> _moveToMyLocation() async {
    if (_position == null) {
      await _handleLocationAction();
      return;
    }
    if (!_mapReady) return;
    final origin = PlaceSearchOrigin(
      type: PlaceSearchOriginType.device,
      latitude: _position!.latitude,
      longitude: _position!.longitude,
    );
    final isFavoriteTab = _categories[_selectedCategory].isFavoriteTab;
    setState(() {
      _isFollowingLocation = true;
      _showReSearchButton = false;
      if (isFavoriteTab) {
        _searchOrigin = origin;
        final catalog = _savedCatalog;
        if (catalog != null) _refreshSavedPlaceView(catalog);
      }
    });
    await _moveCameraProgrammatically(
      target: LatLng(
        latitude: _position!.latitude,
        longitude: _position!.longitude,
      ),
      zoomLevel: _radiusZoomLevels[_selectedRadiusIndex],
    );
    if (isFavoriteTab) {
      await _enqueueVisibleMarkerApply(_searchGeneration.current);
    } else {
      await _searchCategory(_selectedCategory, originOverride: origin);
    }
  }

  Future<void> _searchCategory(
    int index, {
    PlaceSearchOrigin? originOverride,
  }) async {
    _searchFocusNode.unfocus();
    _preserveCollapsedAfterSearch = false;
    final token = _searchGeneration.begin();
    final category = _categories[index];
    final origin = originOverride ?? _searchOrigin;
    setState(() {
      _selectedCategory = index;
      _manualResultsActive = false;
      _manualSearchKeyword = null;
      _selectedPlace = null;
      _showDetail = false;
      _showReSearchButton = false;
      _searchUiState = category.isFavoriteTab
          ? _PlaceSearchUiState.idle
          : _PlaceSearchUiState.loading;
      _searching = !category.isFavoriteTab;
      _sheetSize = _places.isEmpty ? _SheetSize.collapsed : _SheetSize.half;
    });

    if (category.isFavoriteTab) {
      await _enqueueVisibleMarkerApply(token);
      return;
    }

    unawaited(_enqueueVisibleMarkerApply(token));
    await _runSearch(
      token: token,
      origin: origin,
      category: category.label,
      primaryKeyword: category.primaryQuery,
      supplementalKeywords: category.supplementalQueries,
      categoryIndex: index,
    );
  }

  Future<void> _searchByKeyword(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    _searchFocusNode.unfocus();
    _preserveCollapsedAfterSearch = false;
    final token = _searchGeneration.begin();
    final origin = _searchOrigin.copyWith(type: PlaceSearchOriginType.manual);
    final categoryIndex = manualSearchCategoryIndex(
      currentCategoryIndex: _selectedCategory,
      currentIsFavoriteTab: _categories[_selectedCategory].isFavoriteTab,
    );
    setState(() {
      _searching = true;
      _searchUiState = _PlaceSearchUiState.loading;
      _selectedPlace = null;
      _showDetail = false;
      _showReSearchButton = false;
    });
    unawaited(_enqueueVisibleMarkerApply(token));
    await _runSearch(
      token: token,
      origin: origin,
      category: '',
      primaryKeyword: trimmed,
      supplementalKeywords: const <String>[],
      manualKeyword: trimmed,
      categoryIndex: categoryIndex,
    );
  }

  Future<void> _reSearchHere() async {
    final category = _categories[_selectedCategory];
    if (category.isFavoriteTab) return;
    _preserveCollapsedAfterSearch = false;
    final origin = PlaceSearchOrigin(
      type: PlaceSearchOriginType.mapCenter,
      latitude: _cameraLat,
      longitude: _cameraLng,
    );
    final token = _searchGeneration.begin();
    final manualKeyword = _manualSearchKeyword;
    setState(() {
      _searching = true;
      _searchUiState = _PlaceSearchUiState.loading;
      _selectedPlace = null;
      _showDetail = false;
      _showReSearchButton = false;
    });
    unawaited(_enqueueVisibleMarkerApply(token));
    await _runSearch(
      token: token,
      origin: origin,
      category: manualKeyword == null ? category.label : '',
      primaryKeyword: manualKeyword ?? category.primaryQuery,
      supplementalKeywords:
          manualKeyword == null ? category.supplementalQueries : const [],
      manualKeyword: manualKeyword,
      categoryIndex: _selectedCategory,
    );
  }

  Future<void> _runSearch({
    required int token,
    required PlaceSearchOrigin origin,
    required String category,
    required String primaryKeyword,
    required List<String> supplementalKeywords,
    required int categoryIndex,
    String? manualKeyword,
  }) async {
    try {
      const pageSize = 15;
      final items = <PlaceSearchItem>[];
      var pageNumber = 1;
      while (pageNumber <= 3) {
        final page = await _localSearch.search(
          PlaceSearchQuery(
            originType: origin.type,
            latitude: origin.latitude,
            longitude: origin.longitude,
            radiusM: _radii[_selectedRadiusIndex],
            category: category,
            keyword: primaryKeyword,
            page: pageNumber,
            size: pageSize,
          ),
        );
        if (!_searchGeneration.isCurrent(token) || !mounted) return;
        items.addAll(
          page.items.where(
            (item) => matchesPlaceCategory(item, category),
          ),
        );
        final uniqueCount = mergePlaceSearchItems(
          items,
          originLatitude: origin.latitude,
          originLongitude: origin.longitude,
        ).length;
        if (!shouldFetchNextPlacePage(
          page: pageNumber,
          pageSize: pageSize,
          isEnd: page.isEnd,
          pageableCount: page.pageableCount,
          uniqueCount: uniqueCount,
        )) {
          break;
        }
        pageNumber++;
      }

      for (final supplemental in supplementalKeywords) {
        final page = await _localSearch.search(
          PlaceSearchQuery(
            originType: origin.type,
            latitude: origin.latitude,
            longitude: origin.longitude,
            radiusM: _radii[_selectedRadiusIndex],
            category: category,
            keyword: supplemental,
            size: pageSize,
          ),
        );
        if (!_searchGeneration.isCurrent(token) || !mounted) return;
        items.addAll(
          page.items.where(
            (item) => matchesPlaceCategory(item, category),
          ),
        );
      }

      final merged = mergePlaceSearchItems(
        items,
        originLatitude: origin.latitude,
        originLongitude: origin.longitude,
      );
      if (!_searchGeneration.isCurrent(token) || !mounted) return;
      final places =
          merged.map(HospitalPlace.fromSearchItem).toList(growable: false);
      final preserveCollapsed = _preserveCollapsedAfterSearch;
      setState(() {
        _searchOrigin = origin;
        _selectedCategory = categoryIndex;
        _manualResultsActive = manualKeyword != null;
        _manualSearchKeyword = manualKeyword;
        _resultCategory = categoryIndex;
        _resultManualSearchKeyword = manualKeyword;
        _searchResults = places;
        _searching = false;
        _searchUiState = places.isEmpty
            ? _PlaceSearchUiState.empty
            : _PlaceSearchUiState.idle;
        _selectedPlace = places.any((place) => place.id == _selectedPlace?.id)
            ? _selectedPlace
            : null;
        if (_selectedPlace == null) _showDetail = false;
        if (places.isNotEmpty && !preserveCollapsed) {
          _sheetSize = _SheetSize.half;
        }
        _preserveCollapsedAfterSearch = false;
      });

      await _serializeSavedPlaceMutation(() async {
        if (!_searchGeneration.isCurrent(token) || !mounted) return;
        var displayCatalog = _savedCatalog;
        if (displayCatalog != null && displayCatalog.canWrite) {
          try {
            displayCatalog =
                await _savedPlaceStore.promote(displayCatalog, merged);
          } on SavedPlaceWriteException {
            if (_searchGeneration.isCurrent(token) && mounted) {
              _showSnack('저장한 장소 정보를 갱신하지 못했어요.');
            }
          }
        }
        if (displayCatalog != null &&
            _searchGeneration.isCurrent(token) &&
            mounted) {
          final catalog = displayCatalog;
          setState(() => _refreshSavedPlaceView(catalog));
        }
      });
      await _enqueueVisibleMarkerApply(token);
    } on KakaoLocalSearchException catch (error) {
      await _finishSearchFailure(
        token: token,
        origin: origin,
        categoryIndex: categoryIndex,
        manualKeyword: manualKeyword,
        state: _searchStateForFailure(error.kind),
      );
    } catch (error) {
      dev.log(
        'Unexpected place search failure: ${error.runtimeType}',
        name: 'HospitalSearch',
      );
      await _finishSearchFailure(
        token: token,
        origin: origin,
        categoryIndex: categoryIndex,
        manualKeyword: manualKeyword,
        state: _PlaceSearchUiState.server,
      );
    }
  }

  Future<void> _finishSearchFailure({
    required int token,
    required PlaceSearchOrigin origin,
    required int categoryIndex,
    required String? manualKeyword,
    required _PlaceSearchUiState state,
  }) async {
    if (!_searchGeneration.isCurrent(token) || !mounted) return;
    setState(() {
      _searchOrigin = origin;
      _selectedCategory = categoryIndex;
      _manualResultsActive = manualKeyword != null;
      _manualSearchKeyword = manualKeyword;
      _resultCategory = categoryIndex;
      _resultManualSearchKeyword = manualKeyword;
      _searchResults = const <HospitalPlace>[];
      _searching = false;
      _searchUiState = state;
      _selectedPlace = null;
      _showDetail = false;
      _preserveCollapsedAfterSearch = false;
      final catalog = _savedCatalog;
      if (catalog != null) _refreshSavedPlaceView(catalog);
    });
    _setSheetSizeImmediately(_SheetSize.half);
    await _enqueueVisibleMarkerApply(token);
  }

  void _retryCurrentSearch() {
    final keyword = _manualSearchKeyword;
    if (keyword != null) {
      unawaited(_searchByKeyword(keyword));
      return;
    }
    unawaited(
      _searchCategory(
        _selectedCategory,
        originOverride: _searchOrigin,
      ),
    );
  }

  _PlaceSearchUiState _searchStateForFailure(KakaoLocalFailureKind kind) {
    return switch (kind) {
      KakaoLocalFailureKind.unauthorized => _PlaceSearchUiState.unauthorized,
      KakaoLocalFailureKind.rateLimit => _PlaceSearchUiState.rateLimit,
      KakaoLocalFailureKind.timeout => _PlaceSearchUiState.timeout,
      KakaoLocalFailureKind.offline => _PlaceSearchUiState.offline,
      KakaoLocalFailureKind.server => _PlaceSearchUiState.server,
      KakaoLocalFailureKind.invalidPayload =>
        _PlaceSearchUiState.invalidPayload,
    };
  }

  String _messageForSearchState(_PlaceSearchUiState state) {
    return switch (state) {
      _PlaceSearchUiState.timeout => '검색 시간이 초과됐어요. 다시 시도해주세요.',
      _PlaceSearchUiState.offline => '네트워크 연결을 확인해주세요.',
      _PlaceSearchUiState.unauthorized => '장소 검색 설정을 확인 중이에요.',
      _PlaceSearchUiState.rateLimit => '검색 요청이 많아요. 잠시 후 다시 시도해주세요.',
      _PlaceSearchUiState.server => '장소 검색이 잠시 원활하지 않아요.',
      _PlaceSearchUiState.invalidPayload => '장소 정보를 불러오지 못했어요.',
      _ => '장소 검색에 실패했어요.',
    };
  }
}
