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

  // 태그 라벨 — v2: 이모지 제거, 카테고리별 컬러 배리에이션 금지(actionBase 단일)
  static const _tagLabels = <String, String>{
    'health': '건강', 'training': '훈련', 'food': '먹거리', 'life': '일상',
    'magazine': '매거진', 'walk': '산책', 'grooming': '미용', 'play': '놀이',
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

  String _label(String tag) => _tagLabels[tag] ?? '#$tag';

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
                '지금 인기 있는 주제',
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
    final label = _label(tag);

    return GestureDetector(
      // 해시태그는 카테고리가 아니라 해시태그 피드로 — 구 category 파라미터
      // 전송은 라운지 매칭 실패 폴백으로만 동작하던 잠재 버그(O-3).
      onTap: () => context.push('/hashtag/$tag'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppTheme.actionContainer,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.actionBase,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 10.w, color: AppTheme.actionBase.withValues(alpha: 0.5)),
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
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(14.r),
      ),
    );
  }
}
