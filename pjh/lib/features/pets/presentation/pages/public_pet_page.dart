import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../emotion/domain/repositories/emotion_repository.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../domain/repositories/pet_repository.dart';

class PublicPetPage extends StatefulWidget {
  final String petId;
  const PublicPetPage({super.key, required this.petId});

  @override
  State<PublicPetPage> createState() => _PublicPetPageState();
}

class _PublicPetPageState extends State<PublicPetPage> {
  Map<String, dynamic>? _pet;
  List<EmotionAnalysis> _analyses = [];
  bool _loading = true;
  bool _isFollowing = false;
  int _followerCount = 0;
  String? _currentUserId;
  String? _ownerId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _load();
  }

  Future<void> _load() async {
    try {
      final petRepo = di.sl<PetRepository>();
      final emotionRepo = di.sl<EmotionRepository>();
      final socialRepo = di.sl<SocialRepository>();

      final petResult = await petRepo.getPetDetail(widget.petId);
      final pet = petResult.fold((_) => null, (r) => r);
      final ownerId = pet?['user_id'] as String?;

      final analysesResult = await emotionRepo.getAnalysesByPet(
          petId: widget.petId, limit: 20);
      final analyses = analysesResult.fold((_) => <EmotionAnalysis>[], (r) => r);

      int followerCount = 0;
      bool isFollowing = false;
      if (ownerId != null) {
        final followersResult = await socialRepo.getFollowers(ownerId);
        followerCount =
            followersResult.fold((_) => 0, (list) => list.length);
        if (_currentUserId != null && _currentUserId != ownerId) {
          final isFollowingResult =
              await socialRepo.isFollowing(_currentUserId!, ownerId);
          isFollowing = isFollowingResult.fold((_) => false, (v) => v);
        }
      }

      if (mounted) {
        setState(() {
          _pet = pet;
          _ownerId = ownerId;
          _analyses = analyses;
          _followerCount = followerCount;
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
    if (_currentUserId == null || _ownerId == null) return;
    if (_currentUserId == _ownerId) return; // 본인은 팔로우 불가

    final socialRepo = di.sl<SocialRepository>();
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !wasFollowing;
      _followerCount += wasFollowing ? -1 : 1;
    });

    final result = wasFollowing
        ? await socialRepo.unfollowUser(_currentUserId!, _ownerId!)
        : await socialRepo.followUser(_currentUserId!, _ownerId!);
    result.fold((failure) {
      dev.log('팔로우 토글 실패: ${failure.message}', name: 'PublicPetPage');
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _followerCount += wasFollowing ? 1 : -1;
        });
      }
    }, (_) {});
  }

  void _shareProfile() {
    final link = 'https://petspace.app/pet/${widget.petId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('링크가 복사되었습니다: $link'),
        backgroundColor: Colors.white,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static const _emotionEmoji = {
    'happiness': '😊', 'sadness': '😢', 'anxiety': '😰',
    'sleepiness': '😴', 'curiosity': '🧐',
  };

  String _dominantEmotion(EmotionAnalysis a) {
    final scores = <String, double>{
      'happiness': a.emotions.happiness,
      'sadness': a.emotions.sadness,
      'anxiety': a.emotions.anxiety,
      'sleepiness': a.emotions.sleepiness,
      'curiosity': a.emotions.curiosity,
    };
    return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('반려동물 프로필')),
        body: const Center(child: Text('반려동물을 찾을 수 없습니다')),
      );
    }

    final name = _pet!['name'] as String? ?? '이름 없음';
    final species = _pet!['type'] as String? ?? _pet!['species'] as String? ?? '';
    final photoUrl = _pet!['avatar_url'] as String? ?? _pet!['photo_url'] as String?;
    final ownerName =
        (_pet!['users'] as Map?)?['display_name'] as String? ?? '';
    final isOwnPet = _currentUserId != null && _currentUserId == _ownerId;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // 헤더
          SliverAppBar(
            expandedHeight: 200.h,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryTextColor,
            actions: [
              IconButton(icon: const Icon(Icons.share_outlined), onPressed: _shareProfile),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
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
              // 통계 + 팔로우 버튼 (보호자 팔로우)
              Row(children: [
                Expanded(child: _buildStat('${_analyses.length}', '분석 횟수')),
                Container(width: 1, height: 40.h, color: AppTheme.dividerColor),
                Expanded(child: _buildStat('$_followerCount', '팔로워')),
                if (!isOwnPet) ...[
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
                        _isFollowing ? '팔로잉' : '보호자 팔로우',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: _isFollowing ? AppTheme.primaryColor : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
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
                    final emotion = _dominantEmotion(_analyses[i]);
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
