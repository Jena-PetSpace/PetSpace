part of 'hospital_search_page.dart';

extension _HospitalSearch on _HospitalSearchPageState {
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_favoritesPrefKey) ?? [];
      if (mounted) setState(() => _favoriteIds.addAll(ids));
    } catch (e) {
      dev.log('[HS] 북마크 로드 실패: $e', name: 'HospitalSearch');
    }
  }

  Future<void> _persistFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesPrefKey, _favoriteIds.toList());
    } catch (e) {
      dev.log('[HS] 북마크 저장 실패: $e', name: 'HospitalSearch');
    }
  }

  Future<void> _getLocation() async {
    if (!mounted) return;
    setState(() => _locationError = null);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locationError = '위치 서비스를 켜주세요');
        _searchCategory(_selectedCategory);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationError = '설정에서 위치 권한을 허용해주세요');
          await Geolocator.openAppSettings();
        }
        _searchCategory(_selectedCategory);
        return;
      }

      final Position? lastKnown = await Geolocator.getLastKnownPosition();
      final Position pos = lastKnown ?? await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      setState(() {
        _position = pos;
        _cameraLat = pos.latitude;
        _cameraLng = pos.longitude;
        _isFollowingLocation = true;
        _showReSearchButton = false;
        _locationError = null;
      });

      if (_mapReady) {
        _suppressCameraMoveEvent = true;
        await _mapController!.moveCamera(
          cameraUpdate: CameraUpdate(
            position: LatLng(latitude: pos.latitude, longitude: pos.longitude),
            zoomLevel: _radiusZoomLevels[_selectedRadiusIndex],
            type: -1,
          ),
        );
      }

      _searchCategory(_selectedCategory);
    } catch (e) {
      dev.log('위치 오류: $e', name: 'HospitalSearch');
      if (mounted) setState(() => _locationError = '위치를 가져올 수 없습니다');
      _searchCategory(_selectedCategory);
    }
  }

  void _moveToMyLocation() {
    if (_position == null) { _getLocation(); return; }
    if (!_mapReady) return;
    _suppressCameraMoveEvent = true;
    setState(() {
      _isFollowingLocation = true;
      _showReSearchButton = false;
    });
    _mapController!.moveCamera(
      cameraUpdate: CameraUpdate(
        position: LatLng(latitude: _position!.latitude, longitude: _position!.longitude),
        zoomLevel: _radiusZoomLevels[_selectedRadiusIndex],
        type: -1,
      ),
    );
  }

  Future<void> _searchCategory(int index) async {
    _searchFocusNode.unfocus();
    final cat = _categories[index];
    if (cat.isFavoriteTab) {
      setState(() {
        _selectedCategory = index;
        _selectedPlace = null;
        _showDetail = false;
        _showReSearchButton = false;
        _places = _places.where((p) => _favoriteIds.contains(p.id)).toList();
        if (_places.isEmpty) {
          _sheetSize = _SheetSize.collapsed;
        } else {
          _sheetSize = _SheetSize.half;
        }
      });
      return;
    }
    setState(() {
      _selectedCategory = index;
      _searching = true;
      _selectedPlace = null;
      _showDetail = false;
      _places = [];
      _showReSearchButton = false;
    });
    await _fetchPlaces(cat.query);
  }

  Future<void> _searchByKeyword(String keyword) async {
    if (keyword.trim().isEmpty) return;
    _searchFocusNode.unfocus();
    setState(() {
      _searching = true;
      _selectedPlace = null;
      _showDetail = false;
      _places = [];
      _showReSearchButton = false;
    });
    await _fetchPlaces(keyword.trim());
  }

  Future<void> _reSearchHere() async {
    setState(() {
      _searching = true;
      _selectedPlace = null;
      _showDetail = false;
      _places = [];
      _showReSearchButton = false;
    });
    await _fetchPlacesAt(_categories[_selectedCategory].query, lat: _cameraLat, lng: _cameraLng);
  }

  Future<void> _fetchPlaces(String query) async {
    await _fetchPlacesAt(
      query,
      lat: _position?.latitude ?? _defaultLat,
      lng: _position?.longitude ?? _defaultLng,
    );
  }

  Future<void> _fetchPlacesAt(String query, {required double lat, required double lng}) async {
    try {
      final uri = Uri.parse(
        'https://dapi.kakao.com/v2/local/search/keyword.json'
        '?query=${Uri.encodeComponent(query)}'
        '&x=$lng&y=$lat'
        '&radius=${_radii[_selectedRadiusIndex]}'
        '&sort=distance&size=15',
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'KakaoAK ${ApiConfig.kakaoRestApiKey}'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final documents = (data['documents'] as List<dynamic>? ?? [])
            .map((e) => HospitalPlace.fromJson(e as Map<String, dynamic>))
            .where((p) => _isValidCategoryForSelected(p.category))
            .toList();
        setState(() {
          _places = documents;
          _searching = false;
          if (documents.isNotEmpty) _sheetSize = _SheetSize.half;
        });
        if (_mapReady) await _updateMarkers();
      } else {
        setState(() => _searching = false);
        dev.log('검색 API 실패: ${response.statusCode}', name: 'HospitalSearch');
        if (mounted) {
          final message = response.statusCode == 401 || response.statusCode == 403
              ? '카카오 지도 API 인증이 필요합니다. 관리자에게 문의해주세요.'
              : '장소 검색에 실패했습니다. 잠시 후 다시 시도해주세요.';
          _showSnack(message);
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _searching = false);
        _showSnack('검색 시간이 초과되었습니다. 네트워크를 확인해주세요.');
      }
    } catch (e) {
      dev.log('검색 오류: $e', name: 'HospitalSearch');
      if (mounted) {
        setState(() => _searching = false);
        _showSnack('검색 중 오류가 발생했습니다.');
      }
    }
  }
}
