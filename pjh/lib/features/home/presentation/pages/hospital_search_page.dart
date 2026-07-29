import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/place_search/kakao_local_data_source.dart';
import '../../../../core/place_search/place_search_query.dart';
import '../../../../core/place_search/saved_place_local_data_source.dart';
import '../../../../core/utils/share_origin.dart';
import '../../../../shared/themes/app_theme.dart';

part 'hospital_search_page_map.dart';
part 'hospital_search_page_search.dart';
part 'hospital_search_page_actions.dart';
part 'hospital_search_page_ui.dart';

// ── 데이터 모델 ────────────────────────────────────────────────────────────────

class HospitalPlace {
  final String id;
  final String name;
  final String address;
  final String phone;
  final double lat;
  final double lng;
  final String category;
  final int? distanceM;
  final bool isFavorite;
  final String placeUrl;

  const HospitalPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.category,
    this.distanceM,
    this.isFavorite = false,
    this.placeUrl = '',
  });

  factory HospitalPlace.fromSearchItem(PlaceSearchItem item) {
    return HospitalPlace(
      id: item.providerPlaceId,
      name: item.name,
      address: item.address,
      phone: item.phone,
      lat: item.latitude,
      lng: item.longitude,
      category: item.category,
      distanceM: item.distanceM,
      placeUrl: item.placeUrl,
    );
  }

  HospitalPlace copyWith({bool? isFavorite}) => HospitalPlace(
        id: id,
        name: name,
        address: address,
        phone: phone,
        lat: lat,
        lng: lng,
        category: category,
        distanceM: distanceM,
        isFavorite: isFavorite ?? this.isFavorite,
        placeUrl: placeUrl,
      );

  LatLng get latLng => LatLng(latitude: lat, longitude: lng);

  PlaceSearchItem toSearchItem() => PlaceSearchItem(
        providerPlaceId: id,
        name: name,
        category: category,
        address: address,
        phone: phone,
        latitude: lat,
        longitude: lng,
        placeUrl: placeUrl,
        distanceM: distanceM,
      );
}

// ── 카테고리 ────────────────────────────────────────────────────────────────────

class _Category {
  final String iconAsset;
  final String label;
  final String primaryQuery;
  final List<String> supplementalQueries;
  final bool isFavoriteTab;
  const _Category({
    required this.iconAsset,
    required this.label,
    required this.primaryQuery,
    this.supplementalQueries = const <String>[],
    this.isFavoriteTab = false,
  });
}

const _categories = [
  _Category(
    iconAsset: 'assets/icons/category/cat_my_place.png',
    label: '내 장소',
    primaryQuery: '',
    isFavoriteTab: true,
  ),
  _Category(
    iconAsset: 'assets/icons/category/cat_hospital.png',
    label: '동물병원',
    primaryQuery: '동물병원',
  ),
  _Category(
    iconAsset: 'assets/icons/category/cat_pharmacy.png',
    label: '약국',
    primaryQuery: '동물약국',
    supplementalQueries: <String>['동물약품'],
  ),
  _Category(
    iconAsset: 'assets/icons/category/cat_cafe.png',
    label: '카페',
    primaryQuery: '반려동물카페',
    supplementalQueries: <String>['애견카페'],
  ),
  _Category(
    iconAsset: 'assets/icons/category/cat_grooming.png',
    label: '미용실',
    primaryQuery: '반려동물미용',
    supplementalQueries: <String>['애견미용'],
  ),
];

const _radii = [1000, 3000, 5000];
const _radiiLabel = ['1km', '3km', '5km'];
// 반경별 카카오맵 줌레벨 (카카오맵: 숫자 클수록 가까이, 15=약 1km, 13=약 3km, 12=약 5km)
const _radiusZoomLevels = [15, 13, 12];

@visibleForTesting
const double kPlaceSheetMin = 0.12;
@visibleForTesting
const double kPlaceSheetInitial = 0.42;
@visibleForTesting
const double kPlaceSheetMax = 0.88;
@visibleForTesting
const List<double> kPlaceSheetSnapSizes = <double>[
  kPlaceSheetMin,
  kPlaceSheetInitial,
  kPlaceSheetMax,
];

@visibleForTesting
int placeOrdinal(int index) => index + 1;

@visibleForTesting
String placeDistanceOriginLabel(PlaceSearchOriginType type) => switch (type) {
      PlaceSearchOriginType.device => '현재 위치 기준',
      PlaceSearchOriginType.mapCenter => '지도 중심 기준',
      PlaceSearchOriginType.manual => '검색 기준',
      PlaceSearchOriginType.fallback => '서울시청 주변 결과',
    };

enum _SheetSize { collapsed, half, full }

enum _LocationAccessState {
  checking,
  ready,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

enum _PlaceSearchUiState {
  idle,
  loading,
  empty,
  timeout,
  offline,
  unauthorized,
  rateLimit,
  server,
  invalidPayload,
}

// ── 마커/위치 상수 (part 파일에서 공유) ────────────────────────────────────────────
const double _defaultLat = 37.5665;
const double _defaultLng = 126.9780;
const String _myLocationMarkerId = 'my_location';
const String _myLocationStyleId = 'my_location_style';
const String _placeStyleId = 'place_style';
const String _selectedPlaceStyleId = 'selected_place_style';
const String _selectedPlaceInfoWindowId = 'selected_place_info_window';

@visibleForTesting
List<MarkerOption> buildPlaceMarkerOptions({
  required List<HospitalPlace> places,
  String? selectedPlaceId,
}) {
  return places.asMap().entries.map((entry) {
    final place = entry.value;
    final isSelected = place.id == selectedPlaceId;
    return MarkerOption(
      id: place.id,
      latLng: place.latLng,
      styleId: isSelected ? _selectedPlaceStyleId : _placeStyleId,
      text: '${placeOrdinal(entry.key)}',
      rank: isSelected ? 800 : 100,
    );
  }).toList(growable: false);
}

// ── 메인 페이지 ──────────────────────────────────────────────────────────────────

class HospitalSearchPage extends StatefulWidget {
  const HospitalSearchPage({super.key, this.mapBuilder});

  final WidgetBuilder? mapBuilder;

  @override
  State<HospitalSearchPage> createState() => _HospitalSearchPageState();
}

class _HospitalSearchPageState extends State<HospitalSearchPage>
    with WidgetsBindingObserver {
  final KakaoLocalDataSource _localSearch = sl<KakaoLocalDataSource>();
  final SavedPlaceLocalDataSource _savedPlaceStore =
      sl<SavedPlaceLocalDataSource>();
  final PlaceSearchGeneration _searchGeneration = PlaceSearchGeneration();

  // ── 지도 ──
  KakaoMapController? _mapController;
  StreamSubscription<LabelClickEvent>? _labelClickSub;
  StreamSubscription<CameraMoveEndEvent>? _cameraMoveEndSub;

  bool _mapReady = false;
  bool _mapInitFailed = false;
  bool _markerLayerAdded = false;
  Future<void> _markerQueue = Future<void>.value();
  Future<void> _savedPlaceMutationQueue = Future<void>.value();
  int _markerGeneration = 0;
  int _programmaticMoveToken = 0;
  PendingProgrammaticMove? _pendingProgrammaticMove;
  DateTime? _suppressCameraMoveUntil;
  LatLng? _initialMapPosition;
  Uint8List? _defaultPlaceMarkerBytes;
  Uint8List? _selectedPlaceMarkerBytes;

  // ── 위치 ──
  double _cameraLat = _defaultLat;
  double _cameraLng = _defaultLng;
  Position? _position;
  _LocationAccessState _locationState = _LocationAccessState.checking;
  PlaceSearchOrigin _searchOrigin = PlaceSearchOrigin(
    type: PlaceSearchOriginType.fallback,
    latitude: _defaultLat,
    longitude: _defaultLng,
  );

  // ── UI 상태 ──
  bool _searching = false;
  bool _isFollowingLocation = true;
  bool _showReSearchButton = false;
  int _selectedCategory = 0;
  int _selectedRadiusIndex = 0;
  int _resultCategory = 0;
  List<HospitalPlace> _searchResults = <HospitalPlace>[];
  List<HospitalPlace> _savedPlaceView = <HospitalPlace>[];
  SavedPlaceCatalog? _savedCatalog;
  bool _manualResultsActive = false;
  String? _manualSearchKeyword;
  String? _resultManualSearchKeyword;
  _PlaceSearchUiState _searchUiState = _PlaceSearchUiState.idle;
  HospitalPlace? _selectedPlace;
  bool _showDetail = false;
  _SheetSize _desiredSheetSize = _SheetSize.half;
  _SheetSize? _programmaticSheetTarget;
  bool _sheetAnimationRunning = false;
  int _sheetAnimationGeneration = 0;
  bool _preserveCollapsedAfterSearch = false;
  bool _pendingEmptyCollapse = false;
  bool _sheetAttachCallbackScheduled = false;
  bool _observedSearching = false;
  _PlaceSearchUiState _observedSearchUiState = _PlaceSearchUiState.idle;
  double _effectiveSheetMin = kPlaceSheetMin;
  double _effectiveSheetInitial = kPlaceSheetInitial;

  // ── 스크롤/검색 ──
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ValueNotifier<double> _sheetExtent =
      ValueNotifier<double>(kPlaceSheetInitial);
  final ValueNotifier<double> _mapRenderExtent =
      ValueNotifier<double>(kPlaceSheetInitial);
  Timer? _mapResizeThrottleTimer;
  Timer? _sheetSettleTimer;
  double _pendingMapRenderExtent = kPlaceSheetInitial;
  Future<void> _mapViewportQueue = Future<void>.value();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<String> _currentMarkerIds = [];
  final Set<String> _markerCleanupIds = <String>{};

  List<HospitalPlace> get _places =>
      _categories[_selectedCategory].isFavoriteTab && !_manualResultsActive
          ? _savedPlaceView
          : _searchResults;

  bool get _hasUnresolvedLegacyPlaces =>
      _savedCatalog?.unresolvedLegacyIds.isNotEmpty ?? false;

  _SheetSize get _sheetSize {
    if (!_sheetController.isAttached) return _desiredSheetSize;
    return _sheetSizeForExtent(_sheetController.size);
  }

  set _sheetSize(_SheetSize value) {
    if (value == _SheetSize.collapsed &&
        (_searching || _searchUiState == _PlaceSearchUiState.loading)) {
      _pendingEmptyCollapse = true;
      return;
    }
    _pendingEmptyCollapse = false;
    _desiredSheetSize = value;
    _animateSheetTo(value);
  }

  void _setSheetSizeImmediately(_SheetSize value) {
    _pendingEmptyCollapse = false;
    _desiredSheetSize = value;
    _animateSheetTo(value);
  }

  _SheetSize _sheetSizeForExtent(double extent) {
    final collapsedHalfThreshold =
        (_effectiveSheetMin + _effectiveSheetInitial) / 2;
    final halfFullThreshold = (_effectiveSheetInitial + kPlaceSheetMax) / 2;
    if (extent < collapsedHalfThreshold) return _SheetSize.collapsed;
    if (extent < halfFullThreshold) return _SheetSize.half;
    return _SheetSize.full;
  }

  double _extentForSheetSize(_SheetSize size) => switch (size) {
        _SheetSize.collapsed => _effectiveSheetMin,
        _SheetSize.half => _effectiveSheetInitial,
        _SheetSize.full => kPlaceSheetMax,
      };

  void _animateSheetTo(_SheetSize size) {
    final previousTarget = _programmaticSheetTarget;
    _programmaticSheetTarget = size;
    if (!_sheetController.isAttached) {
      _sheetAnimationRunning = false;
      _scheduleSheetAttachSync();
      return;
    }
    final target = _extentForSheetSize(size);
    if ((_sheetController.size - target).abs() < 0.004 &&
        !_sheetAnimationRunning &&
        (previousTarget == null || previousTarget == size)) {
      _programmaticSheetTarget = null;
      _sheetAnimationRunning = false;
      return;
    }
    final generation = ++_sheetAnimationGeneration;
    _sheetAnimationRunning = true;
    unawaited(
      _sheetController
          .animateTo(
            target,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .timeout(
            const Duration(milliseconds: 420),
            onTimeout: () {},
          )
          .whenComplete(() {
        if (!mounted || generation != _sheetAnimationGeneration) return;
        _programmaticSheetTarget = null;
        _sheetAnimationRunning = false;
        if (_sheetController.isAttached) {
          _desiredSheetSize = _sheetSizeForExtent(_sheetController.size);
        } else {
          _desiredSheetSize = size;
        }
      }).catchError((Object error) {
        dev.log(
          '시트 이동 실패',
          name: 'HospitalSearch',
          error: error,
        );
      }),
    );
  }

  void _scheduleSheetAttachSync() {
    if (_sheetAttachCallbackScheduled) return;
    _sheetAttachCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sheetAttachCallbackScheduled = false;
      if (!mounted) return;
      if (!_sheetController.isAttached) {
        _scheduleSheetAttachSync();
        return;
      }
      final size = _sheetController.size;
      _sheetExtent.value = size;
      _applyMapRenderExtent(size);
      final pendingTarget = _programmaticSheetTarget;
      if (pendingTarget != null && !_sheetAnimationRunning) {
        _animateSheetTo(pendingTarget);
      }
    });
  }

  void _observeSearchSheetTransition() {
    final wasBusy = _observedSearching ||
        _observedSearchUiState == _PlaceSearchUiState.loading;
    final isBusy = _searching || _searchUiState == _PlaceSearchUiState.loading;
    final searchCompleted = wasBusy && !isBusy;
    _observedSearching = _searching;
    _observedSearchUiState = _searchUiState;
    if (!searchCompleted) return;

    final shouldCollapse = _searchUiState == _PlaceSearchUiState.empty &&
        _selectedPlace == null &&
        (_pendingEmptyCollapse || wasBusy);
    _pendingEmptyCollapse = false;
    if (!shouldCollapse) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _searching ||
          _searchUiState != _PlaceSearchUiState.empty ||
          _selectedPlace != null) {
        return;
      }
      _desiredSheetSize = _SheetSize.collapsed;
      _animateSheetTo(_SheetSize.collapsed);
    });
  }

  void _handleSheetExtentChanged() {
    if (!_sheetController.isAttached) return;
    final extent = _sheetController.size;
    if (_programmaticSheetTarget == null) {
      _desiredSheetSize = _sheetSizeForExtent(extent);
      if ((_searching || _searchUiState == _PlaceSearchUiState.loading) &&
          _desiredSheetSize == _SheetSize.collapsed) {
        _preserveCollapsedAfterSearch = true;
      }
    }
    if ((_sheetExtent.value - extent).abs() > 0.001) {
      _sheetExtent.value = extent;
    }
    _scheduleMapViewportSync(extent);
  }

  void _scheduleMapViewportSync(double extent) {
    _pendingMapRenderExtent = extent;
    _sheetSettleTimer?.cancel();
    _sheetSettleTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _applyMapRenderExtent(_pendingMapRenderExtent);
      unawaited(_syncMapPaddingToSheet());
    });
    if (_mapResizeThrottleTimer != null) return;
    _mapResizeThrottleTimer = Timer(const Duration(milliseconds: 100), () {
      _mapResizeThrottleTimer = null;
      if (!mounted) return;
      _applyMapRenderExtent(_pendingMapRenderExtent);
      unawaited(_syncMapPaddingToSheet());
    });
  }

  void _applyMapRenderExtent(double extent) {
    final clamped = extent.clamp(_effectiveSheetMin, kPlaceSheetMax).toDouble();
    if ((_mapRenderExtent.value - clamped).abs() < 0.002) return;
    _suppressCameraMoveForViewportMutation();
    _mapRenderExtent.value = clamped;
  }

  void _suppressCameraMoveForViewportMutation() {
    _suppressCameraMoveUntil =
        DateTime.now().add(const Duration(milliseconds: 400));
  }

  bool _isCameraMoveSuppressed(DateTime now) {
    final until = _suppressCameraMoveUntil;
    return until != null && now.isBefore(until);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sheetController.addListener(_handleSheetExtentChanged);
    _loadFavorites();
    _initializeLocationWithoutPrompt();
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      if (_searchFocusNode.hasFocus) {
        _setSheetSizeImmediately(_SheetSize.collapsed);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _labelClickSub?.cancel();
    _cameraMoveEndSub?.cancel();
    _mapResizeThrottleTimer?.cancel();
    _sheetSettleTimer?.cancel();
    final controller = _mapController;
    if (controller != null) {
      unawaited(
        controller
            .removeInfoWindow(id: _selectedPlaceInfoWindowId)
            .catchError((Object _) {}),
      );
    }
    _mapController?.dispose();
    _sheetController
      ..removeListener(_handleSheetExtentChanged)
      ..dispose();
    _sheetExtent.dispose();
    _mapRenderExtent.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_initializeLocationWithoutPrompt(refreshSearch: false));
    }
  }

  Future<void> _syncMapPaddingToSheet() async {
    final controller = _mapController;
    if (controller == null || !_mapReady) return;
    _mapViewportQueue =
        _mapViewportQueue.catchError((Object _) {}).then((_) async {
      if (!mounted || !identical(_mapController, controller) || !_mapReady) {
        return;
      }
      _suppressCameraMoveForViewportMutation();
      try {
        await controller.setPadding(
          left: 0,
          top: 0,
          right: 0,
          bottom: 24.h.round(),
        );
      } catch (error) {
        dev.log(
          '[HS] setPadding 실패',
          name: 'HospitalSearch',
          error: error,
        );
      } finally {
        _suppressCameraMoveForViewportMutation();
      }
    });
    await _mapViewportQueue;
  }

  Future<void> _serializeSavedPlaceMutation(
    Future<void> Function() mutation,
  ) {
    final next = _savedPlaceMutationQueue
        .catchError((Object _) {})
        .then((_) => mutation());
    _savedPlaceMutationQueue = next;
    return next;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters}m';
  }

  void _closePlaceScreen() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go('/home');
    }
  }

  void _handleSystemBack() {
    if (_showDetail) {
      _closeDetail();
      return;
    }
    switch (_sheetSize) {
      case _SheetSize.full:
        _sheetSize = _SheetSize.half;
        return;
      case _SheetSize.half:
        if (_searching || _searchUiState == _PlaceSearchUiState.loading) {
          _preserveCollapsedAfterSearch = true;
        }
        _setSheetSizeImmediately(_SheetSize.collapsed);
        return;
      case _SheetSize.collapsed:
        _closePlaceScreen();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    _observeSearchSheetTransition();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildLocationBanner(),
              _buildSearchBar(),
              _buildCategoryBar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ColoredBox(
                      color: AppTheme.neutral100,
                      child: Stack(
                        children: [
                          ValueListenableBuilder<double>(
                            valueListenable: _mapRenderExtent,
                            builder: (context, extent, child) {
                              final clearance = 18.h;
                              final mapHeight =
                                  (constraints.maxHeight * (1 - extent) -
                                          clearance)
                                      .clamp(0.0, constraints.maxHeight)
                                      .toDouble();
                              return Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: mapHeight,
                                child: _buildMap(),
                              );
                            },
                          ),
                          _buildCloseMapButton(),
                          _buildMapOverlayButtons(),
                          if (_searching) _buildSearchingIndicator(),
                          if (_showReSearchButton && !_showDetail)
                            _buildReSearchButton(),
                          _buildBottomSheet(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
