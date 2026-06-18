import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../emotion/domain/repositories/emotion_repository.dart';
import '../../../health/domain/repositories/health_repository.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../utils/pet_life_summary.dart';

/// MY 탭 "내 반려동물" 요약 섹션. PetBloc의 pet 목록을 가로 스크롤 카드로 노출하고
/// 카드별로 분석 횟수·최근 감정·최근 건강 기록을 lazy 조회한다.
///
/// 고정 영역(헤더+뱃지+탭 위)에 들어가므로 컴팩트한 가로 스크롤로 세로 공간 절약.
/// emotion/health/pet 3개 도메인 읽기 전용. 펫 0마리면 등록 CTA만 노출.
class MyPetSummarySection extends StatelessWidget {
  final String userId;
  const MyPetSummarySection({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, state) {
        final pets = state is PetLoaded ? state.pets : const <Pet>[];

        return Container(
          color: AppTheme.surfaceColor,
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 0, 8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 16.w),
                child: Row(
                  children: [
                    Text('🐾', style: TextStyle(fontSize: 14.sp)),
                    SizedBox(width: 6.w),
                    Text(
                      '내 반려동물',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              if (pets.isEmpty)
                _buildEmptyState(context)
              else
                SizedBox(
                  height: 112.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(right: 16.w),
                    itemCount: pets.length,
                    separatorBuilder: (_, __) => SizedBox(width: 10.w),
                    itemBuilder: (context, i) =>
                        _PetSummaryCard(pet: pets[i], userId: userId),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 16.w),
      child: InkWell(
        onTap: () => context.push('/pets'),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppTheme.tilePastelBlue,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline,
                  color: AppTheme.primaryColor, size: 22.w),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  '반려동물을 등록하고\n분석·건강을 한눈에 관리해보세요',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.primaryTextColor,
                    height: 1.4,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.secondaryTextColor, size: 20.w),
            ],
          ),
        ),
      ),
    );
  }
}

/// 펫 1마리 요약 카드 — 분석·건강을 lazy 조회(펫 수 1~3이라 카드당 1쿼리 허용).
class _PetSummaryCard extends StatefulWidget {
  final Pet pet;
  final String userId;
  const _PetSummaryCard({required this.pet, required this.userId});

  @override
  State<_PetSummaryCard> createState() => _PetSummaryCardState();
}

class _PetSummaryCardState extends State<_PetSummaryCard> {
  late final Future<PetLifeSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<PetLifeSummary> _loadSummary() async {
    int analysisCount = 0;
    String? latestEmotion;
    String? healthTitle;
    DateTime? healthDate;

    // 분석 요약 (펫별 1쿼리)
    final emotionResult = await sl<EmotionRepository>().getAnalysisHistory(
      userId: widget.userId,
      petId: widget.pet.id,
      limit: 30,
    );
    emotionResult.fold((_) {}, (list) {
      analysisCount = list.length;
      if (list.isNotEmpty) {
        // 가장 최근(analyzedAt 내림차순 가정, 안전하게 reduce)
        final latest = list.reduce(
            (a, b) => a.analyzedAt.isAfter(b.analyzedAt) ? a : b);
        latestEmotion = latest.emotions.dominantEmotion;
      }
    });

    // 건강 요약 (펫별 1쿼리) — 최근 기록 1건
    final healthResult = await sl<HealthRepository>().getHealthRecords(
      petId: widget.pet.id,
      limit: 10,
    );
    healthResult.fold((_) {}, (list) {
      if (list.isNotEmpty) {
        final latest = list
            .reduce((a, b) => a.recordDate.isAfter(b.recordDate) ? a : b);
        healthTitle = latest.title;
        healthDate = latest.recordDate;
      }
    });

    return PetLifeSummary(
      analysisCount: analysisCount,
      latestDominantEmotion: latestEmotion,
      healthTitle: healthTitle,
      healthDate: healthDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    return GestureDetector(
      onTap: () => context.push('/pets'),
      child: Container(
        width: 230.w,
        padding: EdgeInsets.all(11.w),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 펫 기본 정보
            Row(
              children: [
                _avatar(pet),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${pet.typeDisplayName} · ${pet.displayAge}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // 분석·건강 요약 (lazy)
            FutureBuilder<PetLifeSummary>(
              future: _summaryFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return _skeletonLines();
                }
                final s = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryRow(
                      Icons.favorite_rounded,
                      AppTheme.featureEmotion,
                      s.analysisLabel,
                      cta: s.hasAnalysis ? null : '분석하러 가기',
                      onCta: () => context.push('/emotion?petId=${pet.id}'),
                    ),
                    SizedBox(height: 6.h),
                    if (s.hasHealth)
                      _summaryRow(
                        Icons.health_and_safety_rounded,
                        AppTheme.featureHealth,
                        s.healthLabelAt(DateTime.now()),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(Pet pet) {
    final url = pet.avatarUrl;
    return Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _avatarFallback(),
            )
          : _avatarFallback(),
    );
  }

  Widget _avatarFallback() => Icon(Icons.pets,
      size: 20.w, color: AppTheme.primaryColor);

  Widget _summaryRow(IconData icon, Color color, String label,
      {String? cta, VoidCallback? onCta}) {
    return Row(
      children: [
        Icon(icon, size: 14.w, color: color),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
        if (cta != null && onCta != null)
          GestureDetector(
            onTap: onCta,
            child: Text(
              cta,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _skeletonLines() {
    Widget bar(double w) => Container(
          width: w,
          height: 10.h,
          margin: EdgeInsets.only(bottom: 6.h),
          decoration: BoxDecoration(
            color: AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(4.r),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [bar(160.w), bar(120.w)],
    );
  }
}
