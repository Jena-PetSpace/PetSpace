import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../config/api_config.dart';
import '../../../../shared/themes/app_theme.dart';

// ── 데이터 모델 ──────────────────────────────────────────
class HospitalPlace {
  final String id;
  final String name;
  final String address;
  final String phone;
  final double lat;
  final double lng;
  final String category;
  final String? distance;

  const HospitalPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.category,
    this.distance,
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
      distance: json['distance'] as String?,
    );
  }
}

// ── 카테고리 정의 ─────────────────────────────────────────
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
  _Category(emoji: '🐾', label: '펫호텔', query: '펫호텔'),
  _Category(emoji: '🛒', label: '펫샵', query: '반려동물용품'),
];

// ── 메인 페이지 ───────────────────────────────────────────
class HospitalSearchPage extends StatefulWidget {
  const HospitalSearchPage({super.key});

  @override
  State<HospitalSearchPage> createState() => _HospitalSearchPageState();
}

class _HospitalSearchPageState extends State<HospitalSearchPage> {
  late final WebViewController _webViewController;

  Position? _position;
  bool _locationLoading = true;
  String? _locationError;

  bool _mapReady = false;
  bool _searching = false;

  int _selectedCategory = 0;
  List<HospitalPlace> _places = [];
  HospitalPlace? _selectedPlace;

  // DraggableScrollableSheet 높이 제어
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _initWebView();
    _getLocation();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  // ── WebView 초기화 ────────────────────────────────────
  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: _onJsMessage,
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          dev.log('WebView page finished', name: 'HospitalSearch');
        },
        onWebResourceError: (error) {
          dev.log('WebView error: ${error.description}', name: 'HospitalSearch');
        },
      ))
      ..loadHtmlString(_buildMapHtml());
  }

  // ── JS → Flutter 메시지 수신 ──────────────────────────
  void _onJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'mapReady':
          setState(() => _mapReady = true);
          // 지도 준비되면 위치 있으면 바로 검색
          if (_position != null) {
            _searchCategory(_selectedCategory);
          }
          break;

        case 'searchResult':
          final items = (data['places'] as List<dynamic>? ?? [])
              .map((e) => HospitalPlace.fromJson(e as Map<String, dynamic>))
              .toList();
          setState(() {
            _places = items;
            _searching = false;
          });
          // 결과 있으면 바텀시트 올리기
          if (items.isNotEmpty) {
            _sheetController.animateTo(
              0.4,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
          break;

        case 'markerTap':
          final placeId = data['id'] as String?;
          if (placeId != null) {
            final place = _places.firstWhere(
              (p) => p.id == placeId,
              orElse: () => _places.first,
            );
            setState(() => _selectedPlace = place);
          }
          break;
      }
    } catch (e) {
      dev.log('JS message parse error: $e', name: 'HospitalSearch');
    }
  }

  // ── 위치 권한 + 현재 위치 ─────────────────────────────
  Future<void> _getLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          setState(() {
            _locationError = '위치 서비스를 켜주세요';
            _locationLoading = false;
          });
        }
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationError = '설정에서 위치 권한을 허용해주세요';
            _locationLoading = false;
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        setState(() {
          _position = pos;
          _locationLoading = false;
        });
        // 지도가 이미 준비됐으면 바로 이동 + 검색
        if (_mapReady) {
          _moveMapToPosition(pos);
          _searchCategory(_selectedCategory);
        }
      }
    } catch (e) {
      dev.log('위치 오류: $e', name: 'HospitalSearch');
      if (mounted) {
        setState(() {
          _locationError = '위치를 가져올 수 없습니다';
          _locationLoading = false;
        });
      }
    }
  }

  // ── 지도 중심 이동 (JS 호출) ──────────────────────────
  void _moveMapToPosition(Position pos) {
    _webViewController.runJavaScript(
      'moveToPosition(${pos.latitude}, ${pos.longitude});',
    );
  }

  // ── 카테고리 검색 ─────────────────────────────────────
  void _searchCategory(int index) {
    if (!_mapReady) return;

    setState(() {
      _selectedCategory = index;
      _searching = true;
      _selectedPlace = null;
      _places = [];
    });

    final cat = _categories[index];
    final lat = _position?.latitude ?? 37.5665; // 서울 중심 fallback
    final lng = _position?.longitude ?? 126.9780;

    _webViewController.runJavaScript(
      'searchPlaces(${jsonEncode(cat.query)}, $lat, $lng);',
    );
  }

  // ── 전화 걸기 ─────────────────────────────────────────
  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ── 카카오맵 앱으로 길찾기 ────────────────────────────
  Future<void> _openInKakaoMap(HospitalPlace place) async {
    final appUri = Uri.parse(
      'kakaomap://look?p=${place.lat},${place.lng}',
    );
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

  // ── HTML 빌드 ─────────────────────────────────────────
  String _buildMapHtml() {
    final jsKey = ApiConfig.kakaoJsKey;
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; }
    #map { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script type="text/javascript"
    src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=$jsKey&libraries=services">
  </script>
  <script>
    var map;
    var ps;
    var markers = [];
    var infowindow;

    kakao.maps.load(function() {
      var container = document.getElementById('map');
      var options = {
        center: new kakao.maps.LatLng(37.5665, 126.9780),
        level: 5
      };
      map = new kakao.maps.Map(container, options);
      ps = new kakao.maps.services.Places();
      infowindow = new kakao.maps.InfoWindow({ zIndex: 1 });

      FlutterChannel.postMessage(JSON.stringify({ type: 'mapReady' }));
    });

    function moveToPosition(lat, lng) {
      if (!map) return;
      var pos = new kakao.maps.LatLng(lat, lng);
      map.setCenter(pos);
      map.setLevel(5);
    }

    function searchPlaces(keyword, lat, lng) {
      if (!ps) return;
      clearMarkers();

      var options = {
        location: new kakao.maps.LatLng(lat, lng),
        radius: 3000,
        sort: kakao.maps.services.SortBy.DISTANCE
      };

      ps.keywordSearch(keyword, function(data, status) {
        if (status === kakao.maps.services.Status.OK) {
          var places = data.map(function(p) {
            return {
              id: p.id,
              place_name: p.place_name,
              road_address_name: p.road_address_name,
              address_name: p.address_name,
              phone: p.phone,
              x: p.x,
              y: p.y,
              category_name: p.category_name,
              distance: p.distance
            };
          });
          displayMarkers(data);
          FlutterChannel.postMessage(JSON.stringify({
            type: 'searchResult',
            places: places
          }));
        } else {
          FlutterChannel.postMessage(JSON.stringify({
            type: 'searchResult',
            places: []
          }));
        }
      }, options);
    }

    function displayMarkers(places) {
      clearMarkers();
      var bounds = new kakao.maps.LatLngBounds();

      places.forEach(function(place) {
        var pos = new kakao.maps.LatLng(place.y, place.x);
        var marker = new kakao.maps.Marker({ map: map, position: pos });
        markers.push(marker);
        bounds.extend(pos);

        (function(m, p) {
          kakao.maps.event.addListener(m, 'click', function() {
            infowindow.setContent('<div style="padding:5px;font-size:12px;">' + p.place_name + '</div>');
            infowindow.open(map, m);
            FlutterChannel.postMessage(JSON.stringify({ type: 'markerTap', id: p.id }));
          });
        })(marker, place);
      });

      if (places.length > 0) {
        map.setBounds(bounds);
      }
    }

    function clearMarkers() {
      infowindow && infowindow.close();
      markers.forEach(function(m) { m.setMap(null); });
      markers = [];
    }
  </script>
</body>
</html>
''';
  }

  // ── UI 빌드 ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('병원/시설 찾기',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          _buildLocationBanner(),
          _buildCategoryBar(),
          Expanded(
            child: Stack(
              children: [
                // 지도
                WebViewWidget(controller: _webViewController),

                // 검색 중 오버레이
                if (_searching)
                  const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('검색 중...', style: TextStyle(fontSize: 13)),
                        ]),
                      ),
                    ),
                  ),

                // JS 키 미설정 안내
                if (!ApiConfig.isKakaoJsConfigured)
                  _buildJsKeyNotice(),

                // 바텀시트
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: 0.08,
                  minChildSize: 0.08,
                  maxChildSize: 0.85,
                  snap: true,
                  snapSizes: const [0.08, 0.4, 0.85],
                  builder: (context, scrollController) {
                    return _buildBottomSheet(scrollController);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBanner() {
    if (_locationLoading) {
      return Container(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(children: [
          SizedBox(
            width: 16.w,
            height: 16.w,
            child: const CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primaryColor),
          ),
          SizedBox(width: 10.w),
          Text('현재 위치 확인 중...',
              style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryColor)),
        ]),
      );
    }
    if (_locationError != null) {
      return Container(
        color: const Color(0xFFFFF3F3),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(children: [
          Icon(Icons.location_off, size: 18.w, color: AppTheme.errorColor),
          SizedBox(width: 10.w),
          Expanded(
              child: Text(_locationError!,
                  style: TextStyle(
                      fontSize: 11.sp, color: AppTheme.errorColor))),
          GestureDetector(
            onTap: _getLocation,
            child: Text('재시도',
                style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );
    }
    if (_position != null) {
      return Container(
        color: AppTheme.successColor.withValues(alpha: 0.06),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(children: [
          Icon(Icons.location_on, size: 16.w, color: AppTheme.successColor),
          SizedBox(width: 6.w),
          Text('현재 위치 기준으로 검색합니다',
              style: TextStyle(
                  fontSize: 11.sp,
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCategoryBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.emoji,
                        style: TextStyle(fontSize: 18.sp)),
                    SizedBox(height: 2.h),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : AppTheme.primaryTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomSheet(ScrollController scrollController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Column(
        children: [
          // 핸들
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 10.h, bottom: 8.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // 헤더
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Text(
                  _places.isEmpty
                      ? '${_categories[_selectedCategory].label} 검색'
                      : '${_categories[_selectedCategory].label} ${_places.length}개',
                  style: TextStyle(
                      fontSize: 14.sp, fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTextColor),
                ),
                const Spacer(),
                if (_places.isNotEmpty)
                  Text('반경 3km',
                      style: TextStyle(
                          fontSize: 11.sp,
                          color: AppTheme.secondaryTextColor)),
              ],
            ),
          ),

          SizedBox(height: 8.h),

          // 선택된 장소 상세 카드
          if (_selectedPlace != null)
            _buildSelectedPlaceCard(_selectedPlace!),

          // 목록
          Expanded(
            child: _places.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 8.h),
                    itemCount: _places.length,
                    separatorBuilder: (_, __) => SizedBox(height: 6.h),
                    itemBuilder: (_, i) => _buildPlaceItem(_places[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPlaceCard(HospitalPlace place) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(place.name,
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTextColor)),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedPlace = null),
              child: Icon(Icons.close, size: 18.w,
                  color: AppTheme.secondaryTextColor),
            ),
          ]),
          if (place.address.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(place.address,
                style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.secondaryTextColor)),
          ],
          SizedBox(height: 10.h),
          Row(children: [
            if (place.phone.isNotEmpty)
              Expanded(
                child: _buildDetailButton(
                  icon: Icons.phone,
                  label: '전화',
                  color: AppTheme.successColor,
                  onTap: () => _callPhone(place.phone),
                ),
              ),
            if (place.phone.isNotEmpty) SizedBox(width: 8.w),
            Expanded(
              child: _buildDetailButton(
                icon: Icons.map,
                label: '지도 앱',
                color: const Color(0xFFFFE400),
                onTap: () => _openInKakaoMap(place),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildDetailButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = color == const Color(0xFFFFE400);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.9 : 0.12),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 15.w,
              color: isDark ? Colors.black87 : color),
          SizedBox(width: 4.w),
          Text(label,
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.black87 : color)),
        ]),
      ),
    );
  }

  Widget _buildPlaceItem(HospitalPlace place) {
    final isSelected = _selectedPlace?.id == place.id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPlace = place);
        // 지도 마커로 이동
        _webViewController.runJavaScript(
          'moveToPosition(${place.lat}, ${place.lng});',
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          // 번호 배지
          Container(
            width: 26.w,
            height: 26.w,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${_places.indexOf(place) + 1}',
              style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppTheme.primaryColor),
            ),
          ),
          SizedBox(width: 10.w),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name,
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTextColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 2.h),
                if (place.address.isNotEmpty)
                  Text(place.address,
                      style: TextStyle(
                          fontSize: 10.sp,
                          color: AppTheme.secondaryTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          // 거리 + 전화 버튼
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (place.distance != null)
                Text(
                  _formatDistance(place.distance!),
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor),
                ),
              if (place.phone.isNotEmpty) ...[
                SizedBox(height: 4.h),
                GestureDetector(
                  onTap: () => _callPhone(place.phone),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.phone,
                          size: 11.w, color: AppTheme.successColor),
                      SizedBox(width: 3.w),
                      Text('전화',
                          style: TextStyle(
                              fontSize: 10.sp,
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searching) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔍', style: TextStyle(fontSize: 32.sp)),
          SizedBox(height: 8.h),
          Text(
            '카테고리를 선택하면\n주변 시설을 찾아드려요',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.sp, color: AppTheme.secondaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildJsKeyNotice() {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
          ],
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kakao JS API 키를 secrets.dart에 설정해주세요',
              style: TextStyle(fontSize: 11.sp, color: Colors.orange[800]),
            ),
          ),
        ]),
      ),
    );
  }

  String _formatDistance(String distance) {
    final meters = int.tryParse(distance) ?? 0;
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters}m';
  }
}
