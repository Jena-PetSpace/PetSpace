import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/error/error_messages.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../data/datasources/mbti_content_data_source.dart';
import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../../domain/repositories/mbti_repository.dart';
import '../mbti_badge_resolver.dart';

/// MY 프로필 MBTI 뱃지 섹션. PetBloc 의 pet 목록 중 MBTI 결과가 있는(캐시
/// current_mbti_type != null) pet 들의 뱃지(유형코드 + 별명 + 그룹색)를 노출.
/// 탭하면 해당 pet 결과 화면으로 이동.
///
/// 캐시 정책: 캐시만 신뢰. 결과 없는 pet 은 뱃지 미노출(섹션이 비면 섹션 자체 숨김).
class MyMbtiBadgeSection extends StatefulWidget {
  const MyMbtiBadgeSection({super.key});

  @override
  State<MyMbtiBadgeSection> createState() => _MyMbtiBadgeSectionState();
}

class _MyMbtiBadgeSectionState extends State<MyMbtiBadgeSection> {
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    if (content == null) return const SizedBox.shrink();

    return BlocBuilder<PetBloc, PetState>(
      builder: (context, state) {
        if (state is! PetLoaded) return const SizedBox.shrink();

        // 결과가 있는 pet 만(캐시 우선).
        final withResult =
            state.pets.where((p) => p.currentMbtiType != null).toList();
        if (withResult.isEmpty) return const SizedBox.shrink();

        return Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('🧬', style: TextStyle(fontSize: 15.sp)),
                  SizedBox(width: 6.w),
                  Text(
                    '성격 유형',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              ...withResult.map((pet) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: _badge(context, pet, content),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _badge(BuildContext context, Pet pet, MbtiContent content) {
    final species = MbtiSpeciesX.fromPetTypeString(pet.type.name);
    final badge = resolveMbtiBadge(
      typeCode: pet.currentMbtiType,
      species: species,
      content: content,
    );
    if (badge == null) return const SizedBox.shrink();

    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () => _openResult(context, pet),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: badge.groupColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: badge.groupColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            // 유형코드 칩(그룹색)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: badge.groupColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                badge.typeCode,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    badge.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20.w, color: AppTheme.secondaryTextColor),
          ],
        ),
      ),
    );
  }

  Future<void> _openResult(BuildContext context, Pet pet) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final result = await sl<MbtiRepository>().getLatestResult(pet.id);
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(
          content: Text(
            publicErrorMessage(
              failure.message,
              fallback: ErrorMessages.mbtiResultLoadFailed,
            ),
          ),
        ),
      ),
      (res) {
        if (res != null) {
          router.push('/mbti/result', extra: res);
        } else {
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
