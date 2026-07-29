part of 'hospital_search_page.dart';

extension _HospitalMap on _HospitalSearchPageState {
  Widget _buildMap() {
    final mapBuilder = widget.mapBuilder;
    if (mapBuilder != null) return mapBuilder(context);

    if (_locationState == _LocationAccessState.checking) {
      return Container(
        color: AppTheme.neutral100,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final initialPosition = _initialMapPosition ??= LatLng(
      latitude: _searchOrigin.latitude,
      longitude: _searchOrigin.longitude,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        KakaoMap(
          initialPosition: initialPosition,
          onMapCreated: (controller) async {
            await _labelClickSub?.cancel();
            await _cameraMoveEndSub?.cancel();
            if (!mounted) {
              controller.dispose();
              return;
            }
            _mapController = controller;
            _mapReady = false;
            _mapInitFailed = false;
            _markerLayerAdded = false;
            _registeredPlaceMarkerOrdinalCount = 0;
            _currentMarkerIds = <String>[];
            _markerCleanupIds.clear();

            _labelClickSub = controller.onLabelClickedStream.listen((event) {
              final place = _places.cast<HospitalPlace?>().firstWhere(
                    (candidate) => candidate?.id == event.labelId,
                    orElse: () => null,
                  );
              if (place != null && mounted) {
                unawaited(_selectPlace(place));
              }
            });

            _cameraMoveEndSub =
                controller.onCameraMoveEndStream.listen((event) {
              if (!mounted || !identical(_mapController, controller)) return;
              if (!event.latitude.isFinite ||
                  !event.longitude.isFinite ||
                  event.latitude < -90 ||
                  event.latitude > 90 ||
                  event.longitude < -180 ||
                  event.longitude > 180) {
                return;
              }
              final now = DateTime.now();
              if (_isCameraMoveSuppressed(now)) return;
              _cameraLat = event.latitude;
              _cameraLng = event.longitude;
              final resolution = resolveCameraMove(
                movedBy: event.movedBy,
                latitude: event.latitude,
                longitude: event.longitude,
                now: now,
                latestMoveToken: _programmaticMoveToken,
                pending: _pendingProgrammaticMove,
              );
              if (resolution.consumePending) {
                _pendingProgrammaticMove = null;
              }
              if (resolution.disposition ==
                  CameraMoveDisposition.programmatic) {
                return;
              }
              setState(() {
                _isFollowingLocation = false;
                _showReSearchButton =
                    !_categories[_selectedCategory].isFavoriteTab &&
                        shouldShowResearch(
                          searchLatitude: _searchOrigin.latitude,
                          searchLongitude: _searchOrigin.longitude,
                          cameraLatitude: event.latitude,
                          cameraLongitude: event.longitude,
                          radiusM: _radii[_selectedRadiusIndex],
                        );
              });
            });

            unawaited(_initializeMap(controller));
          },
        ),
        if (_mapInitFailed)
          ColoredBox(
            color: Colors.white.withValues(alpha: 0.92),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_outlined,
                    color: AppTheme.secondaryTextColor,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '지도를 불러오지 못했어요.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final controller = _mapController;
                      if (controller != null) {
                        unawaited(_initializeMap(controller));
                      }
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _initializeMap(KakaoMapController controller) async {
    if (!mounted || !identical(_mapController, controller)) return;
    final bottomPadding = 24.h.round();
    setState(() => _mapInitFailed = false);
    try {
      await controller.ready;
      if (!_isCurrentController(controller)) return;
      if (!_markerLayerAdded) {
        await controller.addMarkerLayer(
          layerId: KakaoMapController.defaultLabelLayerId,
        );
        if (!_isCurrentController(controller)) return;
        _markerLayerAdded = true;
      }
      if (!_isCurrentController(controller)) return;
      try {
        await controller.setPoiClickable(isClickable: false);
      } catch (_) {
        dev.log('기본 POI 클릭 비활성화 실패', name: 'HospitalSearch');
      }
      if (!_isCurrentController(controller)) return;
      await _registerMarkerStyles(controller);
      if (!_isCurrentController(controller)) return;
      _suppressCameraMoveForViewportMutation();
      await controller.setPadding(
        left: 0,
        top: 0,
        right: 0,
        bottom: bottomPadding,
      );
      _suppressCameraMoveForViewportMutation();
      if (!_isCurrentController(controller)) return;
      setState(() {
        _mapReady = true;
        _mapInitFailed = false;
      });
      final moved = await _moveCameraProgrammatically(
        target: LatLng(
          latitude: _searchOrigin.latitude,
          longitude: _searchOrigin.longitude,
        ),
        zoomLevel: _radiusZoomLevels[_selectedRadiusIndex],
      );
      if (!moved) throw StateError('initial camera move failed');
      if (!_isCurrentController(controller)) return;
      await _enqueueVisibleMarkerApply(_searchGeneration.current);
    } catch (_) {
      if (!_isCurrentController(controller)) return;
      setState(() {
        _mapReady = false;
        _mapInitFailed = true;
      });
    }
  }

  bool _isCurrentController(KakaoMapController controller) {
    return mounted && identical(_mapController, controller);
  }

  Future<void> _registerMarkerStyles(KakaoMapController controller) async {
    final myLocBytes =
        (await rootBundle.load('assets/icons/map/my_location_dot.png'))
            .buffer
            .asUint8List();
    if (!_isCurrentController(controller)) return;

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
      ],
    );
  }

  Future<void> _ensurePlaceMarkerStyles(
    KakaoMapController controller, {
    required int count,
  }) async {
    if (count <= _registeredPlaceMarkerOrdinalCount) return;

    final firstOrdinal = _registeredPlaceMarkerOrdinalCount + 1;
    final placeStyles = <MarkerStyle>[];
    for (var ordinal = firstOrdinal; ordinal <= count; ordinal++) {
      final placeBytes =
          _defaultPlaceMarkerBytes[ordinal] ??= await _createPlaceMarkerBytes(
        ordinal: ordinal,
        selected: false,
      );
      final selectedPlaceBytes =
          _selectedPlaceMarkerBytes[ordinal] ??= await _createPlaceMarkerBytes(
        ordinal: ordinal,
        selected: true,
      );
      placeStyles
        ..add(
          MarkerStyle(
            styleId: _placeMarkerStyleId(ordinal, selected: false),
            perLevels: [
              MarkerPerLevelStyle.fromBytes(bytes: placeBytes),
            ],
          ),
        )
        ..add(
          MarkerStyle(
            styleId: _placeMarkerStyleId(ordinal, selected: true),
            perLevels: [
              MarkerPerLevelStyle.fromBytes(bytes: selectedPlaceBytes),
            ],
          ),
        );
    }
    if (!_isCurrentController(controller)) return;

    await controller.registerMarkerStyles(styles: placeStyles);
    if (_isCurrentController(controller)) {
      _registeredPlaceMarkerOrdinalCount = count;
    }
  }

  Future<Uint8List> _createPlaceMarkerBytes({
    required int ordinal,
    required bool selected,
  }) async {
    final logicalSize = selected ? 52.0 : 48.0;
    // Kakao Map renders decoded bitmap pixels directly. Multiplying by the
    // Flutter device pixel ratio makes a 48 px marker about three times larger
    // on high-density Android devices.
    final pixelSize = logicalSize.round();
    final center = pixelSize / 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    if (selected) {
      canvas.drawCircle(
        ui.Offset(center, center),
        center - 1,
        ui.Paint()
          ..color = const ui.Color(0x33203F67)
          ..style = ui.PaintingStyle.fill,
      );
    }
    canvas.drawCircle(
      ui.Offset(center, center),
      center - (selected ? 6 : 4),
      ui.Paint()
        ..color =
            selected ? const ui.Color(0xFF203F67) : const ui.Color(0xFF3C79B6)
        ..style = ui.PaintingStyle.fill,
    );
    canvas.drawCircle(
      ui.Offset(center, center),
      center - (selected ? 6 : 4),
      ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final numberPainter = TextPainter(
      text: TextSpan(
        text: '$ordinal',
        style: TextStyle(
          color: Colors.white,
          fontSize: ordinal >= 10 ? 17 : 20,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    numberPainter.paint(
      canvas,
      ui.Offset(
        center - numberPainter.width / 2,
        center - numberPainter.height / 2,
      ),
    );

    final image = await recorder.endRecording().toImage(pixelSize, pixelSize);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw StateError('장소 마커 이미지를 생성하지 못했습니다.');
    }
    return data.buffer.asUint8List();
  }

  Future<bool> _moveCameraProgrammatically({
    required LatLng target,
    required int zoomLevel,
  }) async {
    final controller = _mapController;
    if (controller == null || !_mapReady) return false;
    final token = ++_programmaticMoveToken;
    _pendingProgrammaticMove = PendingProgrammaticMove(
      token: token,
      latitude: target.latitude,
      longitude: target.longitude,
      issuedAt: DateTime.now(),
    );
    try {
      await controller.moveCamera(
        cameraUpdate: CameraUpdate(
          position: target,
          zoomLevel: zoomLevel,
          type: -1,
        ),
      );
      return true;
    } catch (_) {
      if (_pendingProgrammaticMove?.token == token) {
        _pendingProgrammaticMove = null;
      }
      return false;
    }
  }

  Future<void> _enqueueVisibleMarkerApply(int generation) {
    final applyToken = ++_markerGeneration;
    final controller = _mapController;
    final visible = List<HospitalPlace>.of(_places);
    final selectedPlace = _selectedPlace;
    _markerQueue = _markerQueue.catchError((Object _) {}).then(
      (_) async {
        await _applyVisibleMarkers(
          controller: controller,
          generation: generation,
          applyToken: applyToken,
          visible: visible,
        );
        await _syncSelectedInfoWindow(
          controller: controller,
          generation: generation,
          selectedPlace: selectedPlace,
          visible: visible,
        );
      },
    );
    return _markerQueue;
  }

  bool _canApplyMarkers({
    required KakaoMapController controller,
    required int generation,
    required int applyToken,
  }) {
    return mounted &&
        _mapReady &&
        identical(_mapController, controller) &&
        _searchGeneration.isCurrent(generation) &&
        _markerGeneration == applyToken;
  }

  Future<void> _applyVisibleMarkers({
    required KakaoMapController? controller,
    required int generation,
    required int applyToken,
    required List<HospitalPlace> visible,
  }) async {
    if (controller == null ||
        !_canApplyMarkers(
          controller: controller,
          generation: generation,
          applyToken: applyToken,
        )) {
      return;
    }

    final removing = <String>{
      ..._currentMarkerIds,
      ..._markerCleanupIds,
    }.toList(growable: false);
    if (removing.isNotEmpty) {
      try {
        await controller.removeMarkers(ids: removing);
        _currentMarkerIds = <String>[];
        _markerCleanupIds.clear();
      } catch (_) {
        for (final id in removing) {
          try {
            await controller.removeMarker(id: id);
            _currentMarkerIds.remove(id);
            _markerCleanupIds.remove(id);
          } catch (_) {}
        }
        if (_currentMarkerIds.any(removing.contains) ||
            _markerCleanupIds.any(removing.contains)) {
          return;
        }
      }
    }
    if (!_canApplyMarkers(
      controller: controller,
      generation: generation,
      applyToken: applyToken,
    )) {
      return;
    }

    try {
      await controller.removeMarker(id: _myLocationMarkerId);
    } catch (_) {}
    if (!_canApplyMarkers(
      controller: controller,
      generation: generation,
      applyToken: applyToken,
    )) {
      return;
    }

    final markerOptions = buildPlaceMarkerOptions(
      places: visible,
      selectedPlaceId: _selectedPlace?.id,
    );

    if (markerOptions.isNotEmpty) {
      try {
        await _ensurePlaceMarkerStyles(
          controller,
          count: markerOptions.length,
        );
      } catch (error) {
        debugPrint(
          '[PlaceMap] Marker style registration failed: '
          '${error.runtimeType}',
        );
        if (_canApplyMarkers(
          controller: controller,
          generation: generation,
          applyToken: applyToken,
        )) {
          await _addMyLocationMarker(controller);
        }
        return;
      }
      if (!_canApplyMarkers(
        controller: controller,
        generation: generation,
        applyToken: applyToken,
      )) {
        return;
      }
      final attemptedIds =
          markerOptions.map((option) => option.id).toList(growable: false);
      _markerCleanupIds.addAll(attemptedIds);
      try {
        await controller.addMarkers(markerOptions: markerOptions);
        if (_canApplyMarkers(
          controller: controller,
          generation: generation,
          applyToken: applyToken,
        )) {
          _currentMarkerIds = List<String>.of(attemptedIds);
          _markerCleanupIds.clear();
        }
      } catch (_) {
        _currentMarkerIds = <String>[];
        try {
          await controller.removeMarkers(ids: attemptedIds);
          _markerCleanupIds.removeAll(attemptedIds);
        } catch (_) {}
        if (_canApplyMarkers(
          controller: controller,
          generation: generation,
          applyToken: applyToken,
        )) {
          await _addMyLocationMarker(controller);
        }
        return;
      }
    }
    if (!_canApplyMarkers(
      controller: controller,
      generation: generation,
      applyToken: applyToken,
    )) {
      return;
    }
    await _addMyLocationMarker(controller);
  }

  Future<void> _syncSelectedInfoWindow({
    required KakaoMapController? controller,
    required int generation,
    required HospitalPlace? selectedPlace,
    required List<HospitalPlace> visible,
  }) async {
    if (controller == null ||
        !mounted ||
        !identical(_mapController, controller)) {
      return;
    }
    try {
      await controller.removeInfoWindow(id: _selectedPlaceInfoWindowId);
    } catch (_) {}

    final canShow = selectedPlace != null &&
        _searchGeneration.isCurrent(generation) &&
        _selectedPlace?.id == selectedPlace.id &&
        visible.any((place) => place.id == selectedPlace.id);
    if (!canShow || !mounted || !identical(_mapController, controller)) return;

    try {
      await controller.addInfoWindow(
        infoWindowOption: InfoWindowOption.text(
          id: _selectedPlaceInfoWindowId,
          latLng: selectedPlace.latLng,
          title: selectedPlace.name,
          zOrder: 900,
        ),
      );
    } catch (error) {
      dev.log(
        '장소 InfoWindow 표시 실패',
        name: 'HospitalSearch',
        error: error,
      );
    }
  }

  Future<void> _addMyLocationMarker(KakaoMapController controller) async {
    final position = _position;
    if (position == null || !_isCurrentController(controller)) return;
    try {
      await controller.addMarker(
        markerOption: MarkerOption(
          id: _myLocationMarkerId,
          latLng: LatLng(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
          styleId: _myLocationStyleId,
          text: '내 위치',
          rank: 999,
        ),
      );
    } catch (_) {}
  }

  Future<void> _highlightSelectedMarker(HospitalPlace place) async {
    if (_places.indexWhere((item) => item.id == place.id) < 0) return;
    await _enqueueVisibleMarkerApply(_searchGeneration.current);
  }

  Future<void> _restoreDefaultMarker(HospitalPlace place) async {
    if (_places.indexWhere((item) => item.id == place.id) < 0) return;
    await _enqueueVisibleMarkerApply(_searchGeneration.current);
  }
}
