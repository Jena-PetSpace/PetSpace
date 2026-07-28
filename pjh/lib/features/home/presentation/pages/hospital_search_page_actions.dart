part of 'hospital_search_page.dart';

extension _HospitalActions on _HospitalSearchPageState {
  Future<void> _selectPlace(HospitalPlace place) async {
    setState(() {
      _selectedPlace = place;
      _showDetail = true;
      _sheetSize = _SheetSize.half;
    });
    await _syncMapPaddingToSheet();
    if (_mapReady) {
      await _moveCameraProgrammatically(
        target: LatLng(latitude: place.lat, longitude: place.lng),
        zoomLevel: 15,
      );
      await _highlightSelectedMarker(place);
    }
  }

  void _closeDetail() {
    final prev = _selectedPlace;
    setState(() {
      _showDetail = false;
      _selectedPlace = null;
      _sheetSize = _SheetSize.half;
    });
    _syncMapPaddingToSheet();
    if (_mapReady && prev != null) {
      _restoreDefaultMarker(prev);
    }
  }

  Future<void> _toggleFavorite(HospitalPlace place) {
    return _serializeSavedPlaceMutation(() async {
      final catalog = _savedCatalog;
      if (catalog == null) {
        _showSnack('저장한 장소 정보를 불러오지 못했어요.');
        return;
      }
      try {
        final next = _isFavorite(place.id)
            ? await _savedPlaceStore.remove(catalog, place.id)
            : await _savedPlaceStore.save(catalog, place.toSearchItem());
        if (!mounted) return;
        setState(() {
          _refreshSavedPlaceView(next);
          if (_categories[_selectedCategory].isFavoriteTab &&
              !_isFavorite(place.id)) {
            if (_selectedPlace?.id == place.id) {
              _selectedPlace = null;
              _showDetail = false;
            }
          }
        });
        if (_categories[_selectedCategory].isFavoriteTab) {
          await _enqueueVisibleMarkerApply(_searchGeneration.current);
        }
      } on SavedPlaceWriteException {
        _showSnack('저장하지 못했어요. 잠시 후 다시 시도해주세요.');
      }
    });
  }

  bool _isFavorite(String id) =>
      _savedCatalog?.favoriteIds.contains(id) ?? false;

  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openKakaoMapDetail(HospitalPlace place) async {
    final url = place.placeUrl.isNotEmpty
        ? place.placeUrl.replaceFirst(RegExp(r'^http://'), 'https://')
        : 'https://map.kakao.com/link/search/${Uri.encodeComponent(place.name)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('카카오맵을 열 수 없습니다');
    }
  }

  Future<void> _openKakaoMapDirections(HospitalPlace place) async {
    final uri = Uri.parse(
      'https://map.kakao.com/link/to/'
      '${Uri.encodeComponent(place.name)},${place.lat},${place.lng}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('길찾기를 열 수 없습니다');
    }
  }

  Future<void> _sharePlace(HospitalPlace place) async {
    final url = place.placeUrl.isNotEmpty
        ? place.placeUrl.replaceFirst(RegExp(r'^http://'), 'https://')
        : 'https://map.kakao.com/link/search/${Uri.encodeComponent(place.name)}';
    final text = '${place.name}\n${place.address}\n$url';
    await Share.share(
      text,
      subject: place.name,
      sharePositionOrigin: shareOrigin(context),
    );
  }
}
