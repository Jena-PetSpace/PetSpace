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
    _HospitalCategory(emoji: '🐾', label: '동물호텔', query: '동물호텔 펫호텔'),
    _HospitalCategory(emoji: '🦮', label: '반려동물샵', query: '반려동물 용품'),
    _HospitalCategory(emoji: '🌿', label: '자연식품점', query: '강아지 자연식'),
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() { _errorMsg = '위치 서비스를 활성화해주세요'; _loading = false; });
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { _errorMsg = '위치 권한이 거부되었습니다.\n설정에서 허용해주세요.'; _loading = false; });
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

  Future<void> _openMap(_HospitalCategory cat) async {
    String url;
    if (_position != null) {
      final lat = _position!.latitude;
      final lng = _position!.longitude;
      // 카카오맵 앱 → 구글맵 fallback
      final kakaoUrl = 'kakaomap://search?q=${Uri.encodeComponent(cat.query)}&p=$lat,$lng';
      final googleUrl = 'https://www.google.com/maps/search/${Uri.encodeComponent(cat.query)}/@$lat,$lng,15z';
      final kakaoUri = Uri.parse(kakaoUrl);
      if (await canLaunchUrl(kakaoUri)) {
        await launchUrl(kakaoUri);
        return;
      }
      url = googleUrl;
    } else {
      url = 'https://www.google.com/maps/search/${Uri.encodeComponent(cat.query)}';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openNaverMap(String query) async {
    final url = 'nmap://search?query=${Uri.encodeComponent(query)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // 네이버 지도 웹 fallback
      await launchUrl(
        Uri.parse('https://map.naver.com/v5/search/${Uri.encodeComponent(query)}'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('병원/시설 찾기', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // 위치 상태 배너
          _buildLocationBanner(),

          // 카테고리 그리드
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('주변에서 찾기',
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppTheme.primaryTextColor)),
                  SizedBox(height: 12.h),
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

                  // 지도 앱 바로가기
                  Text('지도 앱으로 바로가기',
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppTheme.primaryTextColor)),
                  SizedBox(height: 12.h),
                  Row(children: [
                    Expanded(child: _buildMapAppButton(
                      emoji: '🗺️', label: '구글 지도',
                      onTap: () => _openMap(_categories[0]),
                      color: const Color(0xFF4285F4),
                    )),
                    SizedBox(width: 10.w),
                    Expanded(child: _buildMapAppButton(
                      emoji: '🟢', label: '네이버 지도',
                      onTap: () => _openNaverMap('동물병원'),
                      color: const Color(0xFF03C75A),
                    )),
                    SizedBox(width: 10.w),
                    Expanded(child: _buildMapAppButton(
                      emoji: '🟡', label: '카카오맵',
                      onTap: () => _openMap(_categories[0]),
                      color: const Color(0xFFFFE400),
                      textColor: Colors.black87,
                    )),
                  ]),

                  SizedBox(height: 24.h),
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 18.w, color: AppTheme.primaryColor),
                      SizedBox(width: 10.w),
                      Expanded(child: Text(
                        '카카오맵, 네이버 지도 앱이 설치되어 있으면 앱으로 열립니다.',
                        style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor, height: 1.5),
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

  Widget _buildLocationBanner() {
    if (_loading) {
      return Container(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(children: [
          SizedBox(width: 16.w, height: 16.w, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
          SizedBox(width: 10.w),
          Text('현재 위치를 확인하는 중...', style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryColor)),
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
          Expanded(child: Text(_errorMsg!, style: TextStyle(fontSize: 11.sp, color: AppTheme.errorColor))),
          GestureDetector(
            onTap: _getLocation,
            child: Text('재시도', style: TextStyle(fontSize: 11.sp, color: AppTheme.errorColor, fontWeight: FontWeight.w700)),
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
          Text('현재 위치 기준 검색', style: TextStyle(fontSize: 11.sp, color: AppTheme.successColor, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCategoryCard(_HospitalCategory cat) {
    return GestureDetector(
      onTap: () => _openMap(cat),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(cat.emoji, style: TextStyle(fontSize: 28.sp)),
          SizedBox(height: 6.h),
          Text(cat.label, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppTheme.primaryTextColor)),
        ]),
      ),
    );
  }

  Widget _buildMapAppButton({
    required String emoji, required String label,
    required VoidCallback onTap, required Color color, Color? textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Text(emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(height: 4.h),
          Text(label, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: textColor ?? color)),
        ]),
      ),
    );
  }
}

class _HospitalCategory {
  final String emoji, label, query;
  const _HospitalCategory({required this.emoji, required this.label, required this.query});
}
