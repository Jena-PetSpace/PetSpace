import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/api_config.dart';
import '../../../../shared/themes/app_theme.dart';

class HospitalPlace {
  final String id;
  final String name;
  final String address;
  final String phone;
  final double lat;
  final double lng;
  final String category;
  final int? distanceM;

  const HospitalPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.category,
    this.distanceM,
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
    );
  }

  LatLng get latLng => LatLng(lat, lng);
}

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
  _Category(emoji: '🛒', label: '펫샵', query: '펫샵 반려동물용품'),
];

enum _SheetSize { collapsed, half, full }

class HospitalSearchPage extends StatefulWidget {
  const HospitalSearchPage({super.key});

  @override
  State<HospitalSearchPage> createState() => _HospitalSearchPageState();
}

class _HospitalSearchPageState extends State<HospitalSearchPage> {
  final MapController _mapController = MapController();
  final ScrollController _listScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  static const _defaultCenter = LatLng(37.5665, 126.9780);

  LatLng _mapCenter = _defaultCenter;
  Position? _position;
  String? _locationError;

  bool _mapReady = false;
  bool _searching = false;
  int _selectedCategory = 0;
  List<HospitalPlace> _places = [];
  HospitalPlace? _selectedPlace;

  // 상세 뷰 표시 여부
  bool _showDetail = false;

  _SheetSize _sheetSize = _SheetSize.collapsed;

  double _sheetHeight(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final headerH = 56.h;
    final itemSlotH = 65.h;
    final listPadV = 12.h;
    final separatorH = 6.h;

    // 상세 뷰: 화면 하단 42% 고정
    if (_showDetail) return screenH * 0.42;

    switch (_sheetSize) {
      case _SheetSize.collapsed:
        return headerH;
      case _SheetSize.half:
        return headerH + (itemSlotH * 3) - separatorH + listPadV;
      case _SheetSize.full:
        return screenH - 120.h - MediaQuery.of(context).padding.top;
    }
  }

  @override
  void initState() {
    super.initState();
    _getLocation();
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && _sheetSize != _SheetSize.collapsed) {
        setState(() => _sheetSize = _SheetSize.collapsed);
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _listScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _locationError = null);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
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

      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (mounted) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _position = pos;
          _mapCenter = latLng;
        });
        if (_mapReady) _mapController.move(latLng, 16);
        _searchCategory(_selectedCategory);
      }
    } catch (e) {
      dev.log('위치 오류: $e', name: 'HospitalSearch');
      if (mounted) {
        setState(() => _locationError = '위치를 가져올 수 없습니다');
        _searchCategory(_selectedCategory);
      }
    }
  }

  Future<void> _searchCategory(int index) async {
    _searchFocusNode.unfocus();
    setState(() {
      _selectedCategory = index;
      _searching = true;
      _selectedPlace = null;
      _showDetail = false;
      _places = [];
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
    });
    await _fetchPlaces(keyword.trim());
  }

  Future<void> _fetchPlaces(String query) async {
    final lat = _position?.latitude ?? _defaultCenter.latitude;
    final lng = _position?.longitude ?? _defaultCenter.longitude;

    try {
      final uri = Uri.parse(
        'https://dapi.kakao.com/v2/local/search/keyword.json'
        '?query=${Uri.encodeComponent(query)}'
        '&x=$lng&y=$lat'
        '&radius=5000'
        '&sort=distance'
        '&size=15',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'KakaoAK ${ApiConfig.kakaoRestApiKey}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final documents = (data['documents'] as List<dynamic>? ?? [])
            .map((e) => HospitalPlace.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _places = documents;
            _searching = false;
            if (documents.isNotEmpty) _sheetSize = _SheetSize.half;
          });
        }
      } else {
        dev.log('API 오류: ${response.statusCode}', name: 'HospitalSearch');
        if (mounted) setState(() => _searching = false);
      }
    } catch (e) {
      dev.log('검색 오류: $e', name: 'HospitalSearch');
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openInKakaoMap(HospitalPlace place) async {
    final appUri = Uri.parse('kakaomap://look?p=${place.lat},${place.lng}');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }
    final webUri = Uri.parse(
      'https://map.kakao.com/link/map/${Uri.encodeComponent(place.name)},${place.lat},${place.lng}',
    );
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  void _selectPlace(HospitalPlace place) {
    setState(() {
      _selectedPlace = place;
      _showDetail = true;
      _sheetSize = _SheetSize.full;
    });
    _mapController.move(place.latLng, 17);
  }

  void _closeDetail() {
    setState(() {
      _showDetail = false;
      _sheetSize = _SheetSize.half;
    });
  }

  void _onSheetDrag(DragUpdateDetails details) {
    if (_showDetail) return; // 상세 뷰에선 드래그 비활성
    final delta = details.primaryDelta ?? 0;
    if (delta < -8) {
      if (_sheetSize == _SheetSize.collapsed) {
        setState(() => _sheetSize = _SheetSize.half);
      } else if (_sheetSize == _SheetSize.half) {
        setState(() => _sheetSize = _SheetSize.full);
      }
    } else if (delta > 8) {
      if (_sheetSize == _SheetSize.full) {
        setState(() => _sheetSize = _SheetSize.half);
      } else if (_sheetSize == _SheetSize.half) {
        setState(() => _sheetSize = _SheetSize.collapsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showDetail, // 상세 뷰일 때 기본 pop 막기
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showDetail) _closeDetail();
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

                  if (_searching)
                    Positioned(
                      top: 16, left: 0, right: 0,
                      child: Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              SizedBox(
                                width: 16.w, height: 16.w,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10.w),
                              Text('검색 중...', style: TextStyle(fontSize: 13.sp)),
                            ]),
                          ),
                        ),
                      ),
                    ),

                  // 바텀시트
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      height: _sheetHeight(context),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) {
                            final offset = child.key == const ValueKey('detail')
                                ? const Offset(1.0, 0.0)
                                : const Offset(-1.0, 0.0);
                            return SlideTransition(
                              position: Tween<Offset>(begin: offset, end: Offset.zero)
                                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                              child: child,
                            );
                          },
                          child: _showDetail && _selectedPlace != null
                              ? _buildDetailView(_selectedPlace!, key: const ValueKey('detail'))
                              : _buildListView(key: const ValueKey('list')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ), // PopScope
    );
  }

  // ── 목록 뷰 ───────────────────────────────────────────────────────────────
  Widget _buildListView({Key? key}) {
    return Column(
      key: key,
      children: [
        // 헤더
        GestureDetector(
          onVerticalDragUpdate: _onSheetDrag,
          onTap: () {
            setState(() {
              if (_sheetSize == _SheetSize.collapsed) {
                _sheetSize = _SheetSize.half;
              } else if (_sheetSize == _SheetSize.half) {
                _sheetSize = _SheetSize.full;
              } else {
                _sheetSize = _SheetSize.half;
              }
            });
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 56.h,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(children: [
                // 드래그 핸들
                Container(
                  width: 36.w, height: 4.h,
                  margin: EdgeInsets.only(right: 12.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                Text(
                  _places.isEmpty
                      ? '${_categories[_selectedCategory].label} 검색'
                      : '${_categories[_selectedCategory].label} ${_places.length}개',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const Spacer(),
                if (_places.isNotEmpty)
                  Text('반경 5km',
                      style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor)),
                SizedBox(width: 8.w),
                Container(
                  width: 28.w, height: 28.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _sheetSize == _SheetSize.full
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18.w,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ]),
            ),
          ),
        ),

        // 목록
        if (_sheetSize != _SheetSize.collapsed)
          Expanded(
            child: _places.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    controller: _listScrollController,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    itemCount: _places.length,
                    separatorBuilder: (_, __) => SizedBox(height: 6.h),
                    itemBuilder: (_, i) => _buildPlaceItem(_places[i]),
                  ),
          ),
      ],
    );
  }

  // ── 상세 뷰 ───────────────────────────────────────────────────────────────
  Widget _buildDetailView(HospitalPlace place, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 드래그 핸들 + 뒤로가기 힌트
        GestureDetector(
          onTap: _closeDetail,
          child: Container(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
            child: Row(children: [
              Icon(Icons.keyboard_arrow_down, size: 22.w, color: AppTheme.secondaryTextColor),
              SizedBox(width: 4.w),
              Text('목록으로', style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
            ]),
          ),
        ),

        // 이름 + 거리
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(
                place.name,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: AppTheme.primaryTextColor),
              ),
            ),
            if (place.distanceM != null) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  _formatDistance(place.distanceM!),
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ]),
        ),
        SizedBox(height: 6.h),

        // 카테고리 태그
        if (place.category.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                place.category.split('>').last.trim(),
                style: TextStyle(fontSize: 11.sp, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        SizedBox(height: 10.h),

        // 주소 / 전화
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
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(children: [
              Icon(Icons.phone_outlined, size: 15.w, color: AppTheme.secondaryTextColor),
              SizedBox(width: 5.w),
              Text(place.phone, style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
            ]),
          ),
        ],
        SizedBox(height: 14.h),

        // 액션 버튼
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(children: [
            if (place.phone.isNotEmpty) ...[
              Expanded(child: _buildActionButton(
                icon: Icons.phone,
                label: '전화 연결',
                color: AppTheme.successColor,
                onTap: () => _callPhone(place.phone),
              )),
              SizedBox(width: 10.w),
            ],
            Expanded(child: _buildActionButton(
              icon: Icons.near_me_outlined,
              label: '카카오맵',
              color: const Color(0xFFE8A000),
              onTap: () => _openInKakaoMap(place),
            )),
          ]),
        ),
        const Spacer(),
      ],
    );
  }

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
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
          filled: true,
          fillColor: AppTheme.primaryColor.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: 16,
        onMapReady: () {
          _mapReady = true;
          if (_position != null) {
            _mapController.move(LatLng(_position!.latitude, _position!.longitude), 16);
          }
        },
        onTap: (_, __) {
          if (_showDetail) {
            _closeDetail();
          } else {
            setState(() => _selectedPlace = null);
          }
        },
      ),
      children: [
        TileLayer(
          // OpenStreetMap 기본 타일 — POI(편의점·병원 등) 아이콘 포함
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.petspace.app',
        ),
        if (_position != null)
          MarkerLayer(markers: [
            Marker(
              point: LatLng(_position!.latitude, _position!.longitude),
              width: 22, height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ]),
        MarkerLayer(
          markers: _places.map((place) {
            final isSelected = _selectedPlace?.id == place.id;
            final index = _places.indexOf(place) + 1;
            return Marker(
              point: place.latLng,
              width: isSelected ? 44 : 32,
              height: isSelected ? 44 : 32,
              child: GestureDetector(
                onTap: () => _selectPlace(place),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: isSelected ? 0 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.15),
                        blurRadius: isSelected ? 10 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: isSelected ? 15 : 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationBanner() {
    if (_locationError != null) {
      return Container(
        color: const Color(0xFFFFF3F3),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(children: [
          Icon(Icons.location_off, size: 16.w, color: AppTheme.errorColor),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(_locationError!,
                style: TextStyle(fontSize: 11.sp, color: AppTheme.errorColor)),
          ),
          GestureDetector(
            onTap: _getLocation,
            child: Text('재시도',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

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
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(cat.emoji, style: TextStyle(fontSize: 18.sp)),
                  SizedBox(height: 2.h),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppTheme.primaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15.w, color: Colors.white),
          SizedBox(width: 6.w),
          Text(label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
        ]),
      ),
    );
  }

  Widget _buildPlaceItem(HospitalPlace place) {
    final isSelected = _selectedPlace?.id == place.id;
    final index = _places.indexOf(place) + 1;
    return GestureDetector(
      onTap: () => _selectPlace(place),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 26.w, height: 26.w,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('$index',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                )),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              SizedBox(height: 2.h),
              if (place.address.isNotEmpty)
                Text(place.address,
                    style: TextStyle(fontSize: 10.sp, color: AppTheme.secondaryTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (place.distanceM != null)
              Text(_formatDistance(place.distanceM!),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  )),
            SizedBox(height: 2.h),
            Icon(Icons.chevron_right, size: 16.w, color: AppTheme.secondaryTextColor),
          ]),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searching) return const SizedBox.shrink();
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🔍', style: TextStyle(fontSize: 32.sp)),
        SizedBox(height: 8.h),
        Text('카테고리 선택 또는 검색창에\n직접 입력해서 찾아보세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor)),
      ]),
    );
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters}m';
  }
}
