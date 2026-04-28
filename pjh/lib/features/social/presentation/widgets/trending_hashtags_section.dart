import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../domain/repositories/social_repository.dart';

class TrendingHashtagsSection extends StatefulWidget {
  const TrendingHashtagsSection({super.key});

  @override
  State<TrendingHashtagsSection> createState() => _TrendingHashtagsSectionState();
}

class _TrendingHashtagsSectionState extends State<TrendingHashtagsSection> {
  List<String> _hashtags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<SocialRepository>()
        .getTrendingHashtags(limit: 10, days: 7);
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loading = false),
      (tags) => setState(() {
        _hashtags = tags;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 48.h,
        child: Center(
          child: SizedBox(
            width: 18.w,
            height: 18.w,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_hashtags.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    size: 16.w, color: Colors.deepOrange),
                SizedBox(width: 4.w),
                Text(
                  '인기 해시태그',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 32.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: _hashtags.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final tag = _hashtags[index];
                return GestureDetector(
                  onTap: () => context.push('/hashtag/$tag'),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 4.h),
          const Divider(height: 1, thickness: 1, color: AppTheme.dividerColor),
        ],
      ),
    );
  }
}
