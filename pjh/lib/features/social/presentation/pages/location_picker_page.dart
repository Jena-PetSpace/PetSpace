import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/place_search/kakao_local_data_source.dart';
import '../../../../core/place_search/place_search_query.dart';
import '../../../../shared/themes/app_theme.dart';

class LocationPickResult {
  final String name;
  final String address;
  final double lat;
  final double lng;
  const LocationPickResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class _Place {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  const _Place({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory _Place.fromSearchItem(PlaceSearchItem item) => _Place(
        id: item.providerPlaceId,
        name: item.name,
        address: item.address,
        lat: item.latitude,
        lng: item.longitude,
      );

  LatLng get latLng => LatLng(latitude: lat, longitude: lng);
}

enum _PickerLocationState {
  checking,
  ready,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

enum _PickerSearchStatus { initial, searching, results, empty, failure }

enum _PickerSearchFailure { timeout, offline, other }

class _PickerSearchState {
  final _PickerSearchStatus status;
  final _PickerSearchFailure? failure;

  const _PickerSearchState._(this.status, [this.failure]);

  static const initial = _PickerSearchState._(_PickerSearchStatus.initial);
  static const searching = _PickerSearchState._(_PickerSearchStatus.searching);
  static const results = _PickerSearchState._(_PickerSearchStatus.results);
  static const empty = _PickerSearchState._(_PickerSearchStatus.empty);

  const _PickerSearchState.failure(_PickerSearchFailure kind)
      : this._(_PickerSearchStatus.failure, kind);
}

class LocationPickerPage extends StatefulWidget {
  final KakaoLocalDataSource? localSearch;

  @visibleForTesting
  final bool skipLocationBootstrap;

  @visibleForTesting
  final bool initialMapFailed;

  @visibleForTesting
  final WidgetBuilder? mapPlaceholderBuilder;

  @visibleForTesting
  final Future<bool> Function(int retryAttempt)? mapRetryEvaluator;

  const LocationPickerPage({
    super.key,
    this.localSearch,
    this.skipLocationBootstrap = false,
    this.initialMapFailed = false,
    this.mapPlaceholderBuilder,
    this.mapRetryEvaluator,
  });

  static Future<LocationPickResult?> push(BuildContext context) {
    return Navigator.of(context).push<LocationPickResult>(
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
  }

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const double _defaultLat = 37.5665;
  static const double _defaultLng = 126.9780;
  static const String _myLocStyleId = 'my_loc';
  static const String _placeStyleId = 'place';
  static const String _selStyleId = 'sel';
  static const String _myLocMarkerId = 'my_location';

  late final KakaoLocalDataSource _localSearch;
  final PlaceSearchGeneration _searchGeneration = PlaceSearchGeneration();

  KakaoMapController? _mapCtrl;
  bool _mapReady = false;
  bool _mapInitFailed = false;
  bool _listOnlyMode = false;
  int _mapViewGeneration = 0;
  int _mapRetryCount = 0;
  bool _mapRetriesExhausted = false;
  Timer? _mapInitWatchdog;
  bool _markerLayerAdded = false;
  StreamSubscription<LabelClickEvent>? _labelSub;
  StreamSubscription<CameraMoveEndEvent>? _camSub;
  int _programmaticMoveToken = 0;
  PendingProgrammaticMove? _pendingProgrammaticMove;
  LatLng? _initialMapPosition;
  Future<void> _markerQueue = Future<void>.value();
  int _markerGeneration = 0;

  Position? _position;
  bool _locLoading = true;
  _PickerLocationState _locationState = _PickerLocationState.checking;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _listScrollController = ScrollController();
  Timer? _debounce;

  List<_Place> _places = [];
  _PickerSearchState _searchState = _PickerSearchState.initial;
  _Place? _selected;
  List<String> _markerIds = [];
  final Set<String> _markerCleanupIds = <String>{};

  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _localSearch = widget.localSearch ?? sl<KakaoLocalDataSource>();
    if (widget.skipLocationBootstrap) {
      _locLoading = false;
      _locationState = _PickerLocationState.denied;
    } else {
      _initializeLocationWithoutPrompt();
    }
    if (widget.initialMapFailed) {
      _mapInitFailed = true;
      _listOnlyMode = true;
    }
  }

  @override
  void dispose() {
    _labelSub?.cancel();
    _camSub?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _listScrollController.dispose();
    _debounce?.cancel();
    _mapInitWatchdog?.cancel();
    _sheetCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── 위치 ──────────────────────────────────────────────────────────────────────

  Future<void> _initializeLocationWithoutPrompt() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _locationState = _PickerLocationState.serviceDisabled;
            _locLoading = false;
          });
        }
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationState = _PickerLocationState.denied;
            _locLoading = false;
          });
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationState = _PickerLocationState.deniedForever;
            _locLoading = false;
          });
        }
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        if (mounted) {
          setState(() {
            _locationState = _PickerLocationState.unavailable;
            _locLoading = false;
          });
        }
        return;
      }
      await _readLocation(forceCurrent: false);
    } catch (_) {
      dev.log('현재 위치 확인 실패', name: 'LocationPicker');
      if (mounted) {
        setState(() {
          _locationState = _PickerLocationState.unavailable;
          _locLoading = false;
        });
      }
    }
  }

  Future<void> _requestLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _locationState = _PickerLocationState.serviceDisabled;
            _locLoading = false;
          });
          _showLocationSettingsPrompt(appSettings: false);
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _locationState = _PickerLocationState.denied);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('현재 위치 권한이 허용되지 않았어요.')),
          );
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationState = _PickerLocationState.deniedForever);
          _showLocationSettingsPrompt(appSettings: true);
        }
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        if (mounted) {
          setState(() => _locationState = _PickerLocationState.unavailable);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('현재 위치를 사용할 수 없어요. 잠시 후 다시 시도해 주세요.')),
          );
        }
        return;
      }
      await _readLocation(forceCurrent: true);
    } catch (_) {
      dev.log('현재 위치 요청 실패', name: 'LocationPicker');
      if (mounted) {
        setState(() => _locationState = _PickerLocationState.unavailable);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치를 불러오지 못했어요.')),
        );
      }
    }
  }

  void _showLocationSettingsPrompt({required bool appSettings}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          appSettings ? '설정에서 위치 권한을 허용해주세요.' : '현재 위치를 사용하려면 위치 서비스를 켜주세요.',
        ),
        action: SnackBarAction(
          label: '설정 열기',
          onPressed: () {
            unawaited(
              appSettings
                  ? Geolocator.openAppSettings()
                  : Geolocator.openLocationSettings(),
            );
          },
        ),
      ),
    );
  }

  Future<void> _readLocation({required bool forceCurrent}) async {
    try {
      final cached =
          forceCurrent ? null : await Geolocator.getLastKnownPosition();
      final position = cached ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 8),
            ),
          );
      if (!mounted) return;
      setState(() {
        _position = position;
        _locationState = _PickerLocationState.ready;
        _locLoading = false;
      });
      if (_mapReady) {
        await _moveCameraProgrammatically(
          target: LatLng(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
          zoomLevel: 15,
        );
        await _enqueueMarkerApply(_searchGeneration.current);
      }
    } catch (_) {
      dev.log('현재 위치 확인 실패', name: 'LocationPicker');
      if (mounted) {
        setState(() {
          _locationState = _PickerLocationState.unavailable;
          _locLoading = false;
        });
        if (forceCurrent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('현재 위치를 불러오지 못했어요.')),
          );
        }
      }
    }
  }

  // ── 지도 초기화 ────────────────────────────────────────────────────────────────

  Future<void> _onMapReady(KakaoMapController ctrl) async {
    if (!mounted || !identical(_mapCtrl, ctrl)) return;
    _mapInitWatchdog?.cancel();
    _mapInitWatchdog = null;
    setState(() => _mapInitFailed = false);
    try {
      await ctrl.ready.timeout(const Duration(seconds: 12));
      if (!mounted || !identical(_mapCtrl, ctrl)) return;
      if (!_markerLayerAdded) {
        await ctrl.addMarkerLayer(
          layerId: KakaoMapController.defaultLabelLayerId,
        );
        if (!mounted || !identical(_mapCtrl, ctrl)) return;
        _markerLayerAdded = true;
      }
      if (!mounted || !identical(_mapCtrl, ctrl)) return;
      try {
        await ctrl.setPoiClickable(isClickable: false);
      } catch (_) {
        dev.log('기본 POI 클릭 비활성화 실패', name: 'LocationPicker');
      }
      if (!mounted || !identical(_mapCtrl, ctrl)) return;
      await _registerStyles(ctrl);
      if (!mounted || !identical(_mapCtrl, ctrl)) return;
      setState(() {
        _mapReady = true;
        _mapInitFailed = false;
        _listOnlyMode = false;
        _mapRetriesExhausted = false;
      });
      if (_position != null) {
        final moved = await _moveCameraProgrammatically(
          target: LatLng(
            latitude: _position!.latitude,
            longitude: _position!.longitude,
          ),
          zoomLevel: 15,
        );
        if (!moved) throw StateError('initial camera move failed');
      }
      if (!mounted || !identical(_mapCtrl, ctrl)) return;
      await _enqueueMarkerApply(_searchGeneration.current);
    } catch (_) {
      dev.log('지도 초기화 실패', name: 'LocationPicker');
      if (!mounted || !identical(_mapCtrl, ctrl)) return;
      setState(() {
        _mapReady = false;
        _mapInitFailed = true;
        _listOnlyMode = true;
        _mapRetriesExhausted = _mapRetryCount >= 2;
      });
    }
  }

  Future<void> _registerStyles(KakaoMapController ctrl) async {
    final myBytes =
        (await rootBundle.load('assets/icons/map/my_location_dot.png'))
            .buffer
            .asUint8List();
    if (!mounted || !identical(_mapCtrl, ctrl)) return;
    final placeBytes =
        (await rootBundle.load('assets/icons/map/place_marker.png'))
            .buffer
            .asUint8List();
    if (!mounted || !identical(_mapCtrl, ctrl)) return;
    await ctrl.registerMarkerStyles(styles: [
      MarkerStyle(
        styleId: _myLocStyleId,
        perLevels: [
          MarkerPerLevelStyle.fromBytes(
            bytes: myBytes,
            textStyle: const MarkerTextStyle(
              fontSize: 16,
              fontColorArgb: 0xFF3478F6,
              strokeThickness: 2,
              strokeColorArgb: 0xFFFFFFFF,
            ),
          )
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
          )
        ],
      ),
      MarkerStyle(
        styleId: _selStyleId,
        perLevels: [
          MarkerPerLevelStyle.fromBytes(
            bytes: placeBytes,
            textStyle: const MarkerTextStyle(
              fontSize: 34,
              fontColorArgb: 0xFFFFFFFF,
              strokeThickness: 4,
              strokeColorArgb: 0xFF1E3A5F,
            ),
          )
        ],
      ),
    ]);
  }

  Future<bool> _moveCameraProgrammatically({
    required LatLng target,
    required int zoomLevel,
  }) async {
    final controller = _mapCtrl;
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

  // ── 마커 ──────────────────────────────────────────────────────────────────────

  Future<void> _enqueueMarkerApply(int generation) {
    final applyToken = ++_markerGeneration;
    final controller = _mapCtrl;
    final visible = List<_Place>.of(_places);
    final selectedId = _selected?.id;
    _markerQueue = _markerQueue.catchError((Object _) {}).then(
          (_) => _applyMarkers(
            controller: controller,
            generation: generation,
            applyToken: applyToken,
            visible: visible,
            selectedId: selectedId,
          ),
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
        identical(_mapCtrl, controller) &&
        _searchGeneration.isCurrent(generation) &&
        _markerGeneration == applyToken;
  }

  Future<void> _applyMarkers({
    required KakaoMapController? controller,
    required int generation,
    required int applyToken,
    required List<_Place> visible,
    required String? selectedId,
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
      ..._markerIds,
      ..._markerCleanupIds,
    }.toList(growable: false);
    if (removing.isNotEmpty) {
      try {
        await controller.removeMarkers(ids: removing);
        _markerIds = <String>[];
        _markerCleanupIds.clear();
      } catch (_) {
        for (final id in removing) {
          try {
            await controller.removeMarker(id: id);
            _markerIds.remove(id);
            _markerCleanupIds.remove(id);
          } catch (_) {}
        }
        if (_markerIds.any(removing.contains) ||
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
      await controller.removeMarker(id: _myLocMarkerId);
    } catch (_) {}
    if (!_canApplyMarkers(
      controller: controller,
      generation: generation,
      applyToken: applyToken,
    )) {
      return;
    }

    final markerOptions = visible.asMap().entries.map((entry) {
      final place = entry.value;
      return MarkerOption(
        id: place.id,
        latLng: place.latLng,
        styleId: selectedId == place.id ? _selStyleId : _placeStyleId,
        text: '${entry.key + 1}',
        rank: selectedId == place.id ? 800 : 100,
      );
    }).toList(growable: false);

    if (markerOptions.isNotEmpty) {
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
          _markerIds = List<String>.of(attemptedIds);
          _markerCleanupIds.clear();
        }
      } catch (_) {
        _markerIds = <String>[];
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

  Future<void> _addMyLocationMarker(KakaoMapController controller) async {
    final position = _position;
    if (position == null ||
        !mounted ||
        !_mapReady ||
        !identical(_mapCtrl, controller)) {
      return;
    }
    try {
      await controller.addMarker(
        markerOption: MarkerOption(
          id: _myLocMarkerId,
          latLng: LatLng(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
          styleId: _myLocStyleId,
          text: '내 위치',
          rank: 999,
        ),
      );
    } catch (_) {}
  }

  // ── 검색 ──────────────────────────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    final query = q.trim();
    if (query.isEmpty) {
      final generation = _searchGeneration.begin();
      setState(() {
        _places = [];
        _selected = null;
        _searchState = _PickerSearchState.initial;
      });
      unawaited(_enqueueMarkerApply(generation));
      return;
    }
    if (query.length < 2) {
      final generation = _searchGeneration.begin();
      setState(() {
        _places = <_Place>[];
        _selected = null;
        _searchState = _PickerSearchState.initial;
      });
      unawaited(_enqueueMarkerApply(generation));
      return;
    }
    setState(() {});
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return;
    final generation = _searchGeneration.begin();
    setState(() {
      _searchState = _PickerSearchState.searching;
      _places = <_Place>[];
      _selected = null;
    });
    unawaited(_enqueueMarkerApply(generation));
    try {
      final lat = _position?.latitude ?? _defaultLat;
      final lng = _position?.longitude ?? _defaultLng;
      final page = await _localSearch.search(
        PlaceSearchQuery(
          originType: _position == null
              ? PlaceSearchOriginType.fallback
              : PlaceSearchOriginType.device,
          latitude: lat,
          longitude: lng,
          keyword: normalized,
          category: 'location_picker',
          radiusM: null,
          page: 1,
          size: 15,
        ),
      );
      if (!mounted || !_searchGeneration.isCurrent(generation)) return;
      final places = page.items.map(_Place.fromSearchItem).toList();
      setState(() {
        _places = places;
        _searchState = places.isEmpty
            ? _PickerSearchState.empty
            : _PickerSearchState.results;
      });
      await _enqueueMarkerApply(generation);
      if (!mounted || !_searchGeneration.isCurrent(generation)) return;
      if (places.isNotEmpty && !_listOnlyMode) {
        await _moveCameraProgrammatically(
          target: places.first.latLng,
          zoomLevel: 14,
        );
        if (!mounted || !_searchGeneration.isCurrent(generation)) return;
        try {
          await _sheetCtrl.animateTo(
            _listOnlyMode ? 0.85 : 0.58,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } catch (_) {}
      }
    } on KakaoLocalSearchException catch (error) {
      if (!mounted || !_searchGeneration.isCurrent(generation)) return;
      final failure = switch (error.kind) {
        KakaoLocalFailureKind.timeout => _PickerSearchFailure.timeout,
        KakaoLocalFailureKind.offline => _PickerSearchFailure.offline,
        _ => _PickerSearchFailure.other,
      };
      setState(() {
        _places = <_Place>[];
        _selected = null;
        _searchState = _PickerSearchState.failure(failure);
      });
      unawaited(_enqueueMarkerApply(generation));
      final message = switch (error.kind) {
        KakaoLocalFailureKind.timeout => '검색 시간이 초과됐어요.',
        KakaoLocalFailureKind.offline => '네트워크 연결을 확인해 주세요.',
        _ => '장소를 검색하지 못했어요.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      dev.log('장소 검색 실패', name: 'LocationPicker');
      if (mounted && _searchGeneration.isCurrent(generation)) {
        setState(() {
          _places = <_Place>[];
          _selected = null;
          _searchState = const _PickerSearchState.failure(
            _PickerSearchFailure.other,
          );
        });
        unawaited(_enqueueMarkerApply(generation));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('장소를 검색하지 못했어요.')),
        );
      }
    }
  }

  Future<void> _selectPlace(_Place place) async {
    setState(() => _selected = place);
    if (_listOnlyMode) return;
    await _enqueueMarkerApply(_searchGeneration.current);
    await _moveCameraProgrammatically(
      target: place.latLng,
      zoomLevel: 16,
    );
  }

  void _confirm() {
    if (_selected == null) return;
    Navigator.of(context).pop(LocationPickResult(
      name: _selected!.name,
      address: _selected!.address,
      lat: _selected!.lat,
      lng: _selected!.lng,
    ));
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          '위치 추가',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: _listOnlyMode
            ? null
            : [
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 44, minWidth: 56),
                  child: TextButton(
                    onPressed: _selected != null ? _confirm : null,
                    child: Text(
                      '완료',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: _selected != null
                            ? AppTheme.primaryColor
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ],
      ),
      body: _listOnlyMode
          ? _buildListOnlyLayout()
          : Column(
              children: [
                _buildSearchBar(),
                const Divider(
                    height: 1, thickness: 1, color: AppTheme.dividerColor),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: KeyedSubtree(
                          key: const Key('location_picker_map_surface'),
                          child: _buildMap(),
                        ),
                      ),
                      _buildMyLocationButton(),
                      _buildSheet(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildListOnlyLayout() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          _buildSearchBar(),
          const Divider(height: 1, thickness: 1, color: AppTheme.dividerColor),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.34,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 10.h),
              child: _buildListOnlyHeader(),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppTheme.dividerColor),
          Expanded(child: _buildSearchBody(_listScrollController)),
          Container(
            key: const Key('location_picker_list_action'),
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppTheme.dividerColor),
              ),
            ),
            child: FilledButton(
              key: const Key('location_picker_list_complete'),
              onPressed: _selected != null ? _confirm : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('선택 완료'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListOnlyHeader() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const Key('location_picker_list_only_badge'),
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppTheme.actionContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 20.sp,
                    color: AppTheme.actionBase,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _mapRetriesExhausted
                          ? '지도 재시도를 마쳐 목록으로 계속해요.'
                          : '지도를 불러오지 못했어요. 목록으로 계속할 수 있어요.',
                      style: TextStyle(
                        fontSize: AppTheme.fontCaption.sp,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brandDeep,
                      ),
                    ),
                  ),
                ],
              ),
              if (!_mapRetriesExhausted) ...[
                SizedBox(height: 8.h),
                OutlinedButton.icon(
                  key: const Key('location_picker_list_retry_button'),
                  onPressed: _recreateMapView,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('지도 다시 시도'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          _searchHeader(),
          key: const Key('location_picker_result_header'),
          style: TextStyle(
            fontSize: AppTheme.fontBody.sp,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 18.sp,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 7.w),
            Expanded(
              child: Text(
                '선택한 장소 정보가 게시물에 표시돼요. 장소는 1곳만 선택할 수 있어요.',
                key: const Key('location_picker_privacy_notice'),
                style: TextStyle(
                  fontSize: AppTheme.fontCaption.sp,
                  height: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (_searchState.status != _PickerSearchStatus.results &&
            _searchState.status != _PickerSearchStatus.searching &&
            _locationNotice() != null) ...[
          SizedBox(height: 10.h),
          _locationNotice()!,
        ],
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          _debounce?.cancel();
          if (v.trim().isNotEmpty) _search(v.trim());
        },
        decoration: InputDecoration(
          hintText: '장소명 또는 주소 검색',
          hintStyle:
              TextStyle(fontSize: 14.sp, color: AppTheme.secondaryTextColor),
          prefixIcon: Icon(Icons.search,
              size: 20.w, color: AppTheme.secondaryTextColor),
          suffixIcon: _searchState.status == _PickerSearchStatus.searching
              ? Padding(
                  padding: EdgeInsets.all(12.w),
                  child: SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryColor),
                  ),
                )
              : _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          size: 18.w, color: AppTheme.secondaryTextColor),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchCtrl.clear();
                        final generation = _searchGeneration.begin();
                        setState(() {
                          _places = [];
                          _selected = null;
                          _searchState = _PickerSearchState.initial;
                        });
                        unawaited(_enqueueMarkerApply(generation));
                      },
                    )
                  : null,
          filled: true,
          fillColor: AppTheme.subtleBackground,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24.r),
            borderSide:
                const BorderSide(color: AppTheme.primaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (_locLoading) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }
    final initialPos = _initialMapPosition ??= _position != null
        ? LatLng(latitude: _position!.latitude, longitude: _position!.longitude)
        : const LatLng(latitude: _defaultLat, longitude: _defaultLng);
    if (widget.mapPlaceholderBuilder == null) {
      _armMapInitWatchdog();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.mapPlaceholderBuilder != null)
          widget.mapPlaceholderBuilder!(context)
        else
          KakaoMap(
            key: ValueKey<int>(_mapViewGeneration),
            initialPosition: initialPos,
            onMapCreated: (ctrl) async {
              await _labelSub?.cancel();
              await _camSub?.cancel();
              if (!mounted) {
                ctrl.dispose();
                return;
              }
              if (_listOnlyMode) {
                ctrl.dispose();
                return;
              }
              _mapCtrl = ctrl;
              _mapReady = false;
              _mapInitFailed = false;
              _markerLayerAdded = false;
              _markerIds = <String>[];
              _markerCleanupIds.clear();

              _labelSub = ctrl.onLabelClickedStream.listen((event) {
                _Place? place;
                for (final candidate in _places) {
                  if (candidate.id == event.labelId) {
                    place = candidate;
                    break;
                  }
                }
                if (place != null && mounted) {
                  unawaited(_selectPlace(place));
                }
              });

              _camSub = ctrl.onCameraMoveEndStream.listen((event) {
                if (!mounted || !identical(_mapCtrl, ctrl)) return;
                final resolution = resolveCameraMove(
                  movedBy: event.movedBy,
                  latitude: event.latitude,
                  longitude: event.longitude,
                  now: DateTime.now(),
                  latestMoveToken: _programmaticMoveToken,
                  pending: _pendingProgrammaticMove,
                );
                if (resolution.consumePending) {
                  _pendingProgrammaticMove = null;
                }
              });

              unawaited(_onMapReady(ctrl));
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
                  if (_mapRetriesExhausted)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '이 화면에서는 목록으로 계속할 수 있어요.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _recreateMapView,
                      child: const Text('다시 시도'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _armMapInitWatchdog() {
    if (_mapInitWatchdog != null || _mapReady || _listOnlyMode) return;
    _mapInitWatchdog = Timer(const Duration(seconds: 15), () {
      _mapInitWatchdog = null;
      if (!mounted || _mapReady || _listOnlyMode) return;
      dev.log('지도 생성 응답 시간 초과', name: 'LocationPicker');
      setState(() {
        _mapInitFailed = true;
        _listOnlyMode = true;
        _mapRetriesExhausted = _mapRetryCount >= 2;
      });
    });
  }

  Future<void> _recreateMapView() async {
    if (!mounted || _mapRetriesExhausted) return;
    _mapInitWatchdog?.cancel();
    _mapInitWatchdog = null;
    unawaited(_labelSub?.cancel());
    unawaited(_camSub?.cancel());
    _labelSub = null;
    _camSub = null;
    setState(() {
      _mapRetryCount += 1;
      _mapCtrl = null;
      _mapReady = false;
      _mapInitFailed = false;
      _listOnlyMode = false;
      _markerLayerAdded = false;
      _markerIds = <String>[];
      _markerCleanupIds.clear();
      _mapViewGeneration += 1;
    });
    final evaluator = widget.mapRetryEvaluator;
    if (evaluator == null) return;
    final succeeded = await evaluator(_mapRetryCount);
    if (!mounted) return;
    if (succeeded) {
      setState(() {
        _mapReady = true;
        _mapInitFailed = false;
        _listOnlyMode = false;
        _mapRetriesExhausted = false;
      });
      return;
    }
    setState(() {
      _mapReady = false;
      _mapInitFailed = true;
      _listOnlyMode = true;
      _mapRetriesExhausted = _mapRetryCount >= 2;
    });
  }

  Widget _buildMyLocationButton() {
    return Positioned(
      right: 12.w,
      bottom: 300.h,
      child: GestureDetector(
        onTap: () async {
          if (_locationState == _PickerLocationState.serviceDisabled) {
            _showLocationSettingsPrompt(appSettings: false);
            return;
          }
          if (_locationState == _PickerLocationState.deniedForever) {
            _showLocationSettingsPrompt(appSettings: true);
            return;
          }
          if (_position == null) {
            await _requestLocation();
            return;
          }
          if (!_mapReady) return;
          await _moveCameraProgrammatically(
            target: LatLng(
              latitude: _position!.latitude,
              longitude: _position!.longitude,
            ),
            zoomLevel: 15,
          );
        },
        child: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Icon(Icons.my_location_rounded,
              size: 22.w, color: AppTheme.primaryColor),
        ),
      ),
    );
  }

  Widget _buildSheet() {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactInitialSize = textScale >= 1.5 ? 0.58 : 0.35;
    final compactMinSize = textScale >= 1.5 ? 0.32 : 0.12;
    return DraggableScrollableSheet(
      key: const Key('location_picker_draggable_sheet'),
      controller: _sheetCtrl,
      initialChildSize: _listOnlyMode ? 0.85 : compactInitialSize,
      minChildSize: compactMinSize,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: [compactMinSize, compactInitialSize, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, -3),
              )
            ],
          ),
          child: Column(
            children: [
              // 핸들
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_listOnlyMode) ...[
                      Container(
                        key: const Key('location_picker_list_only_badge'),
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 7.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.actionContainer,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.list_alt_rounded,
                              size: 17.sp,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: 6.w),
                            Flexible(
                              child: Text(
                                _mapRetriesExhausted
                                    ? '지도 재시도를 마쳐 이 화면에서는 목록만 사용해요'
                                    : '지도 없이 목록에서 선택합니다',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            if (!_mapRetriesExhausted)
                              IconButton(
                                key: const Key(
                                  'location_picker_list_retry_button',
                                ),
                                onPressed: _recreateMapView,
                                tooltip: '지도 다시 시도',
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 17.sp,
                          color: AppTheme.primaryColor,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            _searchHeader(),
                            key: const Key('location_picker_result_header'),
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16.sp,
                          color: AppTheme.secondaryTextColor,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            '선택한 장소 정보가 게시물에 표시돼요. 장소는 1곳만 선택할 수 있어요.',
                            key: const Key('location_picker_privacy_notice'),
                            style: TextStyle(
                              fontSize: 11.sp,
                              height: 1.4,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_searchState.status != _PickerSearchStatus.results &&
                        _searchState.status != _PickerSearchStatus.searching &&
                        _locationNotice() != null) ...[
                      SizedBox(height: 9.h),
                      _locationNotice()!,
                    ],
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.dividerColor,
              ),
              Expanded(
                child: _buildSearchBody(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  String _searchHeader() {
    return switch (_searchState.status) {
      _PickerSearchStatus.initial => '장소를 검색하세요',
      _PickerSearchStatus.searching => '장소를 찾고 있어요',
      _PickerSearchStatus.results => _position == null
          ? '현재 위치 없이 검색한 결과 ${_places.length}개'
          : '검색 결과 ${_places.length}개',
      _PickerSearchStatus.empty => '검색 결과 0개',
      _PickerSearchStatus.failure => '검색을 완료하지 못했어요',
    };
  }

  Widget? _locationNotice() {
    final (message, actionLabel, action) = switch (_locationState) {
      _PickerLocationState.denied => (
          '위치 권한이 없어 주변 대신 검색으로 찾을 수 있어요.',
          '위치 허용',
          _requestLocation,
        ),
      _PickerLocationState.deniedForever => (
          '위치 권한이 꺼져 있어 검색 기준 위치를 사용해요.',
          '설정 열기',
          () async => _showLocationSettingsPrompt(appSettings: true),
        ),
      _PickerLocationState.serviceDisabled => (
          '위치 서비스가 꺼져 있어 검색 기준 위치를 사용해요.',
          '설정 열기',
          () async => _showLocationSettingsPrompt(appSettings: false),
        ),
      _PickerLocationState.unavailable => (
          '현재 위치를 확인하지 못해 검색 기준 위치를 사용해요.',
          '다시 확인',
          _requestLocation,
        ),
      _ => (null, null, null),
    };
    if (message == null || actionLabel == null || action == null) return null;
    return Container(
      key: const Key('location_picker_permission_notice'),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackground,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 17.sp,
            color: AppTheme.secondaryTextColor,
          ),
          SizedBox(width: 7.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11.sp,
                height: 1.35,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: TextButton(
              onPressed: action,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBody(ScrollController scrollController) {
    return switch (_searchState.status) {
      _PickerSearchStatus.initial => _buildCenteredState(
          key: const Key('location_picker_initial_state'),
          icon: Icons.search_rounded,
          title: _searchCtrl.text.trim().isEmpty
              ? '위치를 검색해 추가하세요'
              : '두 글자 이상 입력해 주세요',
        ),
      _PickerSearchStatus.searching => _buildCenteredState(
          key: const Key('location_picker_searching_state'),
          title: '검색 결과를 불러오고 있어요',
          progress: true,
        ),
      _PickerSearchStatus.empty => _buildCenteredState(
          key: const Key('location_picker_empty_state'),
          icon: Icons.search_off_rounded,
          title: '검색 결과가 없습니다',
          description: '장소명이나 주소를 다르게 입력해 보세요.',
        ),
      _PickerSearchStatus.failure => _buildSearchFailure(),
      _PickerSearchStatus.results => ListView.separated(
          controller: scrollController,
          padding: EdgeInsets.only(top: 4.h, bottom: 16.h),
          itemCount: _places.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.subtleBackground,
            indent: 56,
          ),
          itemBuilder: (_, i) => _buildTile(_places[i]),
        ),
    };
  }

  Widget _buildSearchFailure() {
    final (title, description) = switch (_searchState.failure) {
      _PickerSearchFailure.offline => (
          '네트워크 연결을 확인해 주세요',
          '연결 상태를 확인한 뒤 다시 검색해 보세요.',
        ),
      _PickerSearchFailure.timeout => (
          '검색 시간이 초과됐어요',
          '잠시 후 같은 장소를 다시 검색해 보세요.',
        ),
      _ => (
          '장소를 검색하지 못했어요',
          '잠시 후 다시 시도해 주세요.',
        ),
    };
    return _buildCenteredState(
      key: const Key('location_picker_failure_state'),
      icon: Icons.wifi_off_rounded,
      title: title,
      description: description,
      actionLabel: '다시 시도',
      onAction: () => _search(_searchCtrl.text),
    );
  }

  Widget _buildCenteredState({
    required Key key,
    required String title,
    IconData? icon,
    String? description,
    bool progress = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      key: key,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (progress)
              const CircularProgressIndicator(color: AppTheme.primaryColor)
            else if (icon != null)
              Icon(icon, size: 32.sp, color: AppTheme.neutral400),
            SizedBox(height: 12.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryTextColor,
              ),
            ),
            if (description != null) ...[
              SizedBox(height: 6.h),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.4,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 12.h),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTile(_Place place) {
    final isSelected = _selected?.id == place.id;
    return Semantics(
      key: Key('location_picker_place_${place.id}'),
      label: '장소 선택: ${place.name}',
      button: true,
      selected: isSelected,
      checked: isSelected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        excludeFromSemantics: true,
        onTap: () => _selectPlace(place),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.05)
                  : null,
              border: Border(
                left: BorderSide(
                  color:
                      isSelected ? AppTheme.primaryColor : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 24.w,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.secondaryTextColor,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryTextColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (place.address.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            place.address,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.secondaryTextColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.check_rounded,
                      size: 20.w,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
