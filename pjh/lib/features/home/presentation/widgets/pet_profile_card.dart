import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../emotion/presentation/bloc/emotion_analysis_bloc.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';

class PetProfileCard extends StatefulWidget {
  const PetProfileCard({super.key});

  @override
  State<PetProfileCard> createState() => _PetProfileCardState();
}

class _PetProfileCardState extends State<PetProfileCard> {
  String? _lastLoadedPetId;

  @override
  void initState() {
    super.initState();
    _loadLatestAnalysis();
  }

  void _loadLatestAnalysis({String? petId}) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<EmotionAnalysisBloc>().add(
        LoadAnalysisHistory(userId: authState.user.uid, petId: petId, limit: 50),
      );
      _lastLoadedPetId = petId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, petState) {
        if (petState is PetLoaded && petState.pets.isNotEmpty) {
          final pet = petState.selectedPet ?? petState.pets.first;
          // 선택된 반려동물이 변경되면 감정 데이터 다시 로드
          if (_lastLoadedPetId != pet.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadLatestAnalysis(petId: pet.id);
            });
          }
          return _buildCard(context, pet, petState.pets.length > 1);
        }
        if (petState is PetOperationSuccess && petState.pets.isNotEmpty) {
          return _buildCard(context, petState.pets.first, petState.pets.length > 1);
        }
        return _buildEmptyCard(context);
      },
    );
  }

  Widget _buildCard(BuildContext context, Pet pet, bool hasMultiplePets) {
    return GestureDetector(
      onTap: () => context.push('/pets'),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          ),
        ),
        child: Column(
          children: [
            // 상단: 아바타 + 이름/정보 + 전환
            Row(
              children: [
                // 아바타
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: ClipOval(
                    child: pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: pet.avatarUrl!,
                            fit: BoxFit.cover,
                            width: 52.w,
                            height: 52.w,
                            placeholder: (_, __) => Icon(
                              Icons.pets,
                              color: Colors.white,
                              size: 24.w,
                            ),
                          )
                        : Icon(Icons.pets, color: Colors.white, size: 24.w),
                  ),
                ),
                SizedBox(width: 14.w),

                // 이름, 타입/품종/나이
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${pet.typeDisplayName} · ${pet.breed ?? '품종 미입력'} · ${pet.displayAge}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                // 전환 버튼 (항상 표시)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '전환',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.9), size: 16.w),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // 하단: 최근 감정 / 최근 스트레스 / 분석횟수
            BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
              builder: (context, emotionState) {
                String emotionText = '-';
                String emotionIcon = '';
                String stressText = '-';
                String countText = '0회';
                EmotionAnalysis? latestAnalysis;

                if (emotionState is EmotionAnalysisHistoryLoaded && emotionState.history.isNotEmpty) {
                  latestAnalysis = emotionState.history.first;
                  emotionText = _getEmotionKorean(latestAnalysis.emotions.dominantEmotion);
                  emotionIcon = _getEmotionEmoji(latestAnalysis.emotions.dominantEmotion);
                  stressText = '${latestAnalysis.emotions.stressLevel}점';
                  countText = '${emotionState.history.length}회';
                }

                return Row(
                  children: [
                    _buildInfoBox(
                      '최근 감정',
                      emotionText,
                      icon: emotionIcon,
                      onTap: latestAnalysis != null
                          ? () => _navigateToResult(context, latestAnalysis!)
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    _buildInfoBox(
                      '최근 스트레스',
                      stressText,
                      onTap: latestAnalysis != null
                          ? () => _navigateToResult(context, latestAnalysis!)
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    _buildInfoBox('분석횟수', countText),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToResult(BuildContext context, EmotionAnalysis analysis) {
    context.push('/emotion/result/${analysis.id}');
  }

  String _getEmotionKorean(String emotion) {
    switch (emotion) {
      case 'happiness': return '기쁨';
      case 'sadness': return '슬픔';
      case 'anxiety': return '불안';
      case 'sleepiness': return '졸림';
      case 'curiosity': return '호기심';
      default: return emotion;
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion) {
      case 'happiness': return '😊';
      case 'sadness': return '😢';
      case 'anxiety': return '😰';
      case 'sleepiness': return '😴';
      case 'curiosity': return '🧐';
      default: return '🐾';
    }
  }

  Widget _buildInfoBox(String label, String value, {String? icon, VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null && icon.isNotEmpty) ...[
                    Text(icon, style: TextStyle(fontSize: 12.sp)),
                    SizedBox(width: 3.w),
                  ],
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.sp,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/pets'),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.pets, color: Colors.white, size: 32.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                '반려동물을 등록해주세요',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.7), size: 16.w),
          ],
        ),
      ),
    );
  }
}
