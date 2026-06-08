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
  /// 카드 배경(연한 그레이/베이지).
  static const Color cardBg = Color(0xFFEDF1F6);

  /// 진한 남색 글자/제목.
  static const Color navy = Color(0xFF0C447C);

  /// 라벨(연한 회색-남색).
  static const Color labelColor = Color(0xFF6B7B8F);

  /// 코랄 포인트.
  static const Color coral = Color(0xFFD85A30);

  /// 인증 뱃지 파란색.
  static const Color verifiedBlue = Color(0xFF1E88E5);

  /// 한글 격자 워터마크 PNG(흰색 글자 PNG). 밝은 카드 위에선 navy 로 틴트.
  /// 파일 없으면 폴백(밝은 단색 유지).
  static const String _watermarkAsset =
      'assets/images/petspace_passport_watermark_white.png';

  /// 사진 위 원형 도장 PNG(선택, 없으면 미표시).
  static const String _stampAsset =
      'assets/images/petspace_passport_stamp.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
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
            // ── 한글 워터마크 레이어(은은). 흰색 PNG 를 navy 로 틴트해 밝은 카드에 맞춤.
            //    파일 없으면 밝은 단색 폴백.
            Positioned.fill(
              child: Opacity(
                opacity: 0.07,
                child: Image.asset(
                  _watermarkAsset,
                  fit: BoxFit.cover,
                  color: navy,
                  colorBlendMode: BlendMode.srcIn,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                  SizedBox(height: 12.h),
                  _buildBody(),
                  SizedBox(height: 10.h),
                  _buildFooter(),
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
        Text(
          '여권',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
        SizedBox(width: 5.w),
        Padding(
          padding: EdgeInsets.only(bottom: 1.h),
          child: Text(
            'PETSPORT',
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              color: labelColor,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            _countryName(pet.countryCodeOrDefault),
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 4.w),
        Flexible(
          child: Text(
            _countryEnglishName(pet.countryCodeOrDefault),
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 4.w),
        Icon(Icons.verified, size: 16.w, color: verifiedBlue),
      ],
    );
  }

  // ── 본문: 좌 사진(+도장+기분) / 우 필드 그리드 ───────────────
  Widget _buildBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPhotoColumn(),
        SizedBox(width: 14.w),
        Expanded(child: _buildFields()),
      ],
    );
  }

  Widget _buildPhotoColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 사진 + 우하단 도장 오버레이
        SizedBox(
          width: 92.w,
          height: 108.w,
          child: Stack(
            children: [
              Positioned.fill(child: _buildPhoto()),
              // 원형 도장(있을 때만). 파일 없으면 미표시.
              Positioned(
                right: -2.w,
                bottom: -2.w,
                child: Opacity(
                  opacity: 0.85,
                  child: Image.asset(
                    _stampAsset,
                    width: 40.w,
                    height: 40.w,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        // 오늘의 기분(코랄)
        _buildMood(),
      ],
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
    return Center(child: Text('🐾', style: TextStyle(fontSize: 34.sp)));
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
              style: TextStyle(fontSize: 9.sp, color: labelColor),
            ),
            SizedBox(height: 2.h),
            Text(
              '오늘 분석하기 ›',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: coral,
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
        Text('오늘의 기분', style: TextStyle(fontSize: 9.sp, color: labelColor)),
        SizedBox(height: 2.h),
        Text(
          '${m.label} ${m.percent}%',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w900,
            color: coral,
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
      ],
    );
  }

  /// 라벨(작게) + 값(굵게). 여권 양식 한 칸.
  Widget _field(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5.sp,
            fontWeight: FontWeight.w600,
            color: labelColor,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ── 푸터: 우측 코랄 버튼 + 지난 기록 보기 텍스트 ─────────────
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onHealthTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: coral,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              '오늘의 건강 관리',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(width: 14.w),
        GestureDetector(
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
