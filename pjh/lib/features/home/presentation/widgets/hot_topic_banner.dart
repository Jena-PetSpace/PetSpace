import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/repositories/social_repository.dart';

class HotTopicBanner extends StatefulWidget {
  const HotTopicBanner({super.key});

  @override
  State<HotTopicBanner> createState() => _HotTopicBannerState();
}

class _HotTopicBannerState extends State<HotTopicBanner> {
  List<String> _tags = [];
  bool _loading = true;

  // 태그별 이모지/색상
  static const _tagMeta = <String, Map<String, dynamic>>{
    'health':    {'emoji': '🏥', 'label': '건강',   'color': Color(0xFF4CAF50)},
    'training':  {'emoji': '🎯', 'label': '훈련',   'color': Color(0xFF2196F3)},
    'food':      {'emoji': '🍖', 'label': '먹거리', 'color': Color(0xFFFF9800)},
    'life':      {'emoji': '🏡', 'label': '일상',   'color': Color(0xFF9C27B0)},
    'magazine':  {'emoji': '📰', 'label': '매거진', 'color': Color(0xFF1E3A5F)},
    'walk':      {'emoji': '🐾', 'label': '산책',   'color': Color(0xFF009688)},
    'grooming':  {'emoji': '✂️', 'label': '미용',   'color': Color(0xFFE91E63)},
    'play':      {'emoji': '🎾', 'label': '놀이',   'color': Color(0xFFFF5722)},
  };

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final repo = di.sl<SocialRepository>();
      final result = await repo.getTrendingHashtags(limit: 6);
      result.fold(
        (failure) {
          dev.log('트렌딩 태그 로드 실패: ${failure.message}', name: 'HotTopicBanner');
          if (mounted) setState(() { _tags = _fallbackTags(); _loading = false; });
        },
        (tags) {
          if (mounted) setState(() { _tags = tags.take(6).toList(); _loading = false; });
        },
      );
    } catch (e) {
      dev.log('트렌딩 태그 오류: $e', name: 'HotTopicBanner');
      if (mounted) setState(() { _tags = _fallbackTags(); _loading = false; });
    }
  }

  List<String> _fallbackTags() => ['health', 'training', 'food', 'life', 'walk', 'grooming'];

  Map<String, dynamic> _meta(String tag) =>
      _tagMeta[tag] ?? {'emoji': '🔥', 'label': '#$tag', 'color': AppTheme.primaryColor};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 타이틀
          Row(
            children: [
              Text(
                '🔥 지금 인기 있는 주제',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/feed'),
                child: Text(
                  '더보기',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // 태그 그리드 (2열 × 최대 3행)
          if (_loading)
            _buildSkeleton()
          else if (_tags.isEmpty)
            const SizedBox.shrink()
          else
            _buildTagGrid(context),
        ],
      ),
    );
  }

  Widget _buildTagGrid(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < _tags.length; i += 2) {
      final left = _tags[i];
      final right = i + 1 < _tags.length ? _tags[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < _tags.length ? 8.h : 0),
          child: Row(
            children: [
              Expanded(child: _buildTagChip(context, left)),
              SizedBox(width: 8.w),
              Expanded(
                child: right != null
                    ? _buildTagChip(context, right)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildTagChip(BuildContext context, String tag) {
    final meta = _meta(tag);
    final color = meta['color'] as Color;
    final emoji = meta['emoji'] as String;
    final label = meta['label'] as String;

    return GestureDetector(
      onTap: () => context.go('/feed?tab=community&category=$tag'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: 18.sp)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 10.w, color: color.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: List.generate(3, (row) => Padding(
        padding: EdgeInsets.only(bottom: row < 2 ? 8.h : 0),
        child: Row(
          children: [
            Expanded(child: _skeletonItem()),
            SizedBox(width: 8.w),
            Expanded(child: _skeletonItem()),
          ],
        ),
      )),
    );
  }

  Widget _skeletonItem() {
    return Container(
      height: 48.h,
      decoration: BoxDecoration(
        color: AppTheme.neutral200,
        borderRadius: BorderRadius.circular(14.r),
      ),
    );
  }
}
