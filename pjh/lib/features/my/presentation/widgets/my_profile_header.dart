import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/domain/entities/user.dart';

class MyProfileHeader extends StatefulWidget {
  final User user;
  final VoidCallback? onPostsTapped;
  final int statsRefreshKey;
  final Widget? beforeStats;

  const MyProfileHeader({
    super.key,
    required this.user,
    this.onPostsTapped,
    this.statsRefreshKey = 0,
    this.beforeStats,
  });

  @override
  State<MyProfileHeader> createState() => _MyProfileHeaderState();
}

class _MyProfileHeaderState extends State<MyProfileHeader> {
  late Future<Map<String, dynamic>?> _profileFuture;
  late Future<Map<String, int>> _statsFuture;

  ProfileService get _profileService => sl<ProfileService>();

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  @override
  void didUpdateWidget(MyProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statsRefreshKey != widget.statsRefreshKey ||
        oldWidget.user != widget.user) {
      _reloadAll();
    }
  }

  void _reloadAll() {
    _profileFuture = _profileService.getProfile();
    _statsFuture = _profileService.getProfileStats();
  }

  void _retryProfile() {
    setState(() {
      _profileFuture = _profileService.getProfile();
    });
  }

  void _retryStats() {
    setState(() {
      _statsFuture = _profileService.getProfileStats();
    });
  }

  Future<void> _openProfileEdit() async {
    final updated = await context.push<bool>('/my/edit-profile');
    if (updated == true && mounted) {
      setState(_reloadAll);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? theme.colorScheme.surface : AppTheme.surfaceColor;
    final textColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    final mutedColor =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.textMuted;

    return Container(
      key: const Key('my_profile_header'),
      color: surface,
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 14.h),
      child: Column(
        children: [
          SizedBox(
            height: 44.h,
            child: Row(
              children: [
                Text(
                  'MY',
                  style: TextStyle(
                    fontSize: AppTheme.fontTitle.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brandDeep,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('my_settings_button'),
                  onPressed: () => context.push('/settings/my'),
                  tooltip: '설정',
                  icon: Icon(
                    Icons.settings_outlined,
                    color: textColor,
                    size: 22.w,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          FutureBuilder<Map<String, dynamic>?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final displayName =
                  (profile?['display_name'] as String?)?.trim().isNotEmpty ==
                          true
                      ? (profile!['display_name'] as String).trim()
                      : (widget.user.displayName.trim().isNotEmpty
                          ? widget.user.displayName.trim()
                          : '사용자');
              final photoUrl =
                  (profile?['photo_url'] as String?)?.isNotEmpty == true
                      ? profile!['photo_url'] as String
                      : widget.user.photoURL;
              final bio = (profile?['bio'] as String?)?.trim() ?? '';
              final initial = displayName.characters.first.toUpperCase();

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildAvatar(photoUrl, initial),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    key: const Key('my_profile_name'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: AppTheme.fontHeading.sp,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  key: const Key('my_profile_edit_button'),
                                  onPressed: _openProfileEdit,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8.w),
                                  ),
                                  child: Text(
                                    '프로필 편집',
                                    style: TextStyle(
                                      fontSize: AppTheme.fontCaption.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              Text(
                                '프로필을 불러오는 중이에요',
                                style: TextStyle(
                                  fontSize: AppTheme.fontCaption.sp,
                                  color: mutedColor,
                                ),
                              )
                            else if (snapshot.hasError)
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '프로필을 불러오지 못했어요',
                                      key: const Key('my_profile_error'),
                                      style: TextStyle(
                                        fontSize: AppTheme.fontCaption.sp,
                                        color: mutedColor,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    key: const Key('my_profile_retry'),
                                    onPressed: _retryProfile,
                                    child: const Text('다시 시도'),
                                  ),
                                ],
                              )
                            else
                              InkWell(
                                key: const Key('my_profile_bio_action'),
                                onTap: bio.isEmpty ? _openProfileEdit : null,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm.r),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4.h),
                                  child: Text(
                                    bio.isEmpty ? '소개를 작성해보세요' : bio,
                                    key: const Key('my_profile_bio'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: AppTheme.fontCaption.sp,
                                      height: 1.45,
                                      color: bio.isEmpty
                                          ? AppTheme.actionBase
                                          : mutedColor,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          if (widget.beforeStats != null) ...[
            SizedBox(height: 12.h),
            widget.beforeStats!,
          ],
          SizedBox(height: 10.h),
          FutureBuilder<Map<String, int>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  key: const Key('my_stats_error'),
                  width: double.infinity,
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                        : AppTheme.subtleBackground,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '활동 통계를 불러오지 못했어요',
                          style: TextStyle(
                            fontSize: AppTheme.fontCaption.sp,
                            color: mutedColor,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('my_stats_retry'),
                        onPressed: _retryStats,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                );
              }

              final loading =
                  snapshot.connectionState == ConnectionState.waiting;
              final stats = snapshot.data;
              return Container(
                key: const Key('my_stats_bar'),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest
                      : AppTheme.subtleBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: widget.onPostsTapped,
                        child: _buildStat(
                          loading ? '—' : '${stats?['posts'] ?? 0}',
                          '게시글',
                          textColor,
                          mutedColor,
                        ),
                      ),
                    ),
                    _buildDivider(isDark, theme),
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push(
                          '/followers/${widget.user.uid}?name=${Uri.encodeComponent(widget.user.displayName)}',
                        ),
                        child: _buildStat(
                          loading ? '—' : '${stats?['followers'] ?? 0}',
                          '팔로워',
                          textColor,
                          mutedColor,
                        ),
                      ),
                    ),
                    _buildDivider(isDark, theme),
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push(
                          '/following/${widget.user.uid}?name=${Uri.encodeComponent(widget.user.displayName)}',
                        ),
                        child: _buildStat(
                          loading ? '—' : '${stats?['following'] ?? 0}',
                          '팔로잉',
                          textColor,
                          mutedColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String initial) {
    return Container(
      key: const Key('my_profile_avatar'),
      width: 64.w,
      height: 64.w,
      decoration: const BoxDecoration(
        color: AppTheme.actionContainer,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _buildInitialAvatar(initial),
            )
          : _buildInitialAvatar(initial),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 26.sp,
          color: AppTheme.brandDeep,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStat(
    String value,
    String label,
    Color valueColor,
    Color labelColor,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 11.h),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: AppTheme.fontBody.sp,
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.fontMicro.sp,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark, ThemeData theme) {
    return Container(
      width: 1,
      height: 32.h,
      color: isDark ? theme.dividerColor : AppTheme.dividerColor,
    );
  }
}
