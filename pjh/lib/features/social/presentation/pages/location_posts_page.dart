import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/social_repository.dart';
import '../bloc/search_bloc.dart';
import '../controllers/post_interaction_coordinator.dart';
import '../widgets/edit_post_bottom_sheet.dart';
import '../widgets/post_card_connector.dart';

class LocationPostsPage extends StatefulWidget {
  final double lat;
  final double lng;
  final String? locationName;
  final SocialRepository? repository;
  final CurrentUserIdProvider? currentUserIdProvider;
  final PostInteractionCoordinator? coordinator;

  const LocationPostsPage({
    super.key,
    required this.lat,
    required this.lng,
    this.locationName,
    this.repository,
    this.currentUserIdProvider,
    this.coordinator,
  });

  @override
  State<LocationPostsPage> createState() => _LocationPostsPageState();
}

class _LocationPostsPageState extends State<LocationPostsPage> {
  final ScrollController _scrollController = ScrollController();
  List<Post> _posts = [];
  bool _loading = true;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _firstLoadError;
  String? _loadMoreError;
  int _loadGeneration = 0;

  SocialRepository get _repository =>
      widget.repository ?? sl<SocialRepository>();
  String get _currentUserId =>
      (widget.currentUserIdProvider ?? sl<CurrentUserIdProvider>())() ?? '';
  String get _title {
    final value = widget.locationName?.trim();
    return value == null || value.isEmpty ? '이 위치의 게시물' : value;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 500) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loadingMore || !_hasMore)) return;
    final generation = reset ? ++_loadGeneration : _loadGeneration;
    setState(() {
      if (reset) {
        _loading = true;
        _loadingMore = false;
        _firstLoadError = null;
        _loadMoreError = null;
        _posts = [];
        _hasMore = true;
      } else {
        _loadingMore = true;
        _loadMoreError = null;
      }
    });
    final result = await _repository.getPostsByLocation(
      lat: widget.lat,
      lng: widget.lng,
      radiusM: 500,
      userId: _currentUserId.isEmpty ? null : _currentUserId,
      limit: 20,
      offset: reset ? 0 : _posts.length,
    );
    if (!mounted || generation != _loadGeneration) return;
    result.fold(
      (failure) {
        dev.log(
          'LocationPostsPage load failed',
          name: 'LocationPostsPage',
          error: failure,
        );
        setState(() {
          _loading = false;
          _loadingMore = false;
          if (reset) {
            _firstLoadError = '게시물을 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
          } else {
            _loadMoreError = '다음 게시물을 불러오지 못했어요.';
          }
        });
      },
      (fetched) {
        final byId = <String, Post>{
          for (final post in reset ? const <Post>[] : _posts) post.id: post,
          for (final post in fetched) post.id: post,
        };
        setState(() {
          _loading = false;
          _loadingMore = false;
          _hasMore = fetched.length == 20;
          _posts = byId.values.toList();
        });
      },
    );
  }

  void _replacePost(Post post) {
    setState(() {
      _posts = _posts
          .map((candidate) => candidate.id == post.id ? post : candidate)
          .toList();
    });
  }

  void _removePost(String postId) {
    setState(() => _posts.removeWhere((post) => post.id == postId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.subtleBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Semantics(
          header: true,
          label: '위치 $_title',
          child: Text(
            _title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.brandDeep,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const FeedShimmerLoading();
    if (_firstLoadError != null && _posts.isEmpty) {
      return _errorState(_firstLoadError!, () => _load(reset: true));
    }
    if (_posts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.location_off_outlined,
        title: '이 위치의 게시물이 없어요',
        subtitle: '이 장소에서 첫 게시물을 작성해보세요.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        key: const Key('location_posts_list'),
        controller: _scrollController,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: _posts.length + 1,
        itemBuilder: (context, index) {
          if (index >= _posts.length) return _loadMoreFooter();
          final post = _posts[index];
          return PostCardConnector(
            key: ValueKey('location-post-${post.id}'),
            post: post,
            currentUserId: _currentUserId,
            repository: _repository,
            coordinator: widget.coordinator,
            onPostChanged: _replacePost,
            onPostRemoved: _removePost,
            shareText: 'PetSpace에서 $_title 게시물을 확인해보세요.',
            onEdit: () => _edit(post),
            onHashtagTap: (tag) => context.push('/hashtag/$tag'),
          );
        },
      ),
    );
  }

  void _edit(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPostBottomSheet(
        post: post,
        onSave: _replacePost,
      ),
    );
  }

  Widget _loadMoreFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_loadMoreError!),
            TextButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _errorState(String message, VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48.w, color: AppTheme.errorColor),
          SizedBox(height: 12.h),
          Text(message, textAlign: TextAlign.center),
          SizedBox(height: 8.h),
          FilledButton(onPressed: retry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
