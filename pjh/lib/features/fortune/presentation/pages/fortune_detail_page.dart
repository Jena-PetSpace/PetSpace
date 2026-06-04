import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../mbti/domain/entities/pet_mbti_result.dart' show MbtiSpecies;
import '../../../mbti/presentation/theme/mbti_theme.dart';
import '../../data/datasources/fortune_content_data_source.dart';
import '../../domain/entities/daily_fortune.dart';
import '../../domain/entities/fortune_content.dart';
import '../../domain/services/fortune_generator.dart';
import '../widgets/fortune_stars.dart';

/// 운세 상세 화면.
///
/// 콘텐츠 로드 + 결정적 생성(같은 pet·같은 날 동일)을 화면에서 수행한다.
/// 서버 저장 없이 매번 재계산되며, 종합운/세부 항목/럭키/면책/공유 자리를 표시한다.
///
/// ⚠️ 동선 카드(굿즈·지도)는 이번 범위 제외 — 연결 대상(/goods·산책코스 화면)이
/// 아직 없어 보류한다. _itemsSection 아래 TODO 참고. 굿즈·지도 기능이 생기면
/// 거기서 별도로 추가한다.
class FortuneDetailPage extends StatefulWidget {
  final String petId;
  final MbtiSpecies species;
  final String dateKey; // 'YYYYMMDD' (로컬)
  final String? petName;
  final String? mbtiTypeCode; // pets.current_mbti_type 캐시(없으면 default 종합운)

  const FortuneDetailPage({
    super.key,
    required this.petId,
    required this.species,
    required this.dateKey,
    this.petName,
    this.mbtiTypeCode,
  });

  @override
  State<FortuneDetailPage> createState() => _FortuneDetailPageState();
}

class _FortuneDetailPageState extends State<FortuneDetailPage> {
  late final Future<_FortuneVM> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FortuneVM> _load() async {
    final content = await sl<FortuneContentDataSource>().loadContent();
    final fortune = sl<FortuneGenerator>().generate(
      petId: widget.petId,
      species: widget.species,
      dateKey: widget.dateKey,
      content: content,
      mbtiTypeCode: widget.mbtiTypeCode,
      petName: widget.petName,
    );
    return _FortuneVM(content: content, fortune: fortune);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MbtiTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('오늘의 운세',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: FutureBuilder<_FortuneVM>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _error(context);
          }
          return _FortuneContent(vm: snapshot.data!);
        },
      ),
    );
  }

  Widget _error(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_dissatisfied,
                size: 48.w, color: MbtiTheme.textSecondary),
            SizedBox(height: 12.h),
            Text('운세를 불러오지 못했어요.',
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

class _FortuneVM {
  final FortuneContent content;
  final DailyFortune fortune;
  const _FortuneVM({required this.content, required this.fortune});
}

class _FortuneContent extends StatelessWidget {
  final _FortuneVM vm;
  const _FortuneContent({required this.vm});

  DailyFortune get f => vm.fortune;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _hero(),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // etc 종일 때만 범용 운세 안내 칩 (강아지/고양이엔 미노출)
                      if (f.species == MbtiSpecies.etc) ...[
                        _genericChip(),
                        SizedBox(height: 16.h),
                      ],
                      _itemsSection(),
                      SizedBox(height: 24.h),
                      _luckySection(),
                      SizedBox(height: 24.h),
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

  // ── Hero: 날짜 + 종합 별점/이모지 + 종합운 문구 ──────────────
  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 28.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MbtiTheme.navy,
            MbtiTheme.navy.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            _prettyDate(f.dateKey),
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 14.h),
          Text(fortuneStarEmoji(f.overallStar),
              style: TextStyle(fontSize: 40.sp)),
          SizedBox(height: 10.h),
          // 종합 별점(세부 3개 평균) — 흰 배경 위 코랄 별
          FortuneStars(star: f.overallStar, size: 22, filledColor: Colors.white),
          SizedBox(height: 16.h),
          Text(
            f.overall,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.45,
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
          Text('범용 운세예요',
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: MbtiTheme.navy)),
        ],
      ),
    );
  }

  // ── 세부 항목 3개: 라벨 + 별점 + 문구 ──────────────────────
  // TODO(동선 카드): 굿즈·지도 기능이 생기면 이 섹션 아래에 동선 카드 추가.
  //  - 득템운(treat) 별점 4~5 → 굿즈 추천 진입
  //  - (강아지)인싸력 별점 4~5 또는 산책 관련 → 지도/산책코스 진입
  //  현재는 연결 대상 화면(/goods·산책코스)이 없어 보류(작업지시서 E. 동선 연결).
  Widget _itemsSection() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('오늘의 세부 운세'),
          SizedBox(height: 16.h),
          for (int i = 0; i < f.items.length; i++) ...[
            _itemRow(f.items[i]),
            if (i < f.items.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                child: Divider(height: 1, color: Colors.grey.shade200),
              ),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(FortuneItemResult item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item.label,
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: MbtiTheme.textPrimary),
            ),
            // 말썽 항목(사고운·냥아치력 등)도 빨강 금지 — 코랄 별로 통일
            FortuneStars(star: item.star, size: 16),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          item.phrase,
          style: TextStyle(
              fontSize: 13.sp, height: 1.5, color: MbtiTheme.textSecondary),
        ),
      ],
    );
  }

  // ── 럭키 간식 / 플레이스 ───────────────────────────────────
  Widget _luckySection() {
    return Row(
      children: [
        Expanded(
          child: _luckyCard('🍖 오늘의 럭키 간식', f.luckyTreat, MbtiTheme.coral),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _luckyCard('📍 오늘의 럭키 플레이스', f.luckyPlace, MbtiTheme.navy),
        ),
      ],
    );
  }

  Widget _luckyCard(String title, String value, Color accent) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: MbtiTheme.textSecondary)),
          SizedBox(height: 10.h),
          Text(value,
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: accent)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(width: 4.w, height: 16.h, color: MbtiTheme.coral),
        SizedBox(width: 8.w),
        Text(title,
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: MbtiTheme.textPrimary)),
      ],
    );
  }

  // ── 면책 고지 (JSON meta.disclaimer 하단 고정) ──────────────
  // 실제 AI 건강 진단과 시각적으로 구분: 무채색 박스 + ⚠️ 라벨 + 작은 회색 글씨.
  // 건강운 항목은 의도적으로 없음.
  Widget _disclaimer() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: MbtiTheme.bg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14.w, color: MbtiTheme.textSecondary),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              vm.content.disclaimer,
              style: TextStyle(
                  fontSize: 11.sp,
                  height: 1.5,
                  color: MbtiTheme.textSecondary),
            ),
          ),
        ],
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

  // ── 공유 버튼 자리 (동작은 작업 4) ─────────────────────────
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
      child: SizedBox(
        width: double.infinity,
        height: 50.h,
        child: OutlinedButton.icon(
          // TODO(작업 4): 공유 카드 캡처/공유 연결. 지금은 버튼 자리만.
          onPressed: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                content: Text('공유 기능은 곧 추가돼요 🐾'),
                duration: Duration(seconds: 2),
              ));
          },
          icon: Icon(Icons.share_outlined, size: 18.w),
          label: Text('운세 공유하기',
              style:
                  TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: MbtiTheme.navy,
            side: const BorderSide(color: MbtiTheme.navy),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r)),
          ),
        ),
      ),
    );
  }

  /// 'YYYYMMDD' → 'YYYY년 M월 D일'.
  String _prettyDate(String key) {
    if (key.length != 8) return key;
    final y = key.substring(0, 4);
    final m = int.tryParse(key.substring(4, 6)) ?? 0;
    final d = int.tryParse(key.substring(6, 8)) ?? 0;
    return '$y년 $m월 $d일';
  }
}
