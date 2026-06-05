import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../mbti/domain/entities/pet_mbti_result.dart'
    show MbtiSpecies, MbtiSpeciesX;
import '../../../mbti/presentation/theme/mbti_theme.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../data/datasources/fortune_content_data_source.dart';
import '../../data/datasources/fortune_seen_local_data_source.dart';
import '../../domain/entities/daily_fortune.dart';
import '../../domain/services/fortune_generator.dart';
import 'fortune_stars.dart';

/// 홈 오늘의 운세 카드. selectedPet(PetBloc) 기준으로 상태 분기:
/// - 미확인(오늘 seen 키 없음) → "오늘의 운세 확인하기" CTA
/// - 확인 후 → 종합운 미리보기(한 줄) + 종합 별점/이모지 + 상세 진입
///
/// "오늘"은 로컬 자정 경계의 fortuneDateKey 로 판단 — 자정이 지나면 키가 달라져
/// 자동으로 미확인 상태로 돌아간다(새 운세). seen 키는 pet 단위라 다견·다묘 독립.
class HomeFortuneCard extends StatefulWidget {
  const HomeFortuneCard({super.key});

  @override
  State<HomeFortuneCard> createState() => _HomeFortuneCardState();
}

class _HomeFortuneCardState extends State<HomeFortuneCard> {
  /// 이번 빌드의 오늘 날짜 키(로컬). 위젯 수명 동안 고정.
  final String _today = fortuneDateKey();

  /// 과거 키 정리는 카드 수명당 1회만.
  bool _purged = false;

  /// pet 별 오늘 확인 여부 캐시(petId → seen). 비동기 조회 결과 저장.
  final Map<String, bool> _seenCache = {};

  @override
  void initState() {
    super.initState();
    _purgeOnce();
    _preloadContent();
  }

  /// 미리보기 생성을 위해 콘텐츠를 1회 로드(캐시 채움). 로드되면 리빌드.
  Future<void> _preloadContent() async {
    if (sl<FortuneContentDataSource>().tryCached() != null) return;
    try {
      await sl<FortuneContentDataSource>().loadContent();
      if (mounted) setState(() {});
    } catch (_) {
      // 로드 실패 시 미리보기는 폴백 문구로 표시(카드 자체는 유지).
    }
  }

  Future<void> _purgeOnce() async {
    if (_purged) return;
    _purged = true;
    // 과거 fortune_seen_* 키 정리(오늘 키는 보존). 실패해도 카드 동작엔 영향 없음.
    try {
      await sl<FortuneSeenLocalDataSource>().purgePastKeys(_today);
    } catch (_) {}
  }

  Pet? _selectedPet(PetState state) {
    if (state is! PetLoaded) return null;
    return state.selectedPet ??
        (state.pets.isNotEmpty ? state.pets.first : null);
  }

  /// 오늘 확인 여부 조회(캐시). 미조회면 false 로 시작하고 비동기 갱신.
  bool _isSeen(String petId) {
    final cached = _seenCache[petId];
    if (cached != null) return cached;
    sl<FortuneSeenLocalDataSource>().isSeen(petId, _today).then((v) {
      if (mounted && _seenCache[petId] != v) {
        setState(() => _seenCache[petId] = v);
      }
    });
    return false;
  }

  /// 미리보기용 운세 생성(확인 후 상태에서만 사용). 상세와 동일 값(같은 시드).
  DailyFortune? _previewFor(Pet pet, MbtiSpecies species) {
    final content = sl<FortuneContentDataSource>().tryCached();
    if (content == null) return null;
    return sl<FortuneGenerator>().generate(
      petId: pet.id,
      species: species,
      dateKey: _today,
      content: content,
      mbtiTypeCode: pet.currentMbtiType,
      petName: pet.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, state) {
        final pet = _selectedPet(state);
        if (pet == null) return const SizedBox.shrink();

        final species = MbtiSpeciesX.fromPetTypeString(pet.type.name);
        final seen = _isSeen(pet.id);

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
          child: seen
              ? _seenCard(context, pet, species)
              : _ctaCard(context, pet, species),
        );
      },
    );
  }

  // ── 미확인: "오늘의 운세 확인하기" CTA ─────────────────────
  Widget _ctaCard(BuildContext context, Pet pet, MbtiSpecies species) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => _openDetail(context, pet, species),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Text('🔮', style: TextStyle(fontSize: 22.sp)),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pet.name}의 오늘의 운세',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '오늘은 어떤 하루일까요? 운세 확인하기',
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
                '확인하기',
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

  // ── 확인 후: 종합운 미리보기 + 종합 별점/이모지 + 진입 ──────
  Widget _seenCard(BuildContext context, Pet pet, MbtiSpecies species) {
    final preview = _previewFor(pet, species);
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => _openDetail(context, pet, species),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            // 종합 별점 이모지(세부 평균 기준 — 상세와 동일 값)
            Container(
              width: 48.w,
              height: 48.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MbtiTheme.coral.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Text(
                preview != null ? fortuneStarEmoji(preview.overallStar) : '🔮',
                style: TextStyle(fontSize: 22.sp),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${pet.name}의 오늘의 운세',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                      if (preview != null) ...[
                        SizedBox(width: 6.w),
                        FortuneStars(star: preview.overallStar, size: 11),
                      ],
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    preview?.overall ?? '오늘의 운세를 확인해보세요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
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

  /// 상세 진입 — 진입 시 오늘 확인으로 기록(낙관적 캐시 갱신).
  Future<void> _openDetail(
      BuildContext context, Pet pet, MbtiSpecies species) async {
    final router = GoRouter.of(context);
    // seen 기록(오늘 키). 진입 즉시 카드가 확인-후 상태로 바뀌도록 낙관적 갱신.
    await sl<FortuneSeenLocalDataSource>().markSeen(pet.id, _today);
    if (mounted) setState(() => _seenCache[pet.id] = true);

    router.push(
      '/fortune?petId=${pet.id}&species=${species.key}&dateKey=$_today'
      '&petName=${Uri.encodeComponent(pet.name)}'
      '${pet.currentMbtiType != null ? '&mbtiType=${pet.currentMbtiType}' : ''}',
    );
  }
}
