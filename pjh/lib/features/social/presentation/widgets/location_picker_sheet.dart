import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import '../../../../config/api_config.dart';
import '../../../../shared/themes/app_theme.dart';

class LocationResult {
  final String name;
  final String address;
  final double lat;
  final double lng;

  const LocationResult({
    required this.name,
    required this.address,
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
  bool _searching = false;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results.clear();
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('https://dapi.kakao.com/v2/local/search/keyword.json')
          .replace(queryParameters: {'query': query, 'size': '15'});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'KakaoAK ${ApiConfig.kakaoRestApiKey}'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final documents = data['documents'] as List<dynamic>;
        final items = documents.map((d) {
          return _PlaceItem(
            name: d['place_name'] as String,
            address: (d['road_address_name'] as String?)?.isNotEmpty == true
                ? d['road_address_name'] as String
                : d['address_name'] as String? ?? '',
            lat: double.tryParse(d['y'] as String? ?? '') ?? 0.0,
            lng: double.tryParse(d['x'] as String? ?? '') ?? 0.0,
          );
        }).toList();
        setState(() {
          _results
            ..clear()
            ..addAll(items);
          _searching = false;
        });
      } else {
        setState(() {
          _error = '검색에 실패했습니다 (${response.statusCode})';
          _searching = false;
        });
      }
    } on TimeoutException {
      if (mounted) setState(() { _error = '요청 시간이 초과되었습니다.'; _searching = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '검색 중 오류가 발생했습니다.'; _searching = false; });
    }
  }

  void _select(_PlaceItem place) {
    Navigator.pop(
      context,
      LocationResult(
        name: place.name,
        address: place.address,
        lat: place.lat,
        lng: place.lng,
      ),
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
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
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
                hintText: '장소명 또는 주소 검색...',
                hintStyle: TextStyle(fontSize: 14.sp, color: AppTheme.hintColor),
                prefixIcon: const Icon(Icons.search, color: AppTheme.hintColor),
                suffixIcon: _searching
                    ? Padding(
                        padding: EdgeInsets.all(12.w),
                        child: SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primaryColor),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppTheme.dividerColor)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppTheme.dividerColor)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppTheme.primaryColor)),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: AppTheme.errorColor)),
        ),
      );
    }

    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48.w, color: AppTheme.hintColor),
            SizedBox(height: 12.h),
            Text('장소를 검색해주세요',
                style: TextStyle(
                    fontSize: 14.sp, color: AppTheme.secondaryTextColor)),
          ],
        ),
      );
    }

    if (!_searching && _results.isEmpty) {
      return Center(
        child: Text('검색 결과가 없습니다.',
            style: TextStyle(
                fontSize: 14.sp, color: AppTheme.secondaryTextColor)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      itemCount: _results.length,
      itemBuilder: (_, i) => _buildTile(_results[i]),
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
        child: Icon(Icons.location_on, size: 18.w, color: AppTheme.primaryColor),
      ),
      title: Text(place.name,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500)),
      subtitle: Text(place.address,
          style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor)),
      onTap: () => _select(place),
    );
  }
}

class _PlaceItem {
  final String name;
  final String address;
  final double lat;
  final double lng;

  const _PlaceItem({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}
