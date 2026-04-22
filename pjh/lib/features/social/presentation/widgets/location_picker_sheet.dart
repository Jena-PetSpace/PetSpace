import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

class LocationResult {
  final String name;
  final double lat;
  final double lng;

  const LocationResult({
    required this.name,
    required this.lat,
    required this.lng,
  });
}

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  static Future<LocationResult?> show(BuildContext context) {
    return showModalBottomSheet<LocationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, ctrl) => const LocationPickerSheet(),
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _searchController = TextEditingController();
  final List<_PlaceItem> _results = [];
  // ignore: prefer_final_fields
  bool _searching = false;

  // 자주 쓰는 장소 프리셋
  static const _presets = [
    _PlaceItem('집', 37.5665, 126.9780),
    _PlaceItem('회사', 37.5700, 126.9836),
    _PlaceItem('동네 공원', 37.5740, 126.9768),
    _PlaceItem('카페', 37.5563, 126.9723),
    _PlaceItem('동물병원', 37.5621, 126.9842),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _results.clear());
      return;
    }
    // 실제 구현 시 Places API 호출 — 현재는 프리셋 필터로 대체
    final filtered = _presets
        .where((p) => p.name.contains(query))
        .toList();
    setState(() => _results
      ..clear()
      ..addAll(filtered));
  }

  void _select(_PlaceItem place) {
    Navigator.pop(
      context,
      LocationResult(name: place.name, lat: place.lat, lng: place.lng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: EdgeInsets.symmetric(vertical: 12.h),
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              '위치 추가',
              style: TextStyle(
                  fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '장소 검색...',
                hintStyle:
                    TextStyle(fontSize: 14.sp, color: AppTheme.hintColor),
                prefixIcon: const Icon(Icons.search, color: AppTheme.hintColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide:
                        const BorderSide(color: AppTheme.dividerColor)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide:
                        const BorderSide(color: AppTheme.dividerColor)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide:
                        const BorderSide(color: AppTheme.primaryColor)),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                if (_searching)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator())),
                if (!_searching && _results.isNotEmpty)
                  ..._results.map((p) => _buildTile(p)),
                if (!_searching && _results.isEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(top: 8.h, bottom: 4.h),
                    child: Text('자주 쓰는 장소',
                        style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.secondaryTextColor,
                            fontWeight: FontWeight.w600)),
                  ),
                  ..._presets.map((p) => _buildTile(p)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(_PlaceItem place) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      leading: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.location_on,
            size: 18.w, color: AppTheme.primaryColor),
      ),
      title: Text(place.name,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500)),
      subtitle: Text(
          '${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)}',
          style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor)),
      onTap: () => _select(place),
    );
  }
}

class _PlaceItem {
  final String name;
  final double lat;
  final double lng;

  const _PlaceItem(this.name, this.lat, this.lng);
}
