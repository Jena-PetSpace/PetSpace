import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/bookmark_collection.dart';

class CollectionPickerSheet extends StatefulWidget {
  final String postId;
  final String userId;
  final String? currentCollectionId;

  const CollectionPickerSheet({
    super.key,
    required this.postId,
    required this.userId,
    this.currentCollectionId,
  });

  static Future<void> show(
    BuildContext context, {
    required String postId,
    required String userId,
    String? currentCollectionId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectionPickerSheet(
        postId: postId,
        userId: userId,
        currentCollectionId: currentCollectionId,
      ),
    );
  }

  @override
  State<CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<CollectionPickerSheet> {
  final _supabase = Supabase.instance.client;
  List<BookmarkCollection> _collections = [];
  bool _loading = true;
  String? _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentCollectionId;
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final response = await _supabase
          .from('bookmark_collections')
          .select('id, user_id, name, emoji, created_at, updated_at, post_count')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      setState(() {
        _collections = (response as List).map((e) {
          final m = e as Map<String, dynamic>;
          return BookmarkCollection(
            id: m['id'] as String,
            userId: m['user_id'] as String,
            name: m['name'] as String,
            emoji: m['emoji'] as String? ?? '📁',
            createdAt: DateTime.parse(m['created_at'] as String),
            updatedAt: DateTime.parse(m['updated_at'] as String),
            postCount: m['post_count'] as int? ?? 0,
          );
        }).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_selectedId == null) {
        // 기본 저장소 (collection_id = null)
        await _supabase
            .from('saved_posts')
            .update({'collection_id': null})
            .eq('post_id', widget.postId)
            .eq('user_id', widget.userId);
      } else {
        await _supabase
            .from('saved_posts')
            .update({'collection_id': _selectedId})
            .eq('post_id', widget.postId)
            .eq('user_id', widget.userId);
      }
      if (mounted) Navigator.pop(context, _selectedId);
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  Future<void> _createCollection() async {
    final nameCtrl = TextEditingController();
    String selectedEmoji = '📁';

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('새 컬렉션'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final emojis = ['📁', '❤️', '🐶', '🐱', '🌟', '🏆', '📸', '🎉'];
                  final picked = await showDialog<String>(
                    context: ctx,
                    builder: (c) => SimpleDialog(
                      title: const Text('이모지 선택'),
                      children: emojis
                          .map((e) => SimpleDialogOption(
                                child: Text(e, style: const TextStyle(fontSize: 28)),
                                onPressed: () => Navigator.pop(c, e),
                              ))
                          .toList(),
                    ),
                  );
                  if (picked != null) setS(() => selectedEmoji = picked);
                },
                child: Text(selectedEmoji, style: const TextStyle(fontSize: 36)),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '컬렉션 이름',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              child: const Text('만들기'),
            ),
          ],
        ),
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final response = await _supabase
          .from('bookmark_collections')
          .insert({
            'user_id': widget.userId,
            'name': name,
            'emoji': selectedEmoji,
          })
          .select()
          .single();

      final newCol = BookmarkCollection(
        id: response['id'] as String,
        userId: response['user_id'] as String,
        name: response['name'] as String,
        emoji: response['emoji'] as String? ?? '📁',
        createdAt: DateTime.parse(response['created_at'] as String),
        updatedAt: DateTime.parse(response['updated_at'] as String),
        postCount: 0,
      );

      setState(() {
        _collections = [newCol, ..._collections];
        _selectedId = newCol.id;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 핸들
            Container(
              margin: EdgeInsets.symmetric(vertical: 10.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Text('컬렉션에 저장',
                      style: TextStyle(
                          fontSize: 17.sp, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _createCollection,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('새 컬렉션'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_loading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  controller: ctrl,
                  children: [
                    // 기본 저장소 옵션
                    _CollectionTile(
                      emoji: '🔖',
                      name: '기본 저장',
                      postCount: null,
                      selected: _selectedId == null,
                      onTap: () => setState(() => _selectedId = null),
                    ),
                    ..._collections.map((col) => _CollectionTile(
                          emoji: col.emoji,
                          name: col.name,
                          postCount: col.postCount,
                          selected: _selectedId == col.id,
                          onTap: () => setState(() => _selectedId = col.id),
                        )),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('저장'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final String emoji;
  final String name;
  final int? postCount;
  final bool selected;
  final VoidCallback onTap;

  const _CollectionTile({
    required this.emoji,
    required this.name,
    required this.postCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: AppTheme.subtleBackground,
          borderRadius: BorderRadius.circular(10.r),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
      title: Text(name,
          style:
              TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500)),
      subtitle: postCount != null
          ? Text('게시물 $postCount개',
              style:
                  TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor))
          : null,
      trailing: selected
          ? Icon(Icons.check_circle_rounded,
              color: AppTheme.primaryColor, size: 22.w)
          : Icon(Icons.circle_outlined,
              color: Colors.grey[300], size: 22.w),
      onTap: onTap,
    );
  }
}
