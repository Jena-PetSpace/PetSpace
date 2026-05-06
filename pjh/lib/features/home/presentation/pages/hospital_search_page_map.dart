part of 'hospital_search_page.dart';

extension _HospitalMap on _HospitalSearchPageState {
  Widget _buildMap() {
    if (_position == null && _locationError == null) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final initialPos = _position != null
        ? LatLng(latitude: _position!.latitude, longitude: _position!.longitude)
        : const LatLng(latitude: _defaultLat, longitude: _defaultLng);

    return KakaoMap(
      initialPosition: initialPos,
      onMapCreated: (controller) {
        _mapController = controller;

        _labelClickSub = controller.onLabelClickedStream.listen((event) {
          final place = _places.firstWhere(
            (p) => p.id == event.labelId,
            orElse: () => const HospitalPlace(
              id: '', name: '', address: '', phone: '', lat: 0, lng: 0, category: '',
            ),
          );
          if (place.id.isNotEmpty && mounted) _selectPlace(place);
        });

        _cameraMoveEndSub = controller.onCameraMoveEndStream.listen((event) {
          if (!mounted) return;
          if (_suppressCameraMoveEvent) {
            _suppressCameraMoveEvent = false;
            return;
          }
          setState(() {
            _isFollowingLocation = false;
            _showReSearchButton = true;
          });
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _onMapReady(controller);
        });
      },
    );
  }

  Future<void> _onMapReady(KakaoMapController controller) async {
    if (!mounted) return;
    dev.log('[HS] _onMapReady 시작', name: 'HospitalSearch');

    try {
      await controller.addMarkerLayer(
        layerId: KakaoMapController.defaultLabelLayerId,
      );
      dev.log('[HS] addMarkerLayer 완료', name: 'HospitalSearch');

      await controller.setPoiClickable(isClickable: false);

      await _registerMarkerStyles(controller);

      _mapReady = true;

      await _syncMapPaddingToSheet();

      if (_position != null) {
        _suppressCameraMoveEvent = true;
        await controller.moveCamera(
          cameraUpdate: CameraUpdate(
            position: LatLng(latitude: _position!.latitude, longitude: _position!.longitude),
            zoomLevel: _radiusZoomLevels[_selectedRadiusIndex],
            type: -1,
          ),
        );
        dev.log('[HS] moveCamera 완료: ${_position!.latitude}, zoom=${_radiusZoomLevels[_selectedRadiusIndex]}', name: 'HospitalSearch');
      }

      if (_places.isNotEmpty) {
        await _updateMarkers();
      } else {
        await _updateMyLocationMarker();
      }
    } catch (e, st) {
      dev.log('[HS] _onMapReady 실패: $e\n$st', name: 'HospitalSearch', error: e);
      _mapReady = true;
    }
  }

  Future<void> _registerMarkerStyles(KakaoMapController controller) async {
    try {
      final myLocBytes = (await rootBundle.load('assets/icons/map/my_location_dot.png'))
          .buffer.asUint8List();
      final placeBytes = (await rootBundle.load('assets/icons/map/place_marker.png'))
          .buffer.asUint8List();

      await controller.registerMarkerStyles(
        styles: [
          MarkerStyle(
            styleId: _myLocationStyleId,
            perLevels: [
              MarkerPerLevelStyle.fromBytes(
                bytes: myLocBytes,
                textStyle: const MarkerTextStyle(
                  fontSize: 16,
                  fontColorArgb: 0xFF3478F6,
                  strokeThickness: 2,
                  strokeColorArgb: 0xFFFFFFFF,
                ),
              ),
            ],
          ),
          MarkerStyle(
            styleId: _placeStyleId,
            perLevels: [
              MarkerPerLevelStyle.fromBytes(
                bytes: placeBytes,
                textStyle: const MarkerTextStyle(
                  fontSize: 28,
                  fontColorArgb: 0xFFFFFFFF,
                  strokeThickness: 3,
                  strokeColorArgb: 0xFF1E3A5F,
                ),
              ),
            ],
          ),
          MarkerStyle(
            styleId: _selectedPlaceStyleId,
            perLevels: [
              MarkerPerLevelStyle.fromBytes(
                bytes: placeBytes,
                textStyle: const MarkerTextStyle(
                  fontSize: 34,
                  fontColorArgb: 0xFFFFFFFF,
                  strokeThickness: 4,
                  strokeColorArgb: 0xFFFF4C2C,
                ),
              ),
            ],
          ),
        ],
      );
      dev.log('[HS] registerMarkerStyles 완료', name: 'HospitalSearch');
    } catch (e, st) {
      dev.log('[HS] registerMarkerStyles 실패: $e\n$st', name: 'HospitalSearch', error: e);
    }
  }

  Future<void> _updateMarkers() async {
    if (_mapController == null || !_mapReady) return;

    if (_currentMarkerIds.isNotEmpty) {
      try {
        await _mapController!.removeMarkers(ids: _currentMarkerIds);
      } catch (e) {
        dev.log('[HS] removeMarkers 실패: $e', name: 'HospitalSearch');
      }
    }
    try {
      await _mapController!.removeMarker(id: _myLocationMarkerId);
    } catch (e) {
      dev.log('[HS] removeMarker(my_location) 실패: $e', name: 'HospitalSearch');
    }

    final newIds = _places.map((p) => p.id).toList();
    final markerOptions = _places.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final p = entry.value;
      return MarkerOption(
        id: p.id,
        latLng: LatLng(latitude: p.lat, longitude: p.lng),
        styleId: _placeStyleId,
        text: '$index',
        rank: 100,
      );
    }).toList();

    if (markerOptions.isNotEmpty) {
      try {
        await _mapController!.addMarkers(markerOptions: markerOptions);
        _currentMarkerIds = newIds;
      } catch (e) {
        dev.log('[HS] addMarkers 실패: $e', name: 'HospitalSearch');
        _currentMarkerIds = [];
      }
    } else {
      _currentMarkerIds = [];
    }

    await _updateMyLocationMarker();
  }

  Future<void> _updateMyLocationMarker() async {
    if (_mapController == null || !_mapReady || _position == null) return;
    try {
      await _mapController!.removeMarker(id: _myLocationMarkerId);
    } catch (e) {
      dev.log('[HS] removeMarker(my_location) 실패: $e', name: 'HospitalSearch');
    }
    try {
      await _mapController!.addMarker(
        markerOption: MarkerOption(
          id: _myLocationMarkerId,
          latLng: LatLng(latitude: _position!.latitude, longitude: _position!.longitude),
          styleId: _myLocationStyleId,
          text: '내 위치',
          rank: 999,
        ),
      );
    } catch (e) {
      dev.log('[HS] 내 위치 마커 추가 실패: $e', name: 'HospitalSearch');
    }
  }

  Future<void> _highlightSelectedMarker(HospitalPlace place) async {
    if (_mapController == null) return;
    final index = _places.indexOf(place) + 1;
    try {
      await _mapController!.removeMarker(id: place.id);
    } catch (e) {
      dev.log('[HS] 선택 마커 제거 건너뜀: $e', name: 'HospitalSearch');
    }
    try {
      await _mapController!.addMarker(
        markerOption: MarkerOption(
          id: place.id,
          latLng: LatLng(latitude: place.lat, longitude: place.lng),
          styleId: _selectedPlaceStyleId,
          text: '$index',
          rank: 800,
        ),
      );
    } catch (e) {
      dev.log('[HS] 선택 마커 강조 실패: $e', name: 'HospitalSearch');
    }
  }

  Future<void> _restoreDefaultMarker(HospitalPlace place) async {
    if (_mapController == null) return;
    final index = _places.indexOf(place) + 1;
    try { await _mapController!.removeMarker(id: place.id); } catch (_) {}
    try {
      await _mapController!.addMarker(
        markerOption: MarkerOption(
          id: place.id,
          latLng: LatLng(latitude: place.lat, longitude: place.lng),
          styleId: _placeStyleId,
          text: '$index',
          rank: 100,
        ),
      );
    } catch (e) {
      dev.log('[HS] 기본 마커 복원 실패: $e', name: 'HospitalSearch');
    }
  }
}
