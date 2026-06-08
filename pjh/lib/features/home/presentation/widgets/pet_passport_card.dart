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

/// 홈 상단 "반려동물 여권 카드".
///
/// 디자인 규칙(작업지시서 공통 원칙):
/// - 네이비(#0C447C) 배경 + 코랄(#D85A30) 포인트 + 흰 텍스트. **빨강 금지.**
/// - 훈민정음 워터마크 PNG 레이어(은은). 파일 없으면 네이비 단색 폴백.
/// - "오늘의 기분 N%" 는 감정 **분포 비율**(신뢰도 아님).
/// - MBTI 없으면 "—", 사진 없으면 기본 일러스트.
class PetPassportCard extends StatelessWidget {
  final Pet pet;

  /// 오늘의 기분(분포 1위). null 이면 미분석 → 분석 유도.
  final PassportMood? mood;

  /// "오늘의 건강 관리" 탭(코랄 버튼).
  final VoidCallback? onHealthTap;

  /// "지난 기록 보기" 탭.
  final VoidCallback? onHistoryTap;

  /// "오늘 분석하기" 탭(mood 없을 때 유도).
  final VoidCallback? onAnalyzeTap;

  const PetPassportCard({
    super.key,
    required this.pet,
    this.mood,
    this.onHealthTap,
    this.onHistoryTap,
    this.onAnalyzeTap,
  });

  /// 여권 카드 네이비 배경.
  static const Color navy = Color(0xFF0C447C);

  /// 여권 카드 코랄 포인트.
  static const Color coral = Color(0xFFD85A30);

  /// 워터마크 PNG 경로(파일 없으면 폴백). soft 버전으로 교체 가능.
  static const String _watermarkAsset =
      'assets/images/petspace_passport_watermark_white.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Stack(
          children: [
            // ── 워터마크 레이어 (은은). 파일 없으면 네이비 단색 폴백 ──
            Positioned.fill(
              child: Opacity(
                opacity: 0.10,
                child: Image.asset(
                  _watermarkAsset,
                  fit: BoxFit.cover,
                  // 안전장치: 에셋 누락 시 빈 박스 → 네이비 단색 유지.
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            // ── 본문 ──
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPassportHeader(),
                  SizedBox(height: 14.h),
                  _buildBody(),
                  SizedBox(height: 14.h),
                  Divider(
                      color: Colors.white.withValues(alpha: 0.2), height: 1),
                  SizedBox(height: 12.h),
                  _buildMoodRow(),
                  SizedBox(height: 12.h),
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 여권 헤더: "여권 PETSPORT / 국가명 ✓" ──────────────────
  Widget _buildPassportHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '여권',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            Text(
              'PETSPORT',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Text(
                  _countryName(pet.countryCodeOrDefault),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(Icons.check_circle, size: 14.w, color: coral),
              ],
            ),
            Text(
              _countryEnglishName(pet.countryCodeOrDefault),
              style: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 본문: 좌 사진 + 우 필드 ─────────────────────────────────
  Widget _buildBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPhoto(),
        SizedBox(width: 14.w),
        Expanded(child: _buildFields()),
      ],
    );
  }

  Widget _buildPhoto() {
    return Container(
      width: 76.w,
      height: 96.w,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
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
    return Center(
      child: Text('🐾', style: TextStyle(fontSize: 32.sp)),
    );
  }

  Widget _buildFields() {
    final mbti = (pet.currentMbtiType != null &&
            pet.currentMbtiType!.trim().isNotEmpty)
        ? pet.currentMbtiType!
        : '—';
    final surname = pet.passportSurname?.trim();
    final given = pet.passportGivenName?.trim();
    final englishName = [surname, given]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    final hanguel = (pet.nameHanguel != null && pet.nameHanguel!.trim().isNotEmpty)
        ? pet.nameHanguel!.trim()
        : pet.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // MBTI · 국가코드 · 여권번호
        Row(
          children: [
            _chip('MBTI $mbti'),
            SizedBox(width: 6.w),
            _chip(pet.countryCodeOrDefault),
          ],
        ),
        SizedBox(height: 8.h),
        _kv('여권번호', pet.passportNo ?? '미발급'),
        _kv('이름(한글)', hanguel),
        _kv('이름(영문)', englishName.isEmpty ? '—' : englishName),
        _kv('생년월일', _formatBirthDate(pet.birthDate)),
        _kv('성별', pet.genderDisplayName ?? '—'),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 3.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56.w,
            child: Text(
              key,
              style: TextStyle(
                fontSize: 9.sp,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── 오늘의 기분 (분포 1위 + 비율) ──────────────────────────
  Widget _buildMoodRow() {
    if (mood == null) {
      // 미분석 → "오늘 분석하기" 유도
      return GestureDetector(
        onTap: onAnalyzeTap,
        child: Row(
          children: [
            Text('🧠', style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                '오늘 기분 분석을 안 했어요',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            Text(
              '오늘 분석하기 ›',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: coral,
              ),
            ),
          ],
        ),
      );
    }

    final m = mood!;
    return Row(
      children: [
        Text(m.emoji, style: TextStyle(fontSize: 18.sp)),
        SizedBox(width: 8.w),
        Text(
          '오늘의 기분: ',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        Text(
          '${m.label} ${m.percent}%',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ── 하단 버튼: 코랄 "오늘의 건강 관리" + "지난 기록 보기" ──
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onHealthTap,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                color: coral,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
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
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: GestureDetector(
            onTap: onHistoryTap,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  '지난 기록 보기',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
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

  /// 국가코드 → 한글 국가명. 미지정 코드는 코드 그대로 표시.
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

  /// 국가코드 → 영문 국가명.
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
