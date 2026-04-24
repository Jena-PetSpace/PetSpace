import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/services/block_service.dart';
import '../../../../core/utils/hashtag_utils.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/image_viewer_page.dart';
import '../../../emotion/presentation/widgets/emotion_chart.dart';
import '../../domain/entities/post.dart';
import 'collection_picker_sheet.dart';
import 'likes_bottom_sheet.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final void Function(String hashtag)? onHashtagTap;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.onDelete,
    this.onEdit,
    this.onHashtagTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

// 앱 세션 내 스트릭 캐시 (N+1 쿼리 방지)
final Map<String, int> _streakCache = {};

class _PostCardState extends State<PostCard> {
  int _currentImageIndex = 0;
  Timer? _likeDebounce;
  Timer? _commentDebounce;
  bool _isSaved = false;
  bool _showHeart = false;

  Post get post => widget.post;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.post.isSavedByCurrentUser;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.isSavedByCurrentUser != widget.post.isSavedByCurrentUser) {
      setState(() => _isSaved = widget.post.isSavedByCurrentUser);
    }
  }

  Future<void> _toggleSave() async {
    if (widget.currentUserId.isEmpty) return;
    final prev = _isSaved;
    setState(() => _isSaved = !_isSaved);
    try {
      if (prev) {
        await Supabase.instance.client
            .from('saved_posts')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', widget.currentUserId);
      } else {
        await Supabase.instance.client.from('saved_posts').upsert({
          'post_id': post.id,
          'user_id': widget.currentUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장되었습니다 🔖'),
              backgroundColor: AppTheme.primaryColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      dev.log('북마크 토글 실패: $e', name: 'PostCard');
      if (mounted) setState(() => _isSaved = prev);
    }
  }

  @override
  void dispose() {
    _likeDebounce?.cancel();
    _commentDebounce?.cancel();
    super.dispose();
  }
  String get currentUserId => widget.currentUserId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          // 캡션 탭 → 게시글 상세
          if (post.content != null && post.content!.isNotEmpty)
            InkWell(
              onTap: () => context.push('/post/${post.id}'),
              child: _buildContent(),
            ),
          // 이미지: 기존 탭/더블탭 동작 유지
          if (post.imageUrls.isNotEmpty) _buildImages(),
          // 감정분석 카드 탭 → 게시글 상세
          if (post.emotionAnalysis != null)
            InkWell(
              onTap: () => context.push('/post/${post.id}'),
              child: _buildEmotionAnalysis(),
            ),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          // 프로필 영역(아바타+이름+시간) 전체를 하나의 InkWell로 묶어 프로필 이동
          Expanded(
            child: InkWell(
              onTap: () => context.push('/user-profile/${post.authorId}'),
              borderRadius: BorderRadius.circular(8.r),
              child: Row(
                children: [
                  Semantics(
                    label: '${post.authorName} 프로필 사진',
                    image: true,
                    child: CircleAvatar(
                      radius: 20.r,
                      backgroundImage: post.authorProfileImage != null
                          ? CachedNetworkImageProvider(post.authorProfileImage!)
                          : null,
                      child: post.authorProfileImage == null
                          ? Text(
                              post.authorName.isNotEmpty ? post.authorName[0] : '?',
                              style: TextStyle(fontSize: 14.sp))
                          : null,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          _buildStreakBadge(post.authorId),
                          SizedBox(width: 4.w),
                          _buildTypeBadge(),
                        ]),
                        Text(
                          _formatDateTime(post.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, size: 24.w),
            onPressed: () => _showPostOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextWithHashtags(post.content!),
          if (post.tags.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: post.tags.map((tag) {
                return _buildHashtagChip(tag);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextWithHashtags(String text) {
    final segments = HashtagUtils.parseTextWithHashtags(text);

    if (segments.isEmpty) {
      return Text(
        text,
        style: TextStyle(fontSize: 14.sp, height: 1.4),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14.sp,
          height: 1.4,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        children: segments.map((segment) {
          if (segment['isHashtag'] == true) {
            final hashtag = segment['hashtag'] as String;
            return WidgetSpan(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (widget.onHashtagTap != null) {
                    widget.onHashtagTap!(hashtag);
                  } else {
                    dev.log('Hashtag tapped: #$hashtag', name: 'PostCard');
                  }
                },
                child: Text(
                  segment['text'],
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          } else {
            return TextSpan(text: segment['text']);
          }
        }).toList(),
      ),
    );
  }

  Widget _buildHashtagChip(String tag) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.onHashtagTap != null) {
          widget.onHashtagTap!(tag);
        } else {
          dev.log('Hashtag tapped: #$tag', name: 'PostCard');
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          '#$tag',
          style: TextStyle(
            fontSize: 13.sp,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _onDoubleTapImage() {
    if (!post.isLikedByCurrentUser) {
      widget.onLike();
    }
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  Widget _buildImages() {
    if (post.imageUrls.length == 1) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: GestureDetector(
          onTap: () => _openViewer(context, 0),
          onDoubleTap: _onDoubleTapImage,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CachedNetworkImage(
                imageUrl: post.imageUrls.first,
                width: double.infinity,
                height: 300.h,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 300.h,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 300.h,
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 24.w),
                      SizedBox(height: 8.h),
                      Text('이미지 로드 실패',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 14.sp)),
                    ],
                  ),
                ),
              ),
              if (_showHeart)
                _DoubleTapHeart(size: 80.w),
            ],
          ),
        ),
      );
    }

    // Multi-image: PageView with dots indicator + 탭으로 전체화면 뷰어
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        children: [
          SizedBox(
            height: 300.h,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  itemCount: post.imageUrls.length,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _openViewer(context, index),
                      onDoubleTap: _onDoubleTapImage,
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrls[index],
                        width: double.infinity,
                        height: 300.h,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 300.h,
                          color: Colors.grey[200],
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 300.h,
                          color: Colors.grey[200],
                          child: Icon(Icons.error,
                              color: Colors.red, size: 24.w),
                        ),
                      ),
                    );
                  },
                ),
                if (_showHeart) _DoubleTapHeart(size: 80.w),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(post.imageUrls.length, (index) {
              return Container(
                width: _currentImageIndex == index ? 8.w : 6.w,
                height: _currentImageIndex == index ? 8.w : 6.w,
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentImageIndex == index
                      ? AppTheme.primaryColor
                      : Colors.grey[300],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBadge(String authorId) {
    return FutureBuilder<int>(
      future: _fetchStreak(authorId),
      builder: (ctx, snap) {
        final streak = snap.data ?? 0;
        if (streak < 3) return const SizedBox.shrink();

        final String emoji;
        final Color color;
        if (streak >= 30) {
          emoji = '⭐';
          color = Colors.amber;
        } else if (streak >= 7) {
          emoji = '🔥';
          color = Colors.orange;
        } else {
          emoji = '🔥';
          color = Colors.deepOrange;
        }

        return Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: TextStyle(fontSize: 11.sp)),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ]);
      },
    );
  }

  Future<int> _fetchStreak(String authorId) async {
    if (_streakCache.containsKey(authorId)) return _streakCache[authorId]!;
    try {
      final res = await Supabase.instance.client
          .rpc('get_user_streak', params: {'p_user_id': authorId});
      final streak = (res as int?) ?? 0;
      _streakCache[authorId] = streak;
      return streak;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildTypeBadge() {
    switch (post.type) {
      case PostType.emotionAnalysis:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text('감정분석',
              style: TextStyle(
                  fontSize: 10.sp,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600)),
        );
      case PostType.text:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text('커뮤니티',
              style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w600)),
        );
      case PostType.image:
      case PostType.video:
        return const SizedBox.shrink();
    }
  }

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageViewerPage(
          imageUrls: post.imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildEmotionAnalysis() {
    final emotionAnalysis = post.emotionAnalysis!;
    final dominantEmotion = emotionAnalysis.emotions.dominantEmotion;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.getEmotionColor(dominantEmotion).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color:
              AppTheme.getEmotionColor(dominantEmotion).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60.w,
            height: 60.w,
            child: EmotionChart(
              emotions: emotionAnalysis.emotions,
              size: 60.w,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getEmotionIcon(dominantEmotion),
                      color: AppTheme.getEmotionColor(dominantEmotion),
                      size: 16.w,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _getEmotionName(dominantEmotion),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getEmotionColor(dominantEmotion),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
                Text(
                  '신뢰도 ${(emotionAnalysis.confidence * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: post.isLikedByCurrentUser ? '좋아요 취소' : '좋아요',
                button: true,
                child: InkWell(
                  onTap: () {
                    _likeDebounce?.cancel();
                    _likeDebounce = Timer(const Duration(milliseconds: 300), () {
                      if (mounted) widget.onLike();
                    });
                  },
                  borderRadius: BorderRadius.circular(20.r),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    child: Icon(
                      post.isLikedByCurrentUser
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: post.isLikedByCurrentUser ? Colors.red : null,
                      size: 20.w,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: post.likesCount > 0
                    ? () => LikesBottomSheet.show(
                          context,
                          postId: post.id,
                          currentUserId: currentUserId,
                        )
                    : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                  child: Text(
                    '${post.likesCount}',
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 16.w),
          Semantics(
            label: '댓글 ${post.commentsCount}개 보기',
            button: true,
            child: InkWell(
              onTap: widget.onComment,
              borderRadius: BorderRadius.circular(20.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.comment_outlined, size: 20.w),
                    SizedBox(width: 4.w),
                    Text(
                      '${post.commentsCount}',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          InkWell(
            onTap: widget.onShare,
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              child: Icon(Icons.share_outlined, size: 20.w),
            ),
          ),
          const Spacer(),
          // 북마크 버튼 (단탭=저장토글, 롱프레스=컬렉션 선택)
          SizedBox(
            width: 44.w,
            height: 44.w,
            child: GestureDetector(
              onTap: _toggleSave,
              onLongPress: () {
                if (widget.currentUserId.isEmpty) return;
                CollectionPickerSheet.show(
                  context,
                  postId: post.id,
                  userId: widget.currentUserId,
                );
              },
              child: Icon(
                _isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_outlined,
                size: 22.w,
                color: _isSaved ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
              ),
            ),
          ),
          if (post.location != null)
            GestureDetector(
              onTap: (post.locationLat != null && post.locationLng != null)
                  ? () => context.push('/location', extra: {
                        'lat': post.locationLat,
                        'lng': post.locationLng,
                        'locationName': post.location,
                      })
                  : null,
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16.w,
                      color: (post.locationLat != null && post.locationLng != null)
                          ? AppTheme.primaryColor
                          : Colors.grey),
                  SizedBox(width: 4.w),
                  Text(
                    post.location!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: (post.locationLat != null && post.locationLng != null)
                          ? AppTheme.primaryColor
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (post.authorId == currentUserId) ...[
            if (widget.onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onEdit!();
                },
              ),
            if (widget.onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(context);
                },
              ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text('신고'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('차단'),
              onTap: () {
                Navigator.pop(ctx);
                _showBlockDialog(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    String? selectedReason;
    final reasons = [
      '스팸 또는 광고',
      '폭력적이거나 위험한 콘텐츠',
      '허위 정보',
      '혐오 발언 또는 차별',
      '개인정보 침해',
      '기타',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('게시물 신고'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '신고 사유를 선택해주세요',
                style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              SizedBox(height: 12.h),
              ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason, style: TextStyle(fontSize: 14.sp)),
                    value: reason,
                    // ignore: deprecated_member_use
                    groupValue: selectedReason,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setDialogState(() => selectedReason = value);
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: AppTheme.primaryColor,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: selectedReason != null
                  ? () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('신고가 접수되었습니다. 검토 후 조치하겠습니다.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  : null,
              child: const Text('신고'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사용자 차단'),
        content: Text(
          '${post.authorName}님을 차단하시겠습니까?\n\n차단하면 해당 사용자의 게시물과 댓글이 보이지 않습니다.',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final blockSvc = sl<BlockService>();
              final success = await blockSvc.blockUser(post.authorId);
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${post.authorName}님을 차단했습니다.'),
                    backgroundColor: Colors.red,
                    action: SnackBarAction(
                      label: '차단 해제',
                      textColor: Colors.white,
                      onPressed: () async {
                        final ok = await blockSvc.unblockUser(post.authorId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? '${post.authorName}님의 차단이 해제되었습니다.'
                                : '차단 해제에 실패했습니다.'),
                          ),
                        );
                      },
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('차단 처리에 실패했습니다.')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('차단'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시물 삭제'),
        content: const Text('정말로 이 게시물을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete!();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  String _getEmotionName(String emotion) => AppTheme.getEmotionLabel(emotion);

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case 'happiness':  return Icons.mood;
      case 'calm':       return Icons.self_improvement;
      case 'excitement': return Icons.celebration;
      case 'curiosity':  return Icons.psychology;
      case 'anxiety':    return Icons.warning;
      case 'fear':       return Icons.warning_amber_outlined;
      case 'sadness':    return Icons.mood_bad;
      case 'discomfort': return Icons.sick_outlined;
      case 'sleepiness': return Icons.bedtime; // 하위 호환
      default:           return Icons.help_outline;
    }
  }
}

// ─── 더블탭 하트 애니메이션 ─────────────────────────────────────────────────────
class _DoubleTapHeart extends StatefulWidget {
  final double size;
  const _DoubleTapHeart({required this.size});

  @override
  State<_DoubleTapHeart> createState() => _DoubleTapHeartState();
}

class _DoubleTapHeartState extends State<_DoubleTapHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Icon(Icons.favorite, color: Colors.white, size: widget.size),
        ),
      ),
    );
  }
}
