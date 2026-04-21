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
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/api_config.dart';
import '../../../../shared/themes/app_theme.dart';

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
  final String emoji;
  final String label;
  final String query;
  const _Category({required this.emoji, required this.label, required this.query});
}

const _categories = [
  _Category(emoji: '🏥', label: '동물병원', query: '동물병원'),
  _Category(emoji: '💊', label: '동물약국', query: '동물약국'),
  _Category(emoji: '✂️', label: '애견미용', query: '애견미용'),
  _Category(emoji: '🐾', label: '펫호텔', query: '펫호텔 애견호텔'),
];

const _radii = [1000, 3000, 5000];
const _radiiLabel = ['1km', '3km', '5km'];
// 반경별 카카오맵 줌레벨 (카카오맵: 숫자 클수록 가까이, 15=약 1km, 13=약 3km, 12=약 5km)
const _radiusZoomLevels = [15, 13, 12];

enum _SheetSize { collapsed, half, full }

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
  // 초기값은 아무 위치나 무방 — 지도 생성 후 즉시 내 위치로 이동함
  static const double _defaultLat = 37.5665;
  static const double _defaultLng = 126.9780;
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

  static const String _myLocationMarkerId = 'my_location';
  static const String _myLocationStyleId = 'my_location_style';
  static const String _placeStyleId = 'place_style';
  static const String _selectedPlaceStyleId = 'selected_place_style';
  List<String> _currentMarkerIds = [];

  // ── 초기화 ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _getLocation();
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      if (_searchFocusNode.hasFocus) {
        // 검색 포커스 시 시트를 full로 올려 지도를 가림
        // (PlatformView 리사이즈로 인한 지도 블랙아웃 회피)
        if (_sheetSize != _SheetSize.full) {
          setState(() => _sheetSize = _SheetSize.full);
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

  // ── 시트 높이 ────────────────────────────────────────────────────────────────

  double _sheetHeight(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;
    // 디테일: 버튼 2행이 잘리지 않을 최소 높이 보장 (화면 비율 기반)
    if (_showDetail) return (screenH * 0.42).clamp(320.0, 420.0);
    switch (_sheetSize) {
      case _SheetSize.collapsed:
        return 56.h;
      case _SheetSize.half:
        // 항목 3개 + 헤더: 화면 비율 기반 (작은/큰 기기 모두 대응)
        return (screenH * 0.32).clamp(200.0, 280.0);
      case _SheetSize.full:
        return screenH - 120.h - topPad;
    }
  }

  // 시트 상태에 맞게 지도 bottom padding 동기화 — 카메라 이동 기준점을 보이는 영역 중앙으로 맞춤
  Future<void> _syncMapPaddingToSheet() async {
    if (_mapController == null || !_mapReady) return;
    final sheetPx = _sheetHeight(context).toInt();
    try {
      await _mapController!.setPadding(left: 0, top: 0, right: 0, bottom: sheetPx);
    } catch (e) {
      dev.log('[HS] setPadding 실패: $e', name: 'HospitalSearch');
    }
  }

  // ── 위치 ────────────────────────────────────────────────────────────────────

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
        if (mounted) setState(() => _locationError = '설정에서 위치 권한을 허용해주세요');
        _searchCategory(_selectedCategory);
        return;
      }

      // lastKnown 우선, 없으면 getCurrentPosition
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

      // 지도가 준비돼 있으면 즉시 이동, 아니면 _onMapReady에서 처리
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

  // ── 지도 초기화 ──────────────────────────────────────────────────────────────

  Widget _buildMap() {
    // _position이 아직 없으면 로딩 인디케이터 표시 (M-1-1: 서울시청 초기 노출 방지)
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
      // 1) 마커 레이어 생성
      await controller.addMarkerLayer(
        layerId: KakaoMapController.defaultLabelLayerId,
      );
      dev.log('[HS] addMarkerLayer 완료', name: 'HospitalSearch');

      // 2) POI 클릭만 차단 (시각은 유지 — 지도 맥락 보존)
      await controller.setPoiClickable(isClickable: false);

      // 3) 마커 스타일 등록 (번호 텍스트 렌더링 활성화)
      await _registerMarkerStyles(controller);

      _mapReady = true;

      // 4) 시트 패딩 동기화 (카메라 이동 전에 적용)
      await _syncMapPaddingToSheet();

      // 5) 카메라 이동
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

      // 6) 마커 표시
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

  // ── 검색 ────────────────────────────────────────────────────────────────────

  Future<void> _searchCategory(int index) async {
    _searchFocusNode.unfocus();
    setState(() {
      _selectedCategory = index;
      _searching = true;
      _selectedPlace = null;
      _showDetail = false;
      _places = [];
      _showReSearchButton = false;
    });
    await _fetchPlaces(_categories[index].query);
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
        // 지도가 준비된 경우에만 마커 업데이트
        if (_mapReady) await _updateMarkers();
      } else {
        setState(() => _searching = false);
      }
    } catch (e) {
      dev.log('검색 오류: $e', name: 'HospitalSearch');
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── 마커 ────────────────────────────────────────────────────────────────────

  Future<void> _updateMarkers() async {
    if (_mapController == null || !_mapReady) return;

    // clearMarkers 대신 이전 마커 id만 제거 — clearMarkers는 레이어를 null로 만들어 E002 발생
    if (_currentMarkerIds.isNotEmpty) {
      try {
        await _mapController!.removeMarkers(ids: _currentMarkerIds);
      } catch (e) {
        dev.log('[HS] removeMarkers 실패: $e', name: 'HospitalSearch');
      }
    }
    // 내 위치 마커도 별도 제거
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

  Future<void> _registerMarkerStyles(KakaoMapController controller) async {
    try {
      final myLocBytes = (await rootBundle.load('assets/icons/map/my_location_dot.png'))
          .buffer.asUint8List();
      final placeBytes = (await rootBundle.load('assets/icons/map/place_marker.png'))
          .buffer.asUint8List();

      await controller.registerMarkerStyles(
        styles: [
          // 내 위치
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
          // 병원 기본 마커 (번호 텍스트 렌더링용)
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
          // 병원 선택 마커 (빨간 테두리 강조)
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
      // 스타일 등록 실패해도 마커 추가는 진행 (네이티브 기본 스타일로 fallback)
      dev.log('[HS] registerMarkerStyles 실패: $e\n$st', name: 'HospitalSearch', error: e);
    }
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

  // ── 액션 ────────────────────────────────────────────────────────────────────

  Future<void> _selectPlace(HospitalPlace place) async {
    setState(() {
      _selectedPlace = place;
      _showDetail = true;
      _sheetSize = _SheetSize.half;
    });
    // setPadding이 시트 높이를 반영해 카메라 중심을 보이는 지도 영역 중앙으로 맞춤
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
  }

  bool _isFavorite(String id) => _favoriteIds.contains(id);

  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── 외부 링크 액션 ────────────────────────────────────────────────────────────

  /// 카카오맵 장소 상세페이지 (리뷰/사진/영업시간/메뉴)
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

  /// 카카오맵 길찾기 (현재위치 → 병원)
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

  /// 공유 (병원명 + 주소 + 카카오맵 링크)
  Future<void> _sharePlace(HospitalPlace place) async {
    final url = place.placeUrl.isNotEmpty
        ? place.placeUrl.replaceFirst(RegExp(r'^http://'), 'https://')
        : 'https://map.kakao.com/link/search/${Uri.encodeComponent(place.name)}';
    final text = '${place.name}\n${place.address}\n$url';
    await Share.share(text, subject: place.name);
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

  // ── 빌드 ────────────────────────────────────────────────────────────────────

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

  // ── 오버레이 버튼 (내 위치 + 반경) ──────────────────────────────────────────

  Widget _buildMapOverlayButtons() {
    return Positioned(
      right: 12.w,
      bottom: _sheetHeight(context) + 12.h,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOverlayIconButton(
            icon: _isFollowingLocation ? Icons.my_location : Icons.location_searching,
            color: _isFollowingLocation ? AppTheme.primaryColor : Colors.grey[600]!,
            onTap: _moveToMyLocation,
          ),
          SizedBox(height: 8.h),
          ..._buildRadiusButtons(),
        ],
      ),
    );
  }

  List<Widget> _buildRadiusButtons() {
    return List.generate(_radii.length, (i) {
      final selected = _selectedRadiusIndex == i;
      return Padding(
        padding: EdgeInsets.only(bottom: i < _radii.length - 1 ? 4.h : 0),
        child: GestureDetector(
          onTap: () {
            if (_selectedRadiusIndex == i) return;
            setState(() => _selectedRadiusIndex = i);
            if (_mapReady) {
              _suppressCameraMoveEvent = true;
              _mapController!.moveCamera(
                cameraUpdate: CameraUpdate(
                  position: LatLng(
                    latitude: _position?.latitude ?? _defaultLat,
                    longitude: _position?.longitude ?? _defaultLng,
                  ),
                  zoomLevel: _radiusZoomLevels[i],
                  type: -1,
                ),
              );
            }
            _searchCategory(_selectedCategory);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44.w, height: 32.h,
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(8.r),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            alignment: Alignment.center,
            child: Text(
              _radiiLabel[i],
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.secondaryTextColor,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildOverlayIconButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.w, height: 44.w,
        decoration: BoxDecoration(
          color: Colors.white, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, size: 22.w, color: color),
      ),
    );
  }

  // ── 검색 중 인디케이터 ──────────────────────────────────────────────────────

  Widget _buildSearchingIndicator() {
    return Positioned(
      top: 16, left: 0, right: 0,
      child: Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 14.w, height: 14.w,
                child: const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
              SizedBox(width: 10.w),
              Text('검색 중...', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 이 지역 재검색 버튼 ──────────────────────────────────────────────────────

  Widget _buildReSearchButton() {
    return Positioned(
      top: 12, left: 0, right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _reSearchHere,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh, size: 14.w, color: Colors.white),
              SizedBox(width: 6.w),
              Text('이 지역 재검색', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 바텀시트 ──────────────────────────────────────────────────────────────────

  Widget _buildBottomSheet() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: _sheetHeight(context),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              final offset = child.key == const ValueKey('detail')
                  ? const Offset(0.0, 1.0) : const Offset(0.0, -0.2);
              return SlideTransition(
                position: Tween<Offset>(begin: offset, end: Offset.zero)
                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _showDetail && _selectedPlace != null
                ? _buildDetailView(_selectedPlace!, key: const ValueKey('detail'))
                : _buildListView(key: const ValueKey('list')),
          ),
        ),
      ),
    );
  }

  // ── 목록 뷰 ──────────────────────────────────────────────────────────────────

  Widget _buildListView({Key? key}) {
    return Column(
      key: key,
      children: [
        GestureDetector(
          onVerticalDragUpdate: _onSheetDrag,
          onTap: () {
            setState(() {
              _sheetSize = _sheetSize == _SheetSize.full
                  ? _SheetSize.half
                  : _sheetSize == _SheetSize.half
                      ? _SheetSize.full
                      : _SheetSize.half;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 56.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(children: [
              Container(
                width: 36.w, height: 4.h,
                margin: EdgeInsets.only(right: 12.w),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Expanded(
                child: Text(
                  _places.isEmpty
                      ? '${_categories[_selectedCategory].label} 검색 중...'
                      : '${_categories[_selectedCategory].label} ${_places.length}개',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppTheme.primaryTextColor),
                ),
              ),
              if (_places.isNotEmpty) ...[
                Text(_radiiLabel[_selectedRadiusIndex], style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor)),
                Text(' 이내', style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor)),
                SizedBox(width: 8.w),
              ],
              Container(
                width: 28.w, height: 28.w,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _sheetSize == _SheetSize.full ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  size: 18.w, color: AppTheme.primaryColor,
                ),
              ),
            ]),
          ),
        ),
        if (_sheetSize != _SheetSize.collapsed)
          Expanded(
            child: _places.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    controller: _listScrollController,
                    padding: EdgeInsets.only(left: 12.w, right: 12.w, top: 4.h, bottom: 16.h),
                    itemCount: _places.length,
                    separatorBuilder: (_, __) => SizedBox(height: 6.h),
                    itemBuilder: (_, i) => _buildPlaceItem(_places[i], i + 1),
                  ),
          ),
      ],
    );
  }

  // ── 상세 뷰 ──────────────────────────────────────────────────────────────────

  Widget _buildDetailView(HospitalPlace place, {Key? key}) {
    final isFav = _isFavorite(place.id);
    return SingleChildScrollView(
      key: key,
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 6.h, 8.w, 0),
            child: Row(children: [
              GestureDetector(
                onTap: _closeDetail,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  child: Row(children: [
                    Icon(Icons.keyboard_arrow_down, size: 20.w, color: AppTheme.secondaryTextColor),
                    SizedBox(width: 2.w),
                    Text('목록으로', style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
                  ]),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _toggleFavorite(place),
                child: Padding(
                  padding: EdgeInsets.all(8.w),
                  child: Icon(
                    isFav ? Icons.bookmark : Icons.bookmark_border,
                    size: 22.w,
                    color: isFav ? AppTheme.primaryColor : Colors.grey[400],
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(place.name,
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: AppTheme.primaryTextColor)),
              ),
              if (place.distanceM != null) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(_formatDistance(place.distanceM!),
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                ),
              ],
            ]),
          ),
          SizedBox(height: 4.h),
          if (place.category.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(place.category.split('>').last.trim(),
                  style: TextStyle(fontSize: 11.sp, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
              ),
            ),
          SizedBox(height: 8.h),
          if (place.address.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.location_on_outlined, size: 15.w, color: AppTheme.secondaryTextColor),
                SizedBox(width: 5.w),
                Expanded(child: Text(place.address,
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor, height: 1.4))),
              ]),
            ),
          if (place.phone.isNotEmpty) ...[
            SizedBox(height: 3.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(children: [
                Icon(Icons.phone_outlined, size: 15.w, color: AppTheme.secondaryTextColor),
                SizedBox(width: 5.w),
                Text(place.phone, style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
              ]),
            ),
          ],
          SizedBox(height: 12.h),
          // 1행: 전화 + 길찾기
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(children: [
              Expanded(child: _buildActionButton(
                icon: Icons.phone,
                label: '전화',
                color: place.phone.isNotEmpty ? AppTheme.successColor : Colors.grey[400]!,
                onTap: place.phone.isNotEmpty
                    ? () => _callPhone(place.phone)
                    : () => _showSnack('전화번호 정보가 없습니다'),
              )),
              SizedBox(width: 10.w),
              Expanded(child: _buildActionButton(
                icon: Icons.near_me,
                label: '길찾기',
                color: const Color(0xFFE8A000),
                onTap: () => _openKakaoMapDirections(place),
              )),
            ]),
          ),
          SizedBox(height: 8.h),
          // 2행: 리뷰·상세 + 공유
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(children: [
              Expanded(child: _buildActionButton(
                icon: Icons.rate_review_outlined,
                label: '리뷰·상세',
                color: AppTheme.primaryColor,
                onTap: () => _openKakaoMapDetail(place),
              )),
              SizedBox(width: 10.w),
              Expanded(child: _buildActionButton(
                icon: Icons.share_outlined,
                label: '공유',
                color: Colors.grey[600]!,
                onTap: () => _sharePlace(place),
              )),
            ]),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  // ── 검색바 ────────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 4.h),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: _searchByKeyword,
        decoration: InputDecoration(
          hintText: '병원, 시설 이름으로 검색',
          hintStyle: TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor),
          prefixIcon: Icon(Icons.search, size: 20.w, color: AppTheme.secondaryTextColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 18.w),
                  onPressed: () { _searchController.clear(); setState(() {}); },
                )
              : null,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
          filled: true,
          fillColor: AppTheme.primaryColor.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ── 위치 에러 배너 ────────────────────────────────────────────────────────────

  Widget _buildLocationBanner() {
    if (_locationError == null) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFFFFF3F3),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(children: [
        Icon(Icons.location_off, size: 16.w, color: AppTheme.errorColor),
        SizedBox(width: 8.w),
        Expanded(child: Text(_locationError!, style: TextStyle(fontSize: 11.sp, color: AppTheme.errorColor))),
        GestureDetector(
          onTap: _getLocation,
          child: Text('재시도', style: TextStyle(fontSize: 11.sp, color: AppTheme.errorColor, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── 카테고리 바 ───────────────────────────────────────────────────────────────

  Widget _buildCategoryBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 10.h),
      child: Row(
        children: List.generate(_categories.length, (i) {
          final cat = _categories[i];
          final selected = _selectedCategory == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _searchCategory(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(cat.emoji, style: TextStyle(fontSize: 18.sp)),
                  SizedBox(height: 2.h),
                  Text(cat.label,
                    style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppTheme.primaryTextColor),
                    textAlign: TextAlign.center),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 액션 버튼 ──────────────────────────────────────────────────────────────────

  Widget _buildActionButton({
    required IconData icon, required String label,
    required Color color, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(12.r),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15.w, color: Colors.white),
          SizedBox(width: 6.w),
          Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }

  // ── 장소 아이템 ───────────────────────────────────────────────────────────────

  Widget _buildPlaceItem(HospitalPlace place, int index) {
    final isSelected = _selectedPlace?.id == place.id;
    final isFav = _isFavorite(place.id);
    return GestureDetector(
      onTap: () => _selectPlace(place),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(children: [
          Container(
            width: 26.w, height: 26.w,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('$index',
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.primaryColor)),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: 2.h),
              if (place.address.isNotEmpty)
                Text(place.address,
                  style: TextStyle(fontSize: 10.sp, color: AppTheme.secondaryTextColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (place.distanceM != null)
              Text(_formatDistance(place.distanceM!),
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
            SizedBox(height: 2.h),
            GestureDetector(
              onTap: () => _toggleFavorite(place),
              child: Icon(
                isFav ? Icons.bookmark : Icons.bookmark_border,
                size: 16.w,
                color: isFav ? AppTheme.primaryColor : Colors.grey[400],
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── 빈 상태 ───────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    if (_searching) return const SizedBox.shrink();
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🔍', style: TextStyle(fontSize: 36.sp)),
        SizedBox(height: 10.h),
        Text(
          '${_radiiLabel[_selectedRadiusIndex]} 이내에\n${_categories[_selectedCategory].label}이 없어요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor),
        ),
        SizedBox(height: 6.h),
        Text('반경을 넓히거나 다른 지역을 검색해보세요',
          style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
      ]),
    );
  }

  // ── 유틸 ─────────────────────────────────────────────────────────────────────

  // 카테고리 탭 선택 시 무관한 결과(예: 세무회계) 제거
  // 키워드 직접 검색(_searchByKeyword)은 _selectedCategory가 유지되므로 동일하게 적용됨
  bool _isValidCategoryForSelected(String category) {
    const whitelist = <List<String>>[
      ['동물병원', '의원'],           // 0: 동물병원
      ['동물약국'],                    // 1: 동물약국
      ['애견', '반려', '미용', '펫샵', '펫숍'],  // 2: 애견미용
      ['펫호텔', '애견호텔', '반려동물호텔', '반려동물'],  // 3: 펫호텔
    ];
    if (_selectedCategory < 0 || _selectedCategory >= whitelist.length) {
      return true;
    }
    final keywords = whitelist[_selectedCategory];
    return keywords.any((kw) => category.contains(kw));
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters}m';
  }
}
