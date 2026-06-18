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
      _suppressCameraMoveEvent = true;
      _mapController!.moveCamera(
        cameraUpdate: CameraUpdate(
          position: LatLng(latitude: place.lat, longitude: place.lng),
          zoomLevel: 15,
          type: -1,
        ),
      );
      await _highlightSelectedMarker(place);
    }
  }

  void _closeDetail() {
    final prev = _selectedPlace;
    setState(() { _showDetail = false; _sheetSize = _SheetSize.half; });
    _syncMapPaddingToSheet();
    if (_mapReady && prev != null) {
      _restoreDefaultMarker(prev);
    }
  }

  void _toggleFavorite(HospitalPlace place) {
    setState(() {
      if (_favoriteIds.contains(place.id)) {
        _favoriteIds.remove(place.id);
      } else {
        _favoriteIds.add(place.id);
      }
    });
    _persistFavorites();
  }

  bool _isFavorite(String id) => _favoriteIds.contains(id);

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
