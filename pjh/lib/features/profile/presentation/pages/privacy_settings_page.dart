import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_settings_components.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../social/domain/entities/blocked_user.dart';
import '../../../social/domain/repositories/social_repository.dart';

class PrivacySettingsPage extends StatefulWidget {
  final SocialRepository? repository;

  const PrivacySettingsPage({super.key, this.repository});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  late final SocialRepository _repository =
      widget.repository ?? sl<SocialRepository>();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<BlockedUser> _users = const [];
  BlockedUsersCursor? _cursor;
  Object? _initialError;
  Object? _footerError;
  bool _loading = true;
  bool _loadingMore = false;
  int _requestToken = 0;
  final Set<String> _pendingUnblockIds = <String>{};

  String get _query => _searchController.text;
  String get _normalizedQuery =>
      _query.trim().replaceFirst(RegExp(r'^@+'), '').trim();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _requestToken++;
    _debounce = Timer(const Duration(milliseconds: 350), _loadFirstPage);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 240 &&
        !_loadingMore &&
        !(_debounce?.isActive ?? false) &&
        _cursor != null) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    final token = ++_requestToken;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _initialError = null;
      _footerError = null;
      _cursor = null;
    });
    final result = await _repository.getBlockedUsers(query: _normalizedQuery);
    if (!mounted || token != _requestToken) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _initialError = failure;
      }),
      (page) => setState(() {
        _loading = false;
        _users = page.users;
        _cursor = page.nextCursor;
      }),
    );
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore) return;
    final token = _requestToken;
    setState(() {
      _loadingMore = true;
      _footerError = null;
    });
    final result = await _repository.getBlockedUsers(
      query: _normalizedQuery,
      cursor: cursor,
    );
    if (!mounted || token != _requestToken) return;
    result.fold(
      (failure) => setState(() {
        _loadingMore = false;
        _footerError = failure;
      }),
      (page) {
        final existingIds = _users.map((user) => user.id).toSet();
        final incomingIds = page.users.map((user) => user.id).toSet();
        final hasDuplicate = incomingIds.length != page.users.length ||
            incomingIds.any(existingIds.contains);
        if (hasDuplicate) {
          setState(() {
            _loadingMore = false;
            _footerError = StateError('duplicate blocked-user id');
          });
          return;
        }
        setState(() {
          _loadingMore = false;
          _users = [..._users, ...page.users];
          _cursor = page.nextCursor;
        });
      },
    );
  }

  Future<void> _unblock(BlockedUser user) async {
    if (_pendingUnblockIds.contains(user.id)) return;
    setState(() => _pendingUnblockIds.add(user.id));
    final result = await _repository.unblockUser(user.id);
    if (!mounted) return;
    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('차단을 해제하지 못했습니다. 다시 시도해 주세요.')),
      ),
      (_) {
        final remaining = _users.where((item) => item.id != user.id).toList();
        final shouldLoadMore = remaining.isEmpty && _cursor != null;
        setState(() => _users = remaining);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.displayName}님의 차단을 해제했습니다.')),
        );
        if (shouldLoadMore) unawaited(_loadMore());
      },
    );
    if (mounted) {
      setState(() => _pendingUnblockIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PetSpacePageScaffold(
      title: '개인정보 보호',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/settings/my'),
      ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        children: [
          const PetSpaceSettingsSection(
            title: '개인정보 안내',
            children: [
              ListTile(
                title: Text('현재 제공 범위'),
                subtitle: Text(
                  '이메일 검색과 온라인 상태 표시는 제공하지 않습니다. '
                  '프로필과 게시물 공개 범위 제어 기능은 아직 제공되지 않습니다.',
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          PetSpaceSettingsSection(
            title: '차단한 사용자',
            children: [
              Padding(
                padding: EdgeInsets.all(12.w),
                child: TextField(
                  key: const Key('blocked-user-search'),
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: '이름 또는 사용자 이름 검색',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              _buildState(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildState() {
    if (_loading) return const PetSpaceStateView.loading();
    if (_initialError != null) {
      return PetSpaceStateView.error(
        message: '차단 목록을 불러오지 못했습니다.',
        actionLabel: '다시 시도',
        onAction: _loadFirstPage,
      );
    }
    if (_users.isEmpty && _loadingMore) {
      return const PetSpaceStateView.loading();
    }
    if (_users.isEmpty && _cursor != null && _footerError != null) {
      return PetSpaceStateView.error(
        message: '차단 목록을 더 불러오지 못했습니다.',
        actionLabel: '다시 시도',
        onAction: _loadMore,
      );
    }
    if (_users.isEmpty) {
      return PetSpaceStateView.empty(
        message: _normalizedQuery.isEmpty ? '차단한 사용자가 없습니다.' : '검색 결과가 없습니다.',
      );
    }
    return Column(
      children: [
        for (final user in _users) _buildUserTile(user),
        if (_loadingMore) const PetSpaceStateView.loading(),
        if (_footerError != null)
          TextButton(
            key: const Key('blocked-users-load-more-retry'),
            onPressed: _loadMore,
            child: const Text('더 불러오기 다시 시도'),
          ),
      ],
    );
  }

  Widget _buildUserTile(BlockedUser user) {
    final isPending = _pendingUnblockIds.contains(user.id);
    return ListTile(
      key: ValueKey('blocked-user-${user.id}'),
      leading: CircleAvatar(
        backgroundColor: AppTheme.actionContainer,
        backgroundImage:
            user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
        child: user.photoUrl == null
            ? Text(user.displayName.isEmpty ? '?' : user.displayName[0])
            : null,
      ),
      title: Text(user.displayName),
      subtitle: user.username == null ? null : Text('@${user.username}'),
      trailing: Semantics(
        button: true,
        enabled: !isPending,
        excludeSemantics: true,
        label: isPending
            ? '${user.displayName}님 차단 해제 중'
            : '${user.displayName}님 차단 해제',
        child: SizedBox(
          height: 44,
          child: TextButton(
            key: ValueKey('unblock-user-${user.id}'),
            onPressed: isPending ? null : () => _unblock(user),
            child: isPending
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 6),
                      Text('해제 중'),
                    ],
                  )
                : const Text('차단 해제'),
          ),
        ),
      ),
    );
  }
}
