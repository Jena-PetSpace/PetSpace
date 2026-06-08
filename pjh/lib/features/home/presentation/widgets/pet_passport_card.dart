import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../pets/domain/entities/pet.dart';

/// 펫 여권 카드의 "오늘의 기분" 표시용 데이터.
/// - [label]: 분포 1위 감정 한글명 (예: '편안함')
/// - [percent]: 그 감정의 분포 비율(0~100). ⚠️ 신뢰도(confidence) 아님 — 분포값.
/// - [emoji]: 감정 이모지
/// null 이면 "오늘 분석 없음"으로 간주하여 "오늘 분석하기" 유도.
class PassportMood {
  final String label;
  final int percent;
  final String emoji;

  const PassportMood({
    required this.label,
    required this.percent,
    required this.emoji,
  });
}

/// 홈 상단 "반려동물 여권 카드"(밝은 여권 양식).
///
/// 디자인:
/// - **밝은 카드(연한 그레이/베이지) 배경 + 진한 남색 글자.** 코랄 포인트. 빨강 금지.
/// - 훈민정음 한글 워터마크 PNG(은은) + 사진 위 원형 도장(선택). 파일 없으면 폴백.
/// - 헤더: "여권 PETSPORT" / "대한민국 REPUBLIC OF KOREA + 인증뱃지".
/// - 본문: 좌 사진 + 우 그리드(MBTI·국가코드·여권번호 / 성·이름 / 한글성명 / 생일·성별).
/// - 사진 아래 "오늘의 기분 {감정} {비율}%"(코랄). MBTI 없으면 "—".
class PetPassportCard extends StatelessWidget {
  final Pet pet;

  /// 오늘의 기분(분포 1위). null 이면 미분석 → 분석 유도.
  final PassportMood? mood;

  final VoidCallback? onHealthTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onAnalyzeTap;

  const PetPassportCard({
    super.key,
    required this.pet,
    this.mood,
    this.onHealthTap,
    this.onHistoryTap,
    this.onAnalyzeTap,
  });

  // ── 색상 팔레트(밝은 여권 양식) ──────────────────────────
  /// 카드 배경 그라데이션(좌상 연회색 → 우 연분홍/살구빛). 1번 시안 톤.
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFE7E9ED), // 좌상 연회색
      Color(0xFFF1ECEC), // 중간
      Color(0xFFFBEDE6), // 우 연분홍/살구
    ],
    stops: [0.0, 0.6, 1.0],
  );

  /// 진한 남색 글자/제목.
  static const Color navy = Color(0xFF0C447C);

  /// 라벨(연한 회색-남색) — PETSPORT/영문 국가명 등 보조 텍스트.
  static const Color labelColor = Color(0xFF6B7B8F);

  /// 필드 라벨(파란색): MBTI/국가코드/여권번호 등 항목명.
  static const Color labelBlue = Color(0xFF2C6BB3);

  /// 필드 값(검은색): 항목의 값.
  static const Color valueBlack = Color(0xFF1A1A1A);

  /// 코랄 포인트(버튼). 시안 샘플 기준 밝은 코랄.
  static const Color coral = Color(0xFFFF6F61);

  /// 오늘의 기분 강조색(살짝 진한 코랄, 가독성).
  static const Color moodCoral = Color(0xFFE8553F);

  /// 인증 뱃지 파란색.
  static const Color verifiedBlue = Color(0xFF1E88E5);

  /// 워터마크 틴트(연회색). 흰 카드 위에서 은은하게 보이는 톤.
  static const Color _watermarkTint = Color(0xFF9AA7B5);

  /// 한글 격자 워터마크 PNG(흰색 글자 PNG). 흰 카드 위에선 연회색으로 틴트.
  /// 파일 없으면 폴백(흰 단색 유지).
  static const String _watermarkAsset =
      'assets/images/petspace_passport_watermark_white.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          children: [
            // ── 한글 워터마크 레이어. 흰색 글자 PNG 를 ColorFiltered 로 회색 변환.
            //    (Image.color+srcIn 이 Impeller 에서 누락되는 케이스 → ColorFiltered 사용)
            //    글자 모양(알파)에 불투명 회색을 입힌 뒤 Opacity 로 은은하게.
            Positioned.fill(
              child: Opacity(
                opacity: 0.5,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    _watermarkTint,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    _watermarkAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            // ── 본문 ──
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  SizedBox(height: 14.h),
                  // 좌 사진 + 우 그리드(…생년월일/성별 → 오늘의 기분·건강관리)
                  _buildBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 헤더: 여권 PETSPORT / 국가명 + 인증뱃지 ─────────────────
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 좌: 여권 PETSPORT (고정폭, 공간 점유 최소화)
        Text(
          '여권',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
        SizedBox(width: 6.w),
        Padding(
          padding: EdgeInsets.only(bottom: 1.h),
          child: Text(
            'PETSPORT',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: navy,
              letterSpacing: 1.0,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        // 우: 국가명(한/영) + 인증뱃지 — 남은 공간에 맞춰 축소(잘림 방지)
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 한글명+영문명을 한 덩어리로 두고 폭 부족 시 통째로 축소.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _countryName(pet.countryCodeOrDefault),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: navy,
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        _countryEnglishName(pet.countryCodeOrDefault),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 5.w),
              Icon(Icons.verified, size: 16.w, color: verifiedBlue),
            ],
          ),
        ),
      ],
    );
  }

  // ── 본문: 좌 사진(그리드 높이에 맞춤) / 우 필드 그리드 ──────
  Widget _buildBody() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 사진 — 가로 130 고정, 세로는 그리드 전체 높이에 맞춰 늘어남.
          SizedBox(
            width: 130.w,
            child: _buildPhoto(),
          ),
          SizedBox(width: 14.w),
          Expanded(child: _buildFields()),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: navy.withValues(alpha: 0.15)),
      ),
      child: pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.network(
                pet.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultPhoto(),
              ),
            )
          : _defaultPhoto(),
    );
  }

  Widget _defaultPhoto() {
    return Center(child: Text('🐾', style: TextStyle(fontSize: 44.sp)));
  }

  // ── 오늘의 기분: 라벨 + "편안함 90%"(코랄) / 미분석 시 유도 ──
  Widget _buildMood() {
    if (mood == null) {
      return GestureDetector(
        onTap: onAnalyzeTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘의 기분',
              style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600,
                  color: labelBlue),
            ),
            SizedBox(height: 2.h),
            Text(
              '오늘 분석하기 ›',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: moodCoral,
              ),
            ),
          ],
        ),
      );
    }
    final m = mood!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘의 기분',
            style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: labelBlue)),
        SizedBox(height: 2.h),
        Text(
          '${m.label} ${m.percent}%',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w900,
            color: moodCoral,
          ),
        ),
      ],
    );
  }

  // ── 우측 필드 그리드 ───────────────────────────────────────
  Widget _buildFields() {
    final mbti = (pet.currentMbtiType != null &&
            pet.currentMbtiType!.trim().isNotEmpty)
        ? pet.currentMbtiType!
        : '—';
    final surname = pet.passportSurname?.trim();
    final given = pet.passportGivenName?.trim();
    final hanguel =
        (pet.nameHanguel != null && pet.nameHanguel!.trim().isNotEmpty)
            ? pet.nameHanguel!.trim()
            : pet.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1행: MBTI · 국가코드 · 여권번호
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _field('MBTI', mbti)),
            Expanded(flex: 4, child: _field('국가코드', pet.countryCodeOrDefault)),
            Expanded(flex: 7, child: _field('여권번호', pet.passportNo ?? '미발급')),
          ],
        ),
        SizedBox(height: 10.h),
        // 2행: 성(영문) · 이름(영문)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _field('성', surname == null || surname.isEmpty ? '—' : surname)),
            Expanded(
                flex: 2,
                child: _field('이름', given == null || given.isEmpty ? '—' : given)),
          ],
        ),
        SizedBox(height: 10.h),
        // 3행: 한글성명
        _field('한글성명', hanguel),
        SizedBox(height: 10.h),
        // 4행: 생년월일 · 성별
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _field('생년월일', _formatBirthDate(pet.birthDate))),
            Expanded(child: _field('성별', pet.genderDisplayName ?? '—')),
          ],
        ),
        SizedBox(height: 12.h),
        // 5행: 좌 오늘의 기분(생년월일 밑) / 우 건강관리 버튼
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _buildMood()),
            _buildHealthButton(),
          ],
        ),
        SizedBox(height: 6.h),
        // 지난 기록 보기(우측 정렬)
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: onHistoryTap,
            child: Text(
              '지난 기록 보기',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: labelColor,
                decoration: TextDecoration.underline,
                decorationColor: labelColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 코랄 "오늘의 건강 관리" 버튼 ───────────────────────────
  Widget _buildHealthButton() {
    return GestureDetector(
      onTap: onHealthTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: coral,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Text(
          '오늘의 건강 관리',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// 라벨(파란색) + 값(검은색). 여권 양식 한 칸.
  Widget _field(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: labelBlue,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: valueBlack,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ── 헬퍼 ────────────────────────────────────────────────
  String _formatBirthDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  static String _countryName(String code) {
    const map = {
      'KOR': '대한민국',
      'USA': '미국',
      'JPN': '일본',
      'CHN': '중국',
      'GBR': '영국',
      'DEU': '독일',
      'FRA': '프랑스',
      'CAN': '캐나다',
      'AUS': '호주',
    };
    return map[code] ?? code;
  }

  static String _countryEnglishName(String code) {
    const map = {
      'KOR': 'REPUBLIC OF KOREA',
      'USA': 'UNITED STATES',
      'JPN': 'JAPAN',
      'CHN': 'CHINA',
      'GBR': 'UNITED KINGDOM',
      'DEU': 'GERMANY',
      'FRA': 'FRANCE',
      'CAN': 'CANADA',
      'AUS': 'AUSTRALIA',
    };
    return map[code] ?? code;
  }
}
