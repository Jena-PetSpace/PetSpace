import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/injection_container.dart';
import '../../../../core/services/block_service.dart';
import '../../../../core/utils/hashtag_utils.dart';
import '../../../../core/utils/public_ai_text.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/image_viewer_page.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/saved_posts_page.dart';
import '../../domain/repositories/social_repository.dart';
import '../utils/saved_posts_change_notifier.dart';
import 'collection_picker_sheet.dart';
import 'likes_bottom_sheet.dart';
import 'social_content_report_sheet.dart';

part 'post_card_header.dart';
part 'post_card_media.dart';
part 'post_card_actions.dart';
part 'post_card_dialogs.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onOpenDetail;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onBlocked;
  final void Function(String hashtag)? onHashtagTap;
  final SocialRepository? repository;
  final SavedPostsChangeNotifier? savedPostsNotifier;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.onOpenDetail,
    this.onDelete,
    this.onEdit,
    this.onBlocked,
    this.onHashtagTap,
    this.repository,
    this.savedPostsNotifier,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static const int _contentTruncateThreshold = 150;

  int _currentImageIndex = 0;
  Timer? _likeDebounce;
  bool _isSaved = false;
  bool _isSavePending = false;
  bool _showHeart = false;
  bool _isContentExpanded = false;

  Post get post => widget.post;
  SocialRepository get socialRepository =>
      widget.repository ?? sl<SocialRepository>();
  SavedPostsChangeNotifier get savedPostsNotifier =>
      widget.savedPostsNotifier ?? SavedPostsChangeNotifier.instance;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.post.isSavedByCurrentUser;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      setState(() {
        _isSaved = widget.post.isSavedByCurrentUser;
        _isSavePending = false;
      });
    } else if (oldWidget.post.isSavedByCurrentUser !=
        widget.post.isSavedByCurrentUser) {
      setState(() {
        _isSaved = widget.post.isSavedByCurrentUser;
        if (!_isSaved) _isSavePending = false;
      });
    }
  }

  @override
  void dispose() {
    _likeDebounce?.cancel();
    super.dispose();
  }

  String get currentUserId => widget.currentUserId;
  String get visibleContent => publicAiText(post.content ?? '');

  void _openDetail() {
    final callback = widget.onOpenDetail;
    if (callback != null) {
      callback();
      return;
    }
    context.push('/post/${post.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (post.imageUrls.isNotEmpty) ...[
            _buildImages(),
            _buildActions(),
            if (visibleContent.isNotEmpty)
              InkWell(
                key: const Key('post_card_open_detail'),
                onTap: _openDetail,
                child: _buildContent(),
              ),
            if (post.emotionAnalysis != null)
              InkWell(
                onTap: _openDetail,
                child: _buildEmotionAnalysis(),
              ),
          ] else ...[
            if (visibleContent.isNotEmpty)
              InkWell(
                key: const Key('post_card_open_detail'),
                onTap: _openDetail,
                child: _buildContent(),
              ),
            if (post.emotionAnalysis != null)
              InkWell(
                onTap: _openDetail,
                child: _buildEmotionAnalysis(),
              ),
            _buildActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    final content = visibleContent;
    final isLong = content.length > _contentTruncateThreshold;
    final displayText = (!_isContentExpanded && isLong)
        ? content.substring(0, _contentTruncateThreshold)
        : content;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextWithHashtags(displayText),
          if (isLong && !_isContentExpanded)
            GestureDetector(
              onTap: () => setState(() => _isContentExpanded = true),
              child: Text(
                '... 더보기',
                style: TextStyle(fontSize: 14.sp, color: AppTheme.primaryColor),
              ),
            ),
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

  // 감정 라벨 뱃지만 노출한다 — 퍼센트 도넛/게이지 등 수치 UI 금지
  // (P0 정책: 수치는 데이터 모델에만 보존, 피드 렌더 계층 노출 제거).
  Widget _buildEmotionAnalysis() {
    final emotionAnalysis = post.emotionAnalysis!;
    final dominantEmotion = emotionAnalysis.emotions.dominantEmotion;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppTheme.getEmotionColor(dominantEmotion).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color:
              AppTheme.getEmotionColor(dominantEmotion).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getEmotionIcon(dominantEmotion),
            color: AppTheme.getEmotionColor(dominantEmotion),
            size: 16.w,
          ),
          SizedBox(width: 6.w),
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
    );
  }

  String _formatDateTime(DateTime dateTime) => formatRelativeTime(dateTime);

  String _getEmotionName(String emotion) => AppTheme.getEmotionLabel(emotion);

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case 'happiness':
        return Icons.mood;
      case 'calm':
        return Icons.self_improvement;
      case 'excitement':
        return Icons.celebration;
      case 'curiosity':
        return Icons.psychology;
      case 'anxiety':
        return Icons.warning;
      case 'fear':
        return Icons.warning_amber_outlined;
      case 'sadness':
        return Icons.mood_bad;
      case 'discomfort':
        return Icons.sick_outlined;
      case 'sleepiness':
        return Icons.bedtime; // 하위 호환
      default:
        return Icons.help_outline;
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
