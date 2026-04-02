import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/themes/app_theme.dart';

class HospitalSearchPage extends StatefulWidget {
  const HospitalSearchPage({super.key});

  @override
  State<HospitalSearchPage> createState() => _HospitalSearchPageState();
}

class _HospitalSearchPageState extends State<HospitalSearchPage> {
  bool _loading = false;
  String? _errorMsg;
  Position? _position;

  static const _categories = [
    _HospitalCategory(emoji: '🏥', label: '동물병원', query: '동물병원'),
    _HospitalCategory(emoji: '💊', label: '동물약국', query: '동물약국'),
    _HospitalCategory(emoji: '🛁', label: '애견미용', query: '애견미용'),
    _HospitalCategory(emoji: '🐾', label: '펫호텔', query: '펫호텔 동물호텔'),
    _HospitalCategory(emoji: '🦮', label: '반려동물샵', query: '반려동물 용품'),
    _HospitalCategory(emoji: '🌿', label: '자연식품점', query: '강아지 자연식'),
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  // ── 위치 권한 + 현재 위치 획득 ─────────────────────────
  Future<void> _getLocation() async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() { _errorMsg = '위치 서비스를 켜주세요'; _loading = false; });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { _errorMsg = '설정에서 위치 권한을 허용해주세요'; _loading = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) setState(() { _position = pos; _loading = false; });
    } catch (e) {
      dev.log('위치 오류: $e', name: 'HospitalSearch');
      if (mounted) setState(() { _errorMsg = '위치를 가져올 수 없습니다'; _loading = false; });
    }
  }

  // ── 카카오맵 딥링크 (메인) ──────────────────────────────
  // 앱 설치 여부와 상관없이 가장 풍부한 국내 POI 데이터 활용
  Future<void> _openKakaoMap(String query) async {
    final encodedQuery = Uri.encodeComponent(query);

    // 1순위: 카카오맵 앱 딥링크 (위치 포함)
    if (_position != null) {
      final lat = _position!.latitude;
      final lng = _position!.longitude;
      final appUri = Uri.parse('kakaomap://search?q=$encodedQuery&p=$lat,$lng');
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri);
        return;
      }
    } else {
      // 위치 없이 키워드만으로 앱 딥링크
      final appUri = Uri.parse('kakaomap://search?q=$encodedQuery');
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri);
        return;
      }
    }

    // 2순위: 카카오맵 웹 (앱 미설치 시)
    final webUri = _position != null
        ? Uri.parse(
            'https://map.kakao.com/?q=$encodedQuery'
            '&urlX=${_lngToKakaoX(_position!.longitude)}'
            '&urlY=${_latToKakaoY(_position!.latitude)}'
            '&urlLevel=4',
          )
        : Uri.parse('https://map.kakao.com/?q=$encodedQuery');

    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }

    // 3순위: 구글맵 최종 fallback
    await _openGoogleMap(query);
  }

  // ── 구글맵 fallback ─────────────────────────────────────
  Future<void> _openGoogleMap(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final Uri uri;
    if (_position != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/$encodedQuery/'
        '@${_position!.latitude},${_position!.longitude},15z',
      );
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/$encodedQuery');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // 카카오맵 좌표 변환 (대략값 — 정확도는 낮지만 화면 이동에 충분)
  int _lngToKakaoX(double lng) => (lng * 100000 + 14684300).round();
  int _latToKakaoY(double lat) => (lat * 100000 + 4372000).round();

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
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카카오맵 안내 배너
                  _buildKakaoBanner(),
                  SizedBox(height: 20.h),

                  Text('주변에서 찾기',
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700,
                        color: AppTheme.primaryTextColor)),
                  SizedBox(height: 12.h),

                  // 카테고리 그리드
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10.w,
                      mainAxisSpacing: 10.h,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (_, i) => _buildCategoryCard(_categories[i]),
                  ),
                  SizedBox(height: 24.h),

                  // 바로가기 버튼 2개
                  Text('지도 앱으로 바로가기',
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700,
                        color: AppTheme.primaryTextColor)),
                  SizedBox(height: 12.h),
                  Row(children: [
                    Expanded(child: _buildMapButton(
                      emoji: '🗺️',
                      label: '카카오맵',
                      sublabel: '추천',
                      color: const Color(0xFFFFE400),
                      textColor: Colors.black87,
                      onTap: () => _openKakaoMap('동물병원'),
                    )),
                    SizedBox(width: 12.w),
                    Expanded(child: _buildMapButton(
                      emoji: '🌏',
                      label: '구글 지도',
                      sublabel: 'Fallback',
                      color: const Color(0xFF4285F4),
                      textColor: Colors.white,
                      onTap: () => _openGoogleMap('동물병원'),
                    )),
                  ]),
                  SizedBox(height: 16.h),

                  // 안내
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Icon(Icons.info_outline, size: 18.w, color: AppTheme.primaryColor),
                      SizedBox(width: 10.w),
                      Expanded(child: Text(
                        '카카오맵이 국내 동물병원 데이터가 가장 풍부합니다.\n'
                        '카카오맵 앱이 없으면 웹으로 자동 연결돼요.',
                        style: TextStyle(fontSize: 11.sp,
                            color: AppTheme.secondaryTextColor, height: 1.5),
                      )),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKakaoBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE400).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFFFE400), width: 1.5),
      ),
      child: Row(children: [
        Text('🗺️', style: TextStyle(fontSize: 22.sp)),
        SizedBox(width: 12.w),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('카카오맵 연동',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700,
                color: const Color(0xFF8B7000))),
          Text(
            '카테고리 선택 → 카카오맵 앱으로 바로 검색',
            style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor),
          ),
        ])),
      ]),
    );
  }

  Widget _buildLocationBanner() {
    if (_loading) {
      return Container(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(children: [
          SizedBox(width: 16.w, height: 16.w,
              child: const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
          SizedBox(width: 10.w),
          Text('현재 위치 확인 중...',
              style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryColor)),
        ]),
      );
    }
    if (_errorMsg != null) {
      return Container(
        color: const Color(0xFFFFF3F3),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(children: [
          Icon(Icons.location_off, size: 18.w, color: AppTheme.errorColor),
          SizedBox(width: 10.w),
          Expanded(child: Text(_errorMsg!,
              style: TextStyle(fontSize: 11.sp, color: AppTheme.errorColor))),
          GestureDetector(
            onTap: _getLocation,
            child: Text('재시도',
                style: TextStyle(fontSize: 11.sp, color: AppTheme.errorColor,
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
              style: TextStyle(fontSize: 11.sp, color: AppTheme.successColor,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCategoryCard(_HospitalCategory cat) {
    return GestureDetector(
      onTap: () => _openKakaoMap(cat.query),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(cat.emoji, style: TextStyle(fontSize: 28.sp)),
          SizedBox(height: 6.h),
          Text(cat.label,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600,
                  color: AppTheme.primaryTextColor)),
        ]),
      ),
    );
  }

  Widget _buildMapButton({
    required String emoji,
    required String label,
    required String sublabel,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(children: [
          Text(emoji, style: TextStyle(fontSize: 24.sp)),
          SizedBox(height: 4.h),
          Text(label,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700,
                  color: color == const Color(0xFFFFE400)
                      ? const Color(0xFF8B7000) : color)),
          Text(sublabel,
              style: TextStyle(fontSize: 9.sp, color: AppTheme.secondaryTextColor)),
        ]),
      ),
    );
  }
}

class _HospitalCategory {
  final String emoji, label, query;
  const _HospitalCategory(
      {required this.emoji, required this.label, required this.query});
}
