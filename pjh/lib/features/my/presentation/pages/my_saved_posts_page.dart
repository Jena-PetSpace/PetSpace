import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/domain/entities/bookmark_collection.dart';
import '../../../social/domain/entities/saved_posts_page.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../../social/presentation/bloc/bookmark_bloc.dart';
import '../widgets/saved_posts_grid.dart';

class MySavedPostsPage extends StatelessWidget {
  const MySavedPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.uid : '';
    return BlocProvider(
      create: (_) =>
          sl<BookmarkBloc>()..add(LoadBookmarkCollections(userId: userId)),
      child: _MySavedPostsView(userId: userId),
    );
  }
}

class _MySavedPostsView extends StatefulWidget {
  final String userId;
  const _MySavedPostsView({required this.userId});

  @override
  State<_MySavedPostsView> createState() => _MySavedPostsViewState();
}

class _MySavedPostsViewState extends State<_MySavedPostsView> {
  SavedPostsScope? _scope;
  BookmarkCollection? _selectedCollection;
  int? _detailCount;
  String? _pendingDeleteCollectionId;

  bool get _showingDetail => _scope != null;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookmarkBloc, BookmarkState>(
      listenWhen: (previous, current) =>
          previous.actionStatus != current.actionStatus ||
          previous.actionError != current.actionError,
      listener: (context, state) {
        if (state.actionStatus == BookmarkActionStatus.failure &&
            state.actionError != null) {
          _pendingDeleteCollectionId = null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionError!)),
          );
        } else if (state.actionStatus == BookmarkActionStatus.success &&
            _pendingDeleteCollectionId != null) {
          setState(() {
            _pendingDeleteCollectionId = null;
            _scope = null;
            _selectedCollection = null;
            _detailCount = null;
          });
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.subtleBackground,
          appBar: AppBar(
            backgroundColor: AppTheme.surfaceColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: _showingDetail
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => setState(() {
                      _scope = null;
                      _selectedCollection = null;
                      _detailCount = null;
                    }),
                  )
                : null,
            title: Text(
              _showingDetail ? (_selectedCollection?.name ?? '미분류') : '컬렉션',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            centerTitle: true,
            actions: _selectedCollection == null
                ? null
                : [
                    PopupMenuButton<String>(
                      key: const Key('collection_detail_menu'),
                      onSelected: (_) =>
                          _confirmDelete(context, _selectedCollection!),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'delete', child: Text('컬렉션 삭제')),
                      ],
                    ),
                  ],
          ),
          body: _showingDetail ? _buildDetail() : _buildHub(context, state),
        );
      },
    );
  }

  Widget _buildDetail() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppTheme.surfaceColor,
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 14.h),
          child: Text(
            _detailCount == null ? '게시물' : '게시물 $_detailCount개',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryTextColor,
            ),
          ),
        ),
        Expanded(
          child: SavedPostsGrid(
            repository: sl<SocialRepository>(),
            userId: widget.userId,
            scope: _scope!,
            onCountChanged: (count) {
              if (mounted && count != _detailCount) {
                setState(() => _detailCount = count);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHub(BuildContext context, BookmarkState state) {
    return RefreshIndicator(
      onRefresh: () async => context
          .read<BookmarkBloc>()
          .add(LoadBookmarkCollections(userId: widget.userId)),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _SummaryCard(state: state)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 12.h),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '내 컬렉션',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('create_collection'),
                    onPressed:
                        state.actionStatus == BookmarkActionStatus.loading
                            ? null
                            : () => _showCreateDialog(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('새 컬렉션'),
                  ),
                ],
              ),
            ),
          ),
          if (state.collectionsStatus == BookmarkLoadStatus.loading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 1.3,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) {
                    return _CollectionTile(
                      key: const Key('unassigned_collection'),
                      icon: Icons.bookmark_border_rounded,
                      name: '분류되지 않은 글',
                      subtitle: _countLabel(
                        state.unassignedCount,
                        failed: state.unassignedCountStatus ==
                            BookmarkLoadStatus.failure,
                      ),
                      onTap: () => _openScope(
                        const SavedPostsScope.unassigned(),
                      ),
                    );
                  }
                  final collection = state.collections[index - 1];
                  return _CollectionTile(
                    key: Key('collection_${collection.id}'),
                    icon: Icons.folder_rounded,
                    name: collection.name,
                    onTap: () => _openScope(
                      SavedPostsScope.collection(collection.id),
                      collection: collection,
                    ),
                  );
                },
                childCount: state.collections.length + 1,
              ),
            ),
          ),
          if (state.collectionsStatus == BookmarkLoadStatus.failure)
            SliverToBoxAdapter(
              child: _HubMessage(
                key: const Key('collections_error'),
                icon: Icons.cloud_off_outlined,
                title: '컬렉션을 불러오지 못했어요',
                actionLabel: '다시 시도',
                onAction: () => context.read<BookmarkBloc>().add(
                      LoadBookmarkCollections(userId: widget.userId),
                    ),
              ),
            ),
        ],
      ),
    );
  }

  String? _countLabel(int? count, {bool failed = false}) {
    if (failed) return '—';
    return count == null ? null : '$count개';
  }

  void _openScope(
    SavedPostsScope scope, {
    BookmarkCollection? collection,
  }) {
    setState(() {
      _scope = scope;
      _selectedCollection = collection;
      _detailCount = null;
    });
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('새 컬렉션'),
        content: TextField(
          key: const Key('collection_name_field'),
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: '컬렉션 이름'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('만들기'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && context.mounted) {
      context.read<BookmarkBloc>().add(CreateBookmarkCollection(
            userId: widget.userId,
            name: name,
          ));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BookmarkCollection collection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('컬렉션을 삭제할까요?'),
        content: Text(
          '“${collection.name}”을 삭제해도 게시글은 저장 상태로 유지되며 미분류로 이동해요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      _pendingDeleteCollectionId = collection.id;
      context.read<BookmarkBloc>().add(DeleteBookmarkCollection(
            collectionId: collection.id,
            userId: widget.userId,
          ));
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final BookmarkState state;
  const _SummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final countFailed = state.allCountStatus == BookmarkLoadStatus.failure ||
        state.unassignedCountStatus == BookmarkLoadStatus.failure;
    final allCount = state.allCountStatus == BookmarkLoadStatus.failure
        ? '—'
        : state.allCount?.toString() ?? '—';
    final unassignedCount =
        state.unassignedCountStatus == BookmarkLoadStatus.failure
            ? '—'
            : state.unassignedCount?.toString() ?? '—';
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bookmarks_outlined,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  '저장한 게시물',
                  style: TextStyle(
                    fontSize: AppTheme.fontBody.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (countFailed)
                IconButton(
                  key: const Key('retry_saved_counts'),
                  tooltip: '저장 개수 다시 불러오기',
                  onPressed: () {
                    final auth = context.read<AuthBloc>().state;
                    if (auth is AuthAuthenticated) {
                      context.read<BookmarkBloc>().add(
                            LoadBookmarkCollections(userId: auth.user.uid),
                          );
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            allCount,
            key: const Key('saved_posts_total_count'),
            style: TextStyle(
              fontSize: 30.sp,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: AppTheme.brandDeep,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            '전체 저장 · 미분류 $unassignedCount개',
            key: const Key('saved_posts_count_summary'),
            style: TextStyle(
              fontSize: AppTheme.fontCaption.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String? subtitle;
  final VoidCallback onTap;

  const _CollectionTile({
    super.key,
    required this.icon,
    required this.name,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30.w, color: AppTheme.primaryColor),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2.h),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HubMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _HubMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppTheme.lightTextColor),
          const SizedBox(height: 12),
          Text(title),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
