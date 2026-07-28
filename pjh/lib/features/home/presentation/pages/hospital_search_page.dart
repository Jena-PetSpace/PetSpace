import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
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

// ── 메인 페이지 ──────────────────────────────────────────────────────────────────

class HospitalSearchPage extends StatefulWidget {
  const HospitalSearchPage({super.key});

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
  LatLng? _initialMapPosition;

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
  String? _manualSearchKeyword;
  String? _resultManualSearchKeyword;
  _PlaceSearchUiState _searchUiState = _PlaceSearchUiState.idle;
  HospitalPlace? _selectedPlace;
  bool _showDetail = false;
  _SheetSize _sheetSize = _SheetSize.collapsed;

  // ── 스크롤/검색 ──
  final ScrollController _listScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<String> _currentMarkerIds = [];
  final Set<String> _markerCleanupIds = <String>{};

  List<HospitalPlace> get _places =>
      _categories[_selectedCategory].isFavoriteTab
          ? _savedPlaceView
          : _searchResults;

  bool get _hasUnresolvedLegacyPlaces =>
      _savedCatalog?.unresolvedLegacyIds.isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFavorites();
    _initializeLocationWithoutPrompt();
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      if (_searchFocusNode.hasFocus) {
        if (_sheetSize != _SheetSize.collapsed) {
          setState(() => _sheetSize = _SheetSize.collapsed);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _labelClickSub?.cancel();
    _cameraMoveEndSub?.cancel();
    _mapController?.dispose();
    _listScrollController.dispose();
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

  double _sheetHeight(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;
    if (_showDetail) return (screenH * 0.42).clamp(320.0, 420.0);
    switch (_sheetSize) {
      case _SheetSize.collapsed:
        return 56.h;
      case _SheetSize.half:
        return (screenH * 0.32).clamp(200.0, 280.0);
      case _SheetSize.full:
        return screenH - 120.h - topPad;
    }
  }

  Future<void> _syncMapPaddingToSheet() async {
    if (_mapController == null || !_mapReady) return;
    final sheetPx = _sheetHeight(context).toInt();
    try {
      await _mapController!
          .setPadding(left: 0, top: 0, right: 0, bottom: sheetPx);
    } catch (_) {
      dev.log('[HS] setPadding 실패', name: 'HospitalSearch');
    }
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

  void _onSheetDrag(DragUpdateDetails details) {
    if (_showDetail) return;
    final delta = details.primaryDelta ?? 0;
    bool changed = false;
    if (delta < -8) {
      if (_sheetSize == _SheetSize.collapsed) {
        setState(() => _sheetSize = _SheetSize.half);
        changed = true;
      } else if (_sheetSize == _SheetSize.half) {
        setState(() => _sheetSize = _SheetSize.full);
        changed = true;
      }
    } else if (delta > 8) {
      if (_sheetSize == _SheetSize.full) {
        setState(() => _sheetSize = _SheetSize.half);
        changed = true;
      } else if (_sheetSize == _SheetSize.half) {
        setState(() => _sheetSize = _SheetSize.collapsed);
        changed = true;
      }
    }
    if (changed) _syncMapPaddingToSheet();
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters}m';
  }

  @override
  Widget build(BuildContext context) {
    final canPopNow = !_showDetail && _sheetSize != _SheetSize.full;
    return PopScope(
      canPop: canPopNow,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_sheetSize == _SheetSize.full) {
          setState(() => _sheetSize = _SheetSize.half);
        } else if (_showDetail) {
          _closeDetail();
        }
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
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildMap()),
                    _buildMapOverlayButtons(),
                    if (_searching) _buildSearchingIndicator(),
                    if (_showReSearchButton && !_showDetail)
                      _buildReSearchButton(),
                    _buildBottomSheet(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
