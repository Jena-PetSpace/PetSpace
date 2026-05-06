import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/api_config.dart';
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

  factory HospitalPlace.fromJson(Map<String, dynamic> json) {
    return HospitalPlace(
      id: json['id'] as String? ?? '',
      name: json['place_name'] as String? ?? '',
      address: json['road_address_name'] as String? ??
          json['address_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      lat: double.tryParse(json['y'] as String? ?? '0') ?? 0,
      lng: double.tryParse(json['x'] as String? ?? '0') ?? 0,
      category: json['category_name'] as String? ?? '',
      distanceM: int.tryParse(json['distance'] as String? ?? ''),
      placeUrl: json['place_url'] as String? ?? '',
    );
  }

  HospitalPlace copyWith({bool? isFavorite}) => HospitalPlace(
        id: id, name: name, address: address, phone: phone,
        lat: lat, lng: lng, category: category,
        distanceM: distanceM, isFavorite: isFavorite ?? this.isFavorite,
        placeUrl: placeUrl,
      );

  LatLng get latLng => LatLng(latitude: lat, longitude: lng);
}

// ── 카테고리 ────────────────────────────────────────────────────────────────────

class _Category {
  final String iconAsset;
  final String label;
  final String query;
  final bool isFavoriteTab;
  const _Category({required this.iconAsset, required this.label, required this.query, this.isFavoriteTab = false});
}

const _categories = [
  _Category(iconAsset: 'assets/icons/category/cat_my_place.png', label: '내 장소', query: '', isFavoriteTab: true),
  _Category(iconAsset: 'assets/icons/category/cat_hospital.png', label: '동물병원', query: '동물병원'),
  _Category(iconAsset: 'assets/icons/category/cat_pharmacy.png', label: '약국', query: '동물약품 동물약국'),
  _Category(iconAsset: 'assets/icons/category/cat_cafe.png', label: '카페', query: '반려동물카페 펫카페'),
  _Category(iconAsset: 'assets/icons/category/cat_grooming.png', label: '미용실', query: '반려동물미용 애견미용'),
];

const _radii = [1000, 3000, 5000];
const _radiiLabel = ['1km', '3km', '5km'];
// 반경별 카카오맵 줌레벨 (카카오맵: 숫자 클수록 가까이, 15=약 1km, 13=약 3km, 12=약 5km)
const _radiusZoomLevels = [15, 13, 12];

enum _SheetSize { collapsed, half, full }

// ── 마커/위치 상수 (part 파일에서 공유) ────────────────────────────────────────────
const double _defaultLat = 37.5665;
const double _defaultLng = 126.9780;
const String _myLocationMarkerId = 'my_location';
const String _myLocationStyleId = 'my_location_style';
const String _placeStyleId = 'place_style';
const String _selectedPlaceStyleId = 'selected_place_style';
const String _favoritesPrefKey = 'hospital_search_favorites';

// ── 메인 페이지 ──────────────────────────────────────────────────────────────────

class HospitalSearchPage extends StatefulWidget {
  const HospitalSearchPage({super.key});

  @override
  State<HospitalSearchPage> createState() => _HospitalSearchPageState();
}

class _HospitalSearchPageState extends State<HospitalSearchPage> {
  // ── 지도 ──
  KakaoMapController? _mapController;
  StreamSubscription<LabelClickEvent>? _labelClickSub;
  StreamSubscription<CameraMoveEndEvent>? _cameraMoveEndSub;

  bool _mapReady = false;

  // ── 위치 ──
  double _cameraLat = _defaultLat;
  double _cameraLng = _defaultLng;
  Position? _position;
  String? _locationError;

  // ── UI 상태 ──
  bool _searching = false;
  bool _isFollowingLocation = true;
  bool _showReSearchButton = false;
  bool _suppressCameraMoveEvent = false;
  int _selectedCategory = 0;
  int _selectedRadiusIndex = 0;
  List<HospitalPlace> _places = [];
  final Set<String> _favoriteIds = {};
  HospitalPlace? _selectedPlace;
  bool _showDetail = false;
  _SheetSize _sheetSize = _SheetSize.collapsed;

  // ── 스크롤/검색 ──
  final ScrollController _listScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<String> _currentMarkerIds = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _getLocation();
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
    _labelClickSub?.cancel();
    _cameraMoveEndSub?.cancel();
    _listScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
      await _mapController!.setPadding(left: 0, top: 0, right: 0, bottom: sheetPx);
    } catch (e) {
      dev.log('[HS] setPadding 실패: $e', name: 'HospitalSearch');
    }
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

  bool _isValidCategoryForSelected(String category) {
    const whitelist = <List<String>>[
      [],
      ['동물병원', '의원'],
      ['동물약국', '동물약품', '약국'],
      ['카페', '펫카페', '반려동물카페', '애견카페'],
      ['미용', '애견미용', '반려동물미용', '펫샵', '펫숍', '그루밍'],
    ];
    if (_selectedCategory < 0 || _selectedCategory >= whitelist.length) {
      return true;
    }
    final keywords = whitelist[_selectedCategory];
    if (keywords.isEmpty) return true;
    return keywords.any((kw) => category.contains(kw));
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
                    if (_showReSearchButton && !_showDetail) _buildReSearchButton(),
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
