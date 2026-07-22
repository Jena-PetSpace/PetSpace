import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileStatsCard extends StatelessWidget {
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final VoidCallback? onPostsTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const ProfileStatsCard({
    super.key,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    this.onPostsTap,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                key: const Key('profile_stat_posts'),
                label: '게시물',
                count: postsCount,
                onTap: onPostsTap,
              ),
            ),
            _buildDivider(),
            Expanded(
              child: _buildStatItem(
                context,
                key: const Key('profile_stat_followers'),
                label: '팔로워',
                count: followersCount,
                onTap: onFollowersTap,
              ),
            ),
            _buildDivider(),
            Expanded(
              child: _buildStatItem(
                context,
                key: const Key('profile_stat_following'),
                label: '팔로잉',
                count: followingCount,
                onTap: onFollowingTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required Key key,
    required String label,
    required int count,
    required VoidCallback? onTap,
  }) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: 52.h),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatCount(count),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      key: key,
      button: onTap != null,
      label: '$label $count',
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: onTap,
              child: content,
            ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 36.h, width: 1, color: Colors.grey[200]);
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}
