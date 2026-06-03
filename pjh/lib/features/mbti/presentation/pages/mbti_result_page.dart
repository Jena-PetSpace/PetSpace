import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../data/datasources/mbti_content_data_source.dart';
import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../../domain/services/mbti_scorer.dart';
import '../theme/mbti_theme.dart';
import '../widgets/mbti_axis_bar.dart';
import '../widgets/mbti_compatibility_card.dart';
import '../widgets/mbti_share_helper.dart';

/// 결과 화면. 저장된 [PetMbtiResult] + 해당 content_version 의 [MbtiContent] 를
/// 결합해 별명/소개/성격/강점/주의/추천/궁합/면책을 표시한다.
class MbtiResultPage extends StatefulWidget {
  final PetMbtiResult result;
  final String? petName;

  const MbtiResultPage({super.key, required this.result, this.petName});

  @override
  State<MbtiResultPage> createState() => _MbtiResultPageState();
}

class _MbtiResultPageState extends State<MbtiResultPage> {
  late final Future<MbtiContent> _contentFuture;

  @override
  void initState() {
    super.initState();
    // 저장된 결과의 content_version 기준으로 콘텐츠 로드(복기 호환).
    _contentFuture = sl<MbtiContentDataSource>()
        .loadContent(version: widget.result.contentVersion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MbtiTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('성격 유형 결과',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: FutureBuilder<MbtiContent>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _error();
          }
          return _ResultContent(
            result: widget.result,
            content: snapshot.data!,
            petName: widget.petName,
          );
        },
      ),
    );
  }

  Widget _error() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_dissatisfied,
                size: 48.w, color: MbtiTheme.textSecondary),
            SizedBox(height: 12.h),
            Text('결과를 불러오지 못했어요.',
                style: TextStyle(fontSize: 15.sp, color: MbtiTheme.textPrimary)),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('홈으로'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  final PetMbtiResult result;
  final MbtiContent content;
  final String? petName;

  const _ResultContent({
    required this.result,
    required this.content,
    this.petName,
  });

  @override
  Widget build(BuildContext context) {
    final typeInfo = content.typeInfo(result.typeCode);
    if (typeInfo == null) {
      return Center(
        child: Text('알 수 없는 유형: ${result.typeCode}',
            style: TextStyle(fontSize: 14.sp)),
      );
    }

    final detail = typeInfo.detailFor(result.species);
    // 그룹색은 JSON groups[].color 에서 매핑(하드코딩 금지).
    final groupColor =
        MbtiTheme.colorFromKey(content.colorForGroup(typeInfo.group));
    final compat = content.compatibilityFor(result.typeCode);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _hero(detail, typeInfo.group, groupColor),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (result.species == MbtiSpecies.etc) ...[
                        _genericChip(),
                        SizedBox(height: 16.h),
                      ],
                      _axisSection(groupColor),
                      SizedBox(height: 20.h),
                      _textSection('성격', detail.desc, groupColor),
                      SizedBox(height: 12.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _miniCard(
                                '💪 강점', detail.strength, groupColor),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _miniCard(
                                '🔍 이런 점은', detail.caution, groupColor),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _miniCard('🎾 추천 활동', detail.activity, groupColor,
                          fullWidth: true),
                      SizedBox(height: 24.h),
                      if (compat != null) ...[
                        _sectionTitle('찰떡 궁합', groupColor),
                        SizedBox(height: 12.h),
                        MbtiCompatibilityCard(
                          compatibility: compat,
                          content: content,
                          groupColor: groupColor,
                        ),
                        SizedBox(height: 24.h),
                      ],
                      _disclaimer(),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _bottomActions(context),
      ],
    );
  }

  // ── Hero: 유형코드 + 별명(큰 제목) + summary(부제) ──────────
  Widget _hero(MbtiTypeDetail detail, String group, Color groupColor) {
    final name = (petName != null && petName!.trim().isNotEmpty)
        ? petName!.trim()
        : MbtiTheme.speciesLabel(result.species);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 28.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [groupColor, groupColor.withValues(alpha: 0.82)],
        ),
      ),
      child: Column(
        children: [
          Text(
            '$name의 성격 유형',
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 10.h),
          // 유형코드 칩 + 그룹
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(100.r),
            ),
            child: Text(
              '${result.typeCode}  ·  $group',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // 별명 — 큰 제목
          Text(
            detail.nickname,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          SizedBox(height: 8.h),
          // summary — 한 줄 소개(부제)
          Text(
            detail.summary,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _genericChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: MbtiTheme.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 15.w, color: MbtiTheme.navy),
          SizedBox(width: 6.w),
          Text('범용 문항 기반 결과예요',
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: MbtiTheme.navy)),
        ],
      ),
    );
  }

  Widget _axisSection(Color groupColor) {
    const axisOrder = kMbtiAxisOrder; // EI, SN, TF, JP
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: _cardDeco(),
      child: Column(
        children: [
          for (int i = 0; i < axisOrder.length; i++) ...[
            if (content.axes[axisOrder[i]] != null &&
                result.axisScores[axisOrder[i]] != null)
              MbtiAxisBar(
                axis: content.axes[axisOrder[i]]!,
                score: result.axisScores[axisOrder[i]]!,
                groupColor: groupColor,
              ),
            if (i < axisOrder.length - 1) SizedBox(height: 18.h),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, Color groupColor) {
    return Row(
      children: [
        Container(width: 4.w, height: 16.h, color: groupColor),
        SizedBox(width: 8.w),
        Text(title,
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: MbtiTheme.textPrimary)),
      ],
    );
  }

  Widget _textSection(String title, String body, Color groupColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, groupColor),
          SizedBox(height: 10.h),
          Text(body,
              style: TextStyle(
                  fontSize: 14.sp, height: 1.6, color: MbtiTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _miniCard(String title, String body, Color groupColor,
      {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.all(14.w),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: groupColor)),
          SizedBox(height: 6.h),
          Text(body,
              style: TextStyle(
                  fontSize: 13.sp,
                  height: 1.5,
                  color: MbtiTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _disclaimer() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: MbtiTheme.bg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        content.disclaimer,
        style: TextStyle(
            fontSize: 11.sp, height: 1.5, color: MbtiTheme.textSecondary),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      );

  /// 공유 — PetBloc 에서 result.petId 의 이름/아바타를 찾아 공유 헬퍼 호출.
  void _onShare(BuildContext context) {
    String? name = petName;
    String? avatarUrl;
    final petState = context.read<PetBloc>().state;
    if (petState is PetLoaded) {
      for (final p in petState.pets) {
        if (p.id == result.petId) {
          name ??= p.name;
          avatarUrl = p.avatarUrl;
          break;
        }
      }
    }
    MbtiShareHelper.share(
      context,
      result: result,
      content: content,
      petName: name,
      petAvatarUrl: avatarUrl,
    );
  }

  Widget _bottomActions(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50.h,
              child: OutlinedButton.icon(
                onPressed: () => _onShare(context),
                icon: Icon(Icons.share_outlined, size: 18.w),
                label: Text('공유하기',
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MbtiTheme.navy,
                  side: const BorderSide(color: MbtiTheme.navy),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: SizedBox(
              height: 50.h,
              child: ElevatedButton.icon(
                onPressed: () {
                  // 다시 검사 — 검사 플로우 재진입(같은 pet/species).
                  context.pushReplacement(
                    '/mbti?petId=${result.petId}&species=${result.species.key}'
                    '${petName != null ? '&petName=${Uri.encodeComponent(petName!)}' : ''}',
                  );
                },
                icon: Icon(Icons.refresh, size: 18.w),
                label: Text('다시 검사',
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MbtiTheme.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
