import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/default_avatar.dart';

class PublicPetPage extends StatefulWidget {
  final String petId;
  const PublicPetPage({super.key, required this.petId});

  @override
  State<PublicPetPage> createState() => _PublicPetPageState();
}

class _PublicPetPageState extends State<PublicPetPage> {
  Map<String, dynamic>? _pet;
  List<Map<String, dynamic>> _analyses = [];
  bool _loading = true;
  bool _isFollowing = false;
  int _followerCount = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _load();
  }

  Future<void> _load() async {
    try {
      final pet = await Supabase.instance.client
          .from('pets')
          .select('*, users!pets_user_id_fkey(display_name, photo_url)')
          .eq('id', widget.petId)
          .maybeSingle();

      final analyses = await Supabase.instance.client
          .from('emotion_analyses')
          .select('id, dominant_emotion, happiness, analyzed_at')
          .eq('pet_id', widget.petId)
          .order('analyzed_at', ascending: false)
          .limit(20);

      final follows = await Supabase.instance.client
          .from('pet_follows')
          .select('id')
          .eq('pet_id', widget.petId);

      bool isFollowing = false;
      if (_currentUserId != null) {
        final myFollow = await Supabase.instance.client
            .from('pet_follows')
            .select('id')
            .eq('pet_id', widget.petId)
            .eq('follower_id', _currentUserId!)
            .maybeSingle();
        isFollowing = myFollow != null;
      }

      if (mounted) {
        setState(() {
          _pet = pet;
          _analyses = List<Map<String, dynamic>>.from(analyses);
          _followerCount = (follows as List).length;
          _isFollowing = isFollowing;
          _loading = false;
        });
      }
    } catch (e) {
      dev.log('공개 프로필 로드 실패: $e', name: 'PublicPetPage');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null) return;
    try {
      if (_isFollowing) {
        await Supabase.instance.client
            .from('pet_follows')
            .delete()
            .eq('pet_id', widget.petId)
            .eq('follower_id', _currentUserId!);
        if (mounted) setState(() { _isFollowing = false; _followerCount--; });
      } else {
        await Supabase.instance.client.from('pet_follows').insert({
          'pet_id': widget.petId,
          'follower_id': _currentUserId!,
          'created_at': DateTime.now().toIso8601String(),
        });
        if (mounted) setState(() { _isFollowing = true; _followerCount++; });
      }
    } catch (e) {
      dev.log('팔로우 오류: $e', name: 'PublicPetPage');
    }
  }

  void _shareProfile() {
    final link = 'https://petspace.app/pet/${widget.petId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('링크가 복사되었습니다: $link'),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static const _emotionEmoji = {
    'happiness': '😊', 'sadness': '😢', 'anxiety': '😰',
    'sleepiness': '😴', 'curiosity': '🧐',
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_pet == null) return Scaffold(
      appBar: AppBar(title: const Text('반려동물 프로필')),
      body: const Center(child: Text('반려동물을 찾을 수 없습니다')),
    );

    final name = _pet!['name'] as String? ?? '이름 없음';
    final species = _pet!['species'] as String? ?? '';
    final photoUrl = _pet!['photo_url'] as String?;
    final ownerName = (_pet!['users'] as Map?)?['display_name'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // 헤더
          SliverAppBar(
            expandedHeight: 200.h,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            actions: [
              IconButton(icon: const Icon(Icons.share_outlined), onPressed: _shareProfile),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 20.h),
                      // 반려동물 아바타
                      Container(
                        width: 80.w, height: 80.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipOval(
                          child: photoUrl != null && photoUrl.isNotEmpty
                              ? Image.network(photoUrl, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(child: Text('🐾', style: TextStyle(fontSize: 36))))
                              : const Center(child: Text('🐾', style: TextStyle(fontSize: 36))),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(name, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('$species · $ownerName 의 반려동물',
                        style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.75))),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(children: [
              // 통계 + 팔로우 버튼
              Row(children: [
                Expanded(child: _buildStat('${_analyses.length}', '분석 횟수')),
                Container(width: 1, height: 40.h, color: AppTheme.dividerColor),
                Expanded(child: _buildStat('$_followerCount', '팔로워')),
                SizedBox(width: 12.w),
                GestureDetector(
                  onTap: _toggleFollow,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: _isFollowing ? AppTheme.subtleBackground : AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppTheme.primaryColor),
                    ),
                    child: Text(
                      _isFollowing ? '팔로잉' : '팔로우',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: _isFollowing ? AppTheme.primaryColor : Colors.white,
                      ),
                    ),
                  ),
                ),
              ]),
              SizedBox(height: 20.h),

              if (_analyses.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('감정 기록', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                ),
                SizedBox(height: 10.h),
                GridView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, crossAxisSpacing: 8.w, mainAxisSpacing: 8.h, childAspectRatio: 1,
                  ),
                  itemCount: _analyses.length,
                  itemBuilder: (_, i) {
                    final a = _analyses[i];
                    final emotion = a['dominant_emotion'] as String? ?? 'happiness';
                    final emoji = _emotionEmoji[emotion] ?? '🐾';
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
                      ),
                      child: Center(child: Text(emoji, style: TextStyle(fontSize: 24.sp))),
                    );
                  },
                ),
              ] else
                Container(
                  padding: EdgeInsets.all(20.w),
                  child: Text('아직 감정 분석 기록이 없어요',
                    style: TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor),
                    textAlign: TextAlign.center),
                ),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
      Text(label, style: TextStyle(fontSize: 10.sp, color: AppTheme.secondaryTextColor)),
    ]);
  }
}
