import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/bookmark_collection.dart';
import '../../domain/entities/saved_posts_page.dart';
import '../../domain/repositories/social_repository.dart';
import '../utils/saved_posts_change_notifier.dart';

class CollectionPickerSheet extends StatefulWidget {
  final String postId;
  final String userId;
  final SocialRepository? repository;
  final SavedPostsChangeNotifier? changeNotifier;

  const CollectionPickerSheet({
    super.key,
    required this.postId,
    required this.userId,
    this.repository,
    this.changeNotifier,
  });

  static Future<String?> show(
    BuildContext context, {
    required String postId,
    required String userId,
    SocialRepository? repository,
    SavedPostsChangeNotifier? changeNotifier,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectionPickerSheet(
        postId: postId,
        userId: userId,
        repository: repository,
        changeNotifier: changeNotifier,
      ),
    );
  }

  @override
  State<CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<CollectionPickerSheet> {
  final TextEditingController _nameController = TextEditingController();
  List<BookmarkCollection> _collections = [];
  SavedPostLocation? _location;
  String? _selectedId;
  bool _loading = true;
  bool _saving = false;
  bool _creating = false;
  bool _showCreateField = false;
  String? _loadError;
  String? _moveError;
  String? _createError;

  SocialRepository get _repository =>
      widget.repository ?? sl<SocialRepository>();
  SavedPostsChangeNotifier get _notifier =>
      widget.changeNotifier ?? SavedPostsChangeNotifier.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final collectionsFuture = _repository.getBookmarkCollections(widget.userId);
    final locationFuture = _repository.getSavedPostLocation(
      postId: widget.postId,
      userId: widget.userId,
    );
    final collectionsResult = await collectionsFuture;
    final locationResult = await locationFuture;
    if (!mounted) return;
    if (collectionsResult.isLeft() || locationResult.isLeft()) {
      setState(() {
        _loading = false;
        _loadError = '저장 위치를 불러오지 못했어요.';
      });
      return;
    }
    final collections = collectionsResult.getOrElse(() => const []);
    final location = locationResult.fold<SavedPostLocation?>(
      (_) => null,
      (value) => value,
    );
    setState(() {
      _collections = collections;
      _location = location;
      _selectedId = location?.collectionId;
      _loading = false;
      _loadError = null;
    });
  }

  Future<void> _move() async {
    if (_saving || _location == null) return;
    if (_selectedId == _location!.collectionId) {
      Navigator.pop(context, _selectedId);
      return;
    }
    setState(() {
      _saving = true;
      _moveError = null;
    });
    final previousId = _location!.collectionId;
    final selectedId = _selectedId;
    final notifier = _notifier;
    final result = await _repository.updateSavedPostCollection(
      postId: widget.postId,
      userId: widget.userId,
      collectionId: selectedId,
    );
    if (result.isLeft()) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _moveError = '저장 위치를 변경하지 못했어요. 다시 시도해주세요.';
      });
      return;
    }

    notifier.publish(
      type: SavedPostsChangeType.moved,
      postId: widget.postId,
      wasSaved: true,
      isSaved: true,
      oldCollectionId: previousId,
      newCollectionId: selectedId,
    );
    if (mounted) Navigator.pop(context, selectedId);
  }

  Future<void> _createCollection() async {
    if (_creating || _saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _createError = '컬렉션 이름을 입력해주세요.');
      return;
    }
    setState(() {
      _creating = true;
      _createError = null;
    });
    final result = await _repository.createBookmarkCollection(
      userId: widget.userId,
      name: name,
    );
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _creating = false;
        _createError = '컬렉션을 만들지 못했어요. 다시 시도해주세요.';
      }),
      (collection) => setState(() {
        _collections = [collection, ..._collections];
        _selectedId = collection.id;
        _creating = false;
        _showCreateField = false;
        _createError = null;
        _nameController.clear();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: keyboard > 0 ? 0.92 : 0.68,
      minChildSize: keyboard > 0 ? 0.72 : 0.48,
      maxChildSize: 0.96,
      builder: (_, controller) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: keyboard),
        child: Material(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 10.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 12.w, 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '저장 위치 선택',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('picker_create_collection'),
                      onPressed: _loading ||
                              _saving ||
                              _creating ||
                              _loadError != null ||
                              _location == null
                          ? null
                          : () => setState(() {
                                _showCreateField = !_showCreateField;
                                _createError = null;
                              }),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('새 컬렉션'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildBody(controller)),
              if (_moveError != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    _moveError!,
                    key: const Key('picker_move_error'),
                    style:
                        TextStyle(color: AppTheme.errorColor, fontSize: 12.sp),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
                child: SizedBox(
                  width: double.infinity,
                  height: (48.h).clamp(44.0, 54.0).toDouble(),
                  child: FilledButton(
                    key: const Key('picker_move_button'),
                    onPressed: _saving || _creating || _location == null
                        ? null
                        : _move,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.actionBase,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('선택한 위치로 이동'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ScrollController controller) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _PickerState(
        key: const Key('picker_load_error'),
        icon: Icons.cloud_off_outlined,
        message: _loadError!,
        actionLabel: '다시 시도',
        onAction: _load,
      );
    }
    if (_location == null) {
      return const _PickerState(
        key: Key('picker_not_saved'),
        icon: Icons.bookmark_add_outlined,
        message: '먼저 게시물을 저장해주세요.',
      );
    }
    return ListView(
      controller: controller,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      children: [
        if (_showCreateField)
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('picker_collection_name'),
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: '컬렉션 이름',
                    hintText: '예: 산책 기록',
                  ),
                  onSubmitted: (_) {
                    if (!_creating && !_saving) _createCollection();
                  },
                ),
                if (_createError != null)
                  Text(
                    _createError!,
                    key: const Key('picker_create_error'),
                    style:
                        TextStyle(color: AppTheme.errorColor, fontSize: 12.sp),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: const Key('picker_create_button'),
                    onPressed: _creating || _saving ? null : _createCollection,
                    child: _creating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('만들기'),
                  ),
                ),
              ],
            ),
          ),
        _CollectionTile(
          key: const Key('picker_unassigned'),
          name: '분류하지 않음',
          selected: _selectedId == null,
          onTap: _saving || _creating
              ? null
              : () => setState(() {
                    _selectedId = null;
                    _moveError = null;
                  }),
        ),
        ..._collections.map((collection) => _CollectionTile(
              key: Key('picker_collection_${collection.id}'),
              name: collection.name,
              selected: _selectedId == collection.id,
              onTap: _saving || _creating
                  ? null
                  : () => setState(() {
                        _selectedId = collection.id;
                        _moveError = null;
                      }),
            )),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback? onTap;

  const _CollectionTile({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 8.h,
      leading: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: AppTheme.subtleBackground,
          borderRadius: BorderRadius.circular(10.r),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.folder_outlined, color: AppTheme.primaryColor),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? AppTheme.primaryColor : AppTheme.dividerColor,
      ),
      onTap: onTap,
    );
  }
}

class _PickerState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PickerState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.lightTextColor),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
