import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../../../../config/api_config.dart';
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
  LatLng get latLng => LatLng(latitude: lat, longitude: lng);
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

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

  KakaoMapController? _mapCtrl;
  bool _mapReady = false;
  bool _suppressCam = false;
  StreamSubscription<LabelClickEvent>? _labelSub;
  StreamSubscription<CameraMoveEndEvent>? _camSub;

  Position? _position;
  bool _locLoading = true;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  List<_Place> _places = [];
  bool _searching = false;
  String? _error;
  _Place? _selected;
  List<String> _markerIds = [];

  bool _showList = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _labelSub?.cancel();
    _camSub?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locLoading = false);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locLoading = false);
        return;
      }
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 8)),
          );
      if (mounted) setState(() { _position = pos; _locLoading = false; });
    } catch (e) {
      dev.log('위치 오류: $e', name: 'LocationPicker');
      if (mounted) setState(() => _locLoading = false);
    }
  }

  Future<void> _onMapReady(KakaoMapController ctrl) async {
    try {
      await ctrl.addMarkerLayer(layerId: KakaoMapController.defaultLabelLayerId);
      await ctrl.setPoiClickable(isClickable: false);
      await _registerStyles(ctrl);
      _mapReady = true;
      if (_position != null) {
        _suppressCam = true;
        await ctrl.moveCamera(cameraUpdate: CameraUpdate(
          position: LatLng(latitude: _position!.latitude, longitude: _position!.longitude),
          zoomLevel: 15, type: -1,
        ));
        await _addMyLocMarker();
      }
    } catch (e) {
      dev.log('_onMapReady 오류: $e', name: 'LocationPicker');
      _mapReady = true;
    }
  }

  Future<void> _registerStyles(KakaoMapController ctrl) async {
    try {
      Uint8List myBytes, placeBytes;
      try {
        myBytes = (await rootBundle.load('assets/icons/map/my_location_dot.png')).buffer.asUint8List();
        placeBytes = (await rootBundle.load('assets/icons/map/place_marker.png')).buffer.asUint8List();
      } catch (_) {
        return;
      }
      await ctrl.registerMarkerStyles(styles: [
        MarkerStyle(styleId: _myLocStyleId, perLevels: [
          MarkerPerLevelStyle.fromBytes(bytes: myBytes, textStyle: const MarkerTextStyle(
            fontSize: 16, fontColorArgb: 0xFF3478F6, strokeThickness: 2, strokeColorArgb: 0xFFFFFFFF,
          )),
        ]),
        MarkerStyle(styleId: _placeStyleId, perLevels: [
          MarkerPerLevelStyle.fromBytes(bytes: placeBytes, textStyle: const MarkerTextStyle(
            fontSize: 28, fontColorArgb: 0xFFFFFFFF, strokeThickness: 3, strokeColorArgb: 0xFF1E3A5F,
          )),
        ]),
        MarkerStyle(styleId: _selStyleId, perLevels: [
          MarkerPerLevelStyle.fromBytes(bytes: placeBytes, textStyle: const MarkerTextStyle(
            fontSize: 34, fontColorArgb: 0xFFFFFFFF, strokeThickness: 4, strokeColorArgb: 0xFFFF4C2C,
          )),
        ]),
      ]);
    } catch (e) {
      dev.log('registerStyles 오류: $e', name: 'LocationPicker');
    }
  }

  Future<void> _addMyLocMarker() async {
    if (_mapCtrl == null || !_mapReady || _position == null) return;
    try {
      await _mapCtrl!.removeMarker(id: _myLocMarkerId);
    } catch (_) {}
    try {
      await _mapCtrl!.addMarker(markerOption: MarkerOption(
        id: _myLocMarkerId,
        latLng: LatLng(latitude: _position!.latitude, longitude: _position!.longitude),
        styleId: _myLocStyleId, text: '내 위치', rank: 999,
      ));
    } catch (e) {
      dev.log('내위치마커 오류: $e', name: 'LocationPicker');
    }
  }

  Future<void> _updateMarkers() async {
    if (_mapCtrl == null || !_mapReady) return;
    if (_markerIds.isNotEmpty) {
      try { await _mapCtrl!.removeMarkers(ids: _markerIds); } catch (_) {}
    }
    try { await _mapCtrl!.removeMarker(id: _myLocMarkerId); } catch (_) {}

    final opts = _places.asMap().entries.map((e) => MarkerOption(
      id: e.value.id, latLng: e.value.latLng,
      styleId: _selected?.id == e.value.id ? _selStyleId : _placeStyleId,
      text: '${e.key + 1}', rank: 100,
    )).toList();

    if (opts.isNotEmpty) {
      try {
        await _mapCtrl!.addMarkers(markerOptions: opts);
        _markerIds = _places.map((p) => p.id).toList();
      } catch (e) {
        dev.log('addMarkers 오류: $e', name: 'LocationPicker');
        _markerIds = [];
      }
    } else {
      _markerIds = [];
    }
    await _addMyLocMarker();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _places = []; _error = null; _selected = null; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q.trim()));
  }

  Future<void> _search(String query) async {
    setState(() { _searching = true; _error = null; _selected = null; _showList = true; });
    try {
      final lat = _position?.latitude ?? _defaultLat;
      final lng = _position?.longitude ?? _defaultLng;
      final uri = Uri.parse(
        'https://dapi.kakao.com/v2/local/search/keyword.json'
        '?query=${Uri.encodeComponent(query)}'
        '&x=$lng&y=$lat&sort=distance&size=15',
      );
      final res = await http.get(uri, headers: {'Authorization': 'KakaoAK ${ApiConfig.kakaoRestApiKey}'})
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final docs = (jsonDecode(res.body)['documents'] as List<dynamic>);
        final places = docs.map((d) => _Place(
          id: d['id'] as String? ?? UniqueKey().toString(),
          name: d['place_name'] as String? ?? '',
          address: (d['road_address_name'] as String?)?.isNotEmpty == true
              ? d['road_address_name'] as String
              : d['address_name'] as String? ?? '',
          lat: double.tryParse(d['y'] as String? ?? '') ?? 0,
          lng: double.tryParse(d['x'] as String? ?? '') ?? 0,
        )).toList();
        setState(() { _places = places; _searching = false; });
        await _updateMarkers();
        if (places.isNotEmpty && _mapReady) {
          _suppressCam = true;
          await _mapCtrl?.moveCamera(cameraUpdate: CameraUpdate(
            position: places.first.latLng, zoomLevel: 14, type: -1,
          ));
        }
      } else {
        setState(() { _error = '검색 실패 (${res.statusCode})'; _searching = false; });
      }
    } on TimeoutException {
      if (mounted) setState(() { _error = '요청 시간 초과'; _searching = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '검색 오류'; _searching = false; });
    }
  }

  Future<void> _selectPlace(_Place place) async {
    setState(() => _selected = place);
    await _updateMarkers();
    if (_mapReady) {
      _suppressCam = true;
      await _mapCtrl?.moveCamera(cameraUpdate: CameraUpdate(
        position: place.latLng, zoomLevel: 16, type: -1,
      ));
    }
  }

  void _confirm(_Place place) {
    Navigator.of(context).pop(LocationPickResult(
      name: place.name,
      address: place.address,
      lat: place.lat,
      lng: place.lng,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('위치 추가', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56.h),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) { if (v.trim().isNotEmpty) _search(v.trim()); },
              decoration: InputDecoration(
                hintText: '장소명 또는 주소 검색...',
                hintStyle: TextStyle(fontSize: 14.sp, color: AppTheme.hintColor),
                prefixIcon: const Icon(Icons.search, color: AppTheme.hintColor, size: 20),
                suffixIcon: _searching
                    ? Padding(
                        padding: EdgeInsets.all(12.w),
                        child: SizedBox(
                          width: 16.w, height: 16.w,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                        ),
                      )
                    : _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppTheme.hintColor),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() { _places = []; _error = null; _selected = null; _showList = false; });
                            },
                          )
                        : null,
                filled: true,
                fillColor: AppTheme.subtleBackground,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.r),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 지도
          _locLoading
              ? Container(color: Colors.grey[100], child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)))
              : KakaoMap(
                  initialPosition: _position != null
                      ? LatLng(latitude: _position!.latitude, longitude: _position!.longitude)
                      : const LatLng(latitude: _defaultLat, longitude: _defaultLng),
                  onMapCreated: (ctrl) {
                    _mapCtrl = ctrl;
                    _labelSub = ctrl.onLabelClickedStream.listen((e) {
                      final place = _places.firstWhere(
                        (p) => p.id == e.labelId,
                        orElse: () => const _Place(id: '', name: '', address: '', lat: 0, lng: 0),
                      );
                      if (place.id.isNotEmpty && mounted) _selectPlace(place);
                    });
                    _camSub = ctrl.onCameraMoveEndStream.listen((e) {
                      if (!mounted) return;
                      if (_suppressCam) { _suppressCam = false; return; }
                    });
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted) _onMapReady(ctrl);
                    });
                  },
                ),
          // 내 위치 버튼
          Positioned(
            right: 12.w,
            bottom: _showList ? 280.h : 20.h,
            child: FloatingActionButton.small(
              heroTag: 'loc_btn',
              backgroundColor: Colors.white,
              elevation: 2,
              onPressed: () async {
                if (_position == null) { await _getLocation(); return; }
                if (!_mapReady) return;
                _suppressCam = true;
                await _mapCtrl?.moveCamera(cameraUpdate: CameraUpdate(
                  position: LatLng(latitude: _position!.latitude, longitude: _position!.longitude),
                  zoomLevel: 15, type: -1,
                ));
              },
              child: const Icon(Icons.my_location_rounded, color: AppTheme.primaryColor, size: 20),
            ),
          ),
          // 결과 목록 바텀시트
          if (_showList)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildResultSheet(),
            ),
        ],
      ),
    );
  }

  Widget _buildResultSheet() {
    return Container(
      height: 270.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Column(
        children: [
          SizedBox(height: 8.h),
          Container(width: 36.w, height: 4.h, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.r))),
          SizedBox(height: 8.h),
          if (_error != null)
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(_error!, style: TextStyle(fontSize: 13.sp, color: AppTheme.errorColor)),
            )
          else if (!_searching && _places.isEmpty)
            Padding(
              padding: EdgeInsets.all(24.w),
              child: Text('검색 결과가 없습니다.', style: TextStyle(fontSize: 14.sp, color: AppTheme.secondaryTextColor)),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _places.length,
                itemBuilder: (_, i) => _buildTile(_places[i], i + 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTile(_Place place, int num) {
    final isSelected = _selected?.id == place.id;
    return InkWell(
      onTap: () => _selectPlace(place),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: isSelected
            ? BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.06))
            : null,
        child: Row(
          children: [
            Container(
              width: 28.w, height: 28.w,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : AppTheme.subtleBackground,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$num', style: TextStyle(
                  fontSize: 12.sp, fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppTheme.secondaryTextColor,
                )),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                  if (place.address.isNotEmpty)
                    Text(place.address, style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
                ],
              ),
            ),
            if (isSelected)
              TextButton(
                onPressed: () => _confirm(place),
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                ),
                child: Text('선택', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}
