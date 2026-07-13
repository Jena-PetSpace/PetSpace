import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../data/datasources/mbti_content_data_source.dart';
import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../../domain/repositories/mbti_repository.dart';
import '../mbti_badge_resolver.dart';

/// 홈 MBTI 카드. 선택된 pet(PetBloc.selectedPet) 기준으로 상태 분기:
/// - 결과 없음(캐시 current_mbti_type == null) → "성격 알아보기" CTA
/// - 결과 있음 → 유형 + 별명 + 그룹색 칩, 탭 시 결과 화면 진입
///
/// 캐시 정책: current_mbti_type 캐시만 신뢰(빠른 표시). 캐시가 비어있으면
/// 결과 없음으로 간주(CTA). 캐시가 있으면 별명/그룹색은 번들 콘텐츠로 결합.
class HomeMbtiCard extends StatefulWidget {
  const HomeMbtiCard({super.key});

  @override
  State<HomeMbtiCard> createState() => _HomeMbtiCardState();
}

class _HomeMbtiCardState extends State<HomeMbtiCard> {
  MbtiContent? _content;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final content = await sl<MbtiContentDataSource>().loadContent();
      if (mounted) setState(() => _content = content);
    } catch (_) {
      // 콘텐츠 로드 실패 시 카드 자체를 숨기지 않고 CTA 만 노출(별명 생략).
    }
  }

  Pet? _selectedPet(PetState state) {
    if (state is! PetLoaded) return null;
    return state.selectedPet ?? (state.pets.isNotEmpty ? state.pets.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, state) {
        final pet = _selectedPet(state);
        if (pet == null) return const SizedBox.shrink();

        final species = MbtiSpeciesX.fromPetTypeString(pet.type.name);
        final badge = (_content != null)
            ? resolveMbtiBadge(
                typeCode: pet.currentMbtiType,
                species: species,
                content: _content!,
              )
            : null;

        // 캐시 없음 → CTA. 캐시 있고 콘텐츠 결합 성공 → 결과 카드.
        final hasResult = pet.currentMbtiType != null;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppTheme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: hasResult && badge != null
              ? _resultCard(context, pet, badge, species)
              : _ctaCard(context, pet, species),
        );
      },
    );
  }

  // ── CTA (결과 없음) ────────────────────────────────────────
  Widget _ctaCard(BuildContext context, Pet pet, MbtiSpecies species) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => _startTest(context, pet, species),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(Icons.pets, size: 22.sp, color: AppTheme.textMuted),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pet.name}의 성격 알아보기',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '20개 질문으로 MBTI 유형을 찾아봐요',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppTheme.highlightColor,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                '검사하기',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 결과 카드 (결과 있음) ──────────────────────────────────
  Widget _resultCard(
      BuildContext context, Pet pet, MbtiBadgeInfo badge, MbtiSpecies species) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => _openResult(context, pet),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            // 유형코드 원형 칩(그룹색)
            Container(
              width: 48.w,
              height: 48.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badge.groupColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                badge.typeCode,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: badge.groupColor,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pet.name}의 성격 유형',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    badge.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: badge.groupColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 22.w, color: AppTheme.secondaryTextColor),
          ],
        ),
      ),
    );
  }

  void _startTest(BuildContext context, Pet pet, MbtiSpecies species) {
    context.push(
      '/mbti?petId=${pet.id}&species=${species.key}'
      '&petName=${Uri.encodeComponent(pet.name)}',
    );
  }

  /// 결과 화면 진입 — 캐시엔 type_code 만 있으므로 최신 결과 1건을 조회해 전달.
  /// 조회 실패/없음이면 재검사 플로우로 폴백.
  Future<void> _openResult(BuildContext context, Pet pet) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final result = await sl<MbtiRepository>().getLatestResult(pet.id);
    result.fold(
      (failure) {
        messenger.showSnackBar(
            SnackBar(content: Text(failure.message)));
      },
      (res) {
        if (res != null) {
          router.push('/mbti/result', extra: res);
        } else {
          // 캐시는 있는데 원천이 없으면(이례적) 검사 재진입.
          router.push(
            '/mbti?petId=${pet.id}'
            '&species=${MbtiSpeciesX.fromPetTypeString(pet.type.name).key}'
            '&petName=${Uri.encodeComponent(pet.name)}',
          );
        }
      },
    );
  }
}
