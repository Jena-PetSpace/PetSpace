import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../fortune/data/datasources/fortune_seen_local_data_source.dart'
    show fortuneDateKey;
import '../../../mbti/domain/entities/pet_mbti_result.dart'
    show MbtiSpeciesX;
import '../../../mbti/domain/usecases/get_latest_mbti_result.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';

/// 홈 상단 퀵 액션 — 원형 아이콘 버튼 5개 가로 배치.
/// 아이콘: Lucide 스트로크 SVG(딥블루 단색) — 헤더 아이콘과 동일 계열.
///
/// MBTI·운세는 선택된 반려동물 기준으로 동작한다. 등록된 반려동물이 없으면
/// 진입을 막고 등록 화면으로 유도(반려동물 없이 운세가 생성되던 문제 방지).
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        // 플레이스 = 기존 동물병원 찾기
        asset: 'assets/svg/icon_place.svg',
        label: '플레이스',
        onTap: () => context.push('/hospital'),
      ),
      _QuickAction(
        asset: 'assets/svg/icon_mbti.svg',
        label: 'MBTI 검사',
        // push로 진입해야 뒤로가기(앱·하드웨어)로 홈 복귀 가능
        onTap: () => _openMbti(context),
      ),
      _QuickAction(
        asset: 'assets/svg/icon_walk.svg',
        label: '산책 기록',
        // 미구현 — 버튼만 노출, 탭 시 안내 스낵바
        onTap: () => _showComingSoon(context),
      ),
      _QuickAction(
        asset: 'assets/svg/icon_fortune.svg',
        label: '오늘의 운세',
        onTap: () => _openFortune(context),
      ),
      _QuickAction(
        asset: 'assets/svg/icon_quiz.svg',
        label: 'O/X 퀴즈',
        onTap: () => context.push('/quiz/play'),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Row(
        // 5개가 가로 폭에 균등하게 들어가도록 Expanded 배치
        children: actions
            .map((a) => Expanded(child: _buildItem(context, a)))
            .toList(),
      ),
    );
  }

  Widget _buildItem(BuildContext context, _QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              // 피그마 시안 방향: 무채색 배경 + 딥블루 단색 스트로크 아이콘
              color: AppTheme.border, // v2-review: ECEEF1 근사
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              action.asset,
              width: 24.w,
              height: 24.w,
              colorFilter: const ColorFilter.mode(
                AppTheme.primaryColor,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            action.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('산책 기록은 곧 추가될 예정이에요 🐾'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  // ── 반려동물 기준 진입 ────────────────────────────────────

  /// 선택된 반려동물(없으면 첫 번째). 등록된 반려동물이 없으면 null.
  Pet? _selectedPet(BuildContext context) {
    final state = context.read<PetBloc>().state;
    if (state is! PetLoaded) return null;
    return state.selectedPet ??
        (state.pets.isNotEmpty ? state.pets.first : null);
  }

  /// MBTI 검사 진입 — 반려동물 필요.
  /// 이미 검사한 적이 있으면(저장된 최신 결과 존재) 결과 페이지로 바로 이동하고,
  /// 없으면 검사 시작 페이지로 진입한다.
  /// (결과 페이지의 '다시 검사'는 /mbti로 직행하므로 재검사 동선은 유지된다.)
  Future<void> _openMbti(BuildContext context) async {
    final pet = _selectedPet(context);
    if (pet == null) {
      _promptRegisterPet(context, 'MBTI 검사');
      return;
    }
    final species = MbtiSpeciesX.fromPetTypeString(pet.type.name);
    final testRoute = '/mbti?petId=${pet.id}&species=${species.key}'
        '&petName=${Uri.encodeComponent(pet.name)}';

    // currentMbtiType이 없으면 검사 이력이 없으므로 조회 없이 바로 검사 진입.
    if (pet.currentMbtiType == null) {
      context.push(testRoute);
      return;
    }

    // 검사 이력이 있으면 저장된 최신 결과를 조회해 결과 페이지로 이동.
    final result = await sl<GetLatestMbtiResult>()(StringParams(value: pet.id));
    if (!context.mounted) return;
    result.fold(
      // 조회 실패 시 안전하게 검사 페이지로 폴백.
      (_) => context.push(testRoute),
      (latest) => latest != null
          ? context.push('/mbti/result', extra: latest)
          : context.push(testRoute),
    );
  }

  /// 오늘의 운세 진입 — 반려동물 필요(반려동물 시드 기반 생성).
  void _openFortune(BuildContext context) {
    final pet = _selectedPet(context);
    if (pet == null) {
      _promptRegisterPet(context, '오늘의 운세');
      return;
    }
    final species = MbtiSpeciesX.fromPetTypeString(pet.type.name);
    final dateKey = fortuneDateKey();
    context.push(
      '/fortune?petId=${pet.id}&species=${species.key}&dateKey=$dateKey'
      '&petName=${Uri.encodeComponent(pet.name)}'
      '${pet.currentMbtiType != null ? '&mbtiType=${pet.currentMbtiType}' : ''}',
    );
  }

  /// 반려동물 미등록 안내 — 스낵바 + 등록 화면 유도.
  void _promptRegisterPet(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature은(는) 반려동물 등록 후 이용할 수 있어요 🐾'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '등록하기',
            onPressed: () => context.push('/pets'),
          ),
        ),
      );
  }
}

class _QuickAction {
  final String asset;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.asset,
    required this.label,
    required this.onTap,
  });
}
