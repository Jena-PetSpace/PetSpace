import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../fortune/data/datasources/fortune_seen_local_data_source.dart'
    show fortuneDateKey;
import '../../../mbti/domain/entities/pet_mbti_result.dart'
    show MbtiSpeciesX;
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';

/// 홈 상단 퀵 액션 — 원형 아이콘 버튼 5개 가로 배치.
/// 아이콘은 임시(Material Icons)이며, 추후 전용 일러스트/에셋으로 교체 예정.
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
        icon: Icons.place_rounded,
        label: '플레이스',
        color: AppTheme.successColor,
        onTap: () => context.push('/hospital'),
      ),
      _QuickAction(
        icon: Icons.psychology_rounded,
        label: 'MBTI 검사',
        color: AppTheme.featurePlay,
        // push로 진입해야 뒤로가기(앱·하드웨어)로 홈 복귀 가능
        onTap: () => _openMbti(context),
      ),
      _QuickAction(
        icon: Icons.directions_walk_rounded,
        label: '산책 기록',
        color: const Color(0xFF009688),
        // 미구현 — 버튼만 노출, 탭 시 안내 스낵바
        onTap: () => _showComingSoon(context),
      ),
      _QuickAction(
        icon: Icons.auto_awesome_rounded,
        label: '오늘의 운세',
        color: AppTheme.warningColor,
        onTap: () => _openFortune(context),
      ),
      _QuickAction(
        icon: Icons.quiz_rounded,
        label: 'O/X 퀴즈',
        color: AppTheme.accentColor,
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
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(action.icon, size: 24.w, color: action.color),
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
  void _openMbti(BuildContext context) {
    final pet = _selectedPet(context);
    if (pet == null) {
      _promptRegisterPet(context, 'MBTI 검사');
      return;
    }
    final species = MbtiSpeciesX.fromPetTypeString(pet.type.name);
    context.push(
      '/mbti?petId=${pet.id}&species=${species.key}'
      '&petName=${Uri.encodeComponent(pet.name)}',
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
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
