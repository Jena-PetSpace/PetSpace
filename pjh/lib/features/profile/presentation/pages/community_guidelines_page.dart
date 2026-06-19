import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

/// 커뮤니티 가이드라인 페이지.
///
/// App Store Review Guideline 1.2 / Google Play UGC 정책:
///   - 금지 콘텐츠 명시
///   - 신고 처리 SLA (24시간 이내)
///   - 차단 / 신고 / 회원탈퇴 안내
class CommunityGuidelinesPage extends StatelessWidget {
  const CommunityGuidelinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '커뮤니티 가이드라인',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSection('1. 환영합니다', [
              '펫페이스는 반려동물과 함께하는 일상을 안전하고 따뜻하게 나눌 수 있는 공간입니다.',
              '아래 가이드라인은 모두가 즐겁게 이용할 수 있도록 마련되었습니다.',
            ]),
            _buildSection('2. 금지되는 콘텐츠', [
              '동물 학대, 폭력, 잔혹성을 묘사하는 콘텐츠',
              '음란물, 성적 콘텐츠, 노출이 과도한 이미지',
              '혐오 표현, 차별, 괴롭힘, 인신공격',
              '욕설, 비속어, 지나친 비방',
              '스팸, 광고성 도배, 동일 콘텐츠 반복 게시',
              '타인의 개인정보(연락처, 주소, 사진 등) 무단 게시',
              '저작권 침해 콘텐츠',
              '허위 정보, 가짜 의료/수의학적 진단',
              '불법 거래(생체 매매, 마약, 무기 등) 또는 그 알선',
              '자살·자해 조장 또는 미화',
            ]),
            _buildSection('3. 위반 시 조치', [
              '경미한 위반: 콘텐츠 비공개 처리 + 사용자 안내',
              '반복 위반: 일시 정지 (7~30일)',
              '중대한 위반(불법, 학대 등): 영구 정지 및 관련 기관 신고',
              '신고된 콘텐츠는 영업일 기준 24시간 이내 검토합니다.',
            ]),
            _buildSection('4. 신고하기', [
              '게시글 / 댓글 우측 상단의 ⋮ 메뉴 → "신고"',
              '사용자 프로필 → ⋮ 메뉴 → "신고"',
              '신고 사유: 스팸, 폭력, 허위, 혐오, 개인정보 노출, 기타',
              '신고는 익명으로 처리되며, 가해자에게 신고자가 노출되지 않습니다.',
            ]),
            _buildSection('5. 차단하기', [
              '게시글 / 댓글 / 프로필의 ⋮ 메뉴 → "사용자 차단"',
              '차단된 사용자의 게시글, 댓글, 프로필은 보이지 않습니다.',
              '차단된 사용자도 회원님의 게시글을 볼 수 없습니다.',
              '차단은 언제든 [내 정보 → 설정 → 차단 목록] 에서 해제 가능합니다.',
            ]),
            _buildSection('6. 신고 처리 절차 및 응답 약속', [
              '① 신고 접수: 24시간 365일 가능',
              '② 1차 검토: 영업일 기준 24시간 이내',
              '③ 조치: 가이드라인 위반 시 즉시 콘텐츠 비공개 + 사용자 통지',
              '④ 이의 제기: 내 정보 → 도움말 → 문의하기 로 가능',
              '⑤ 긴급한 안전 위협(자해/타해 위협 등)은 즉시 검토되며, 필요 시 관계기관에 협조 요청합니다.',
            ]),
            _buildSection('7. 안전한 이용을 위한 권고', [
              '본인 또는 반려동물의 위치를 정확히 노출하지 마세요.',
              '의료/수의학적 결정은 반드시 전문가와 상의하세요. 감정분석 결과는 참고용입니다.',
              '낯선 사용자와의 거래는 안전한 방법(공공장소 만남, 직거래)을 권장합니다.',
              '불편을 겪으셨다면 즉시 신고/차단 기능을 이용해주세요.',
            ]),
            _buildSection('8. 본인의 데이터 관리', [
              '게시글/댓글은 [내 정보 → 내 게시글] 에서 직접 삭제 가능',
              '계정 전체 삭제는 [설정 → 회원탈퇴]',
              '회원탈퇴 시 게시글/댓글/감정기록/반려동물 정보 모두 영구 삭제됩니다.',
            ]),
            _buildContactSection(),
            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: AppTheme.primaryColor, size: 24.sp),
              SizedBox(width: 8.w),
              Text(
                '안전한 펫페이스를 위해',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '시행일: 2026년 5월 7일',
            style: TextStyle(fontSize: 12.sp, color: AppTheme.neutral600),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 8.h),
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 6.h, right: 8.w),
                    child: Container(
                      width: 4.w,
                      height: 4.w,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13.sp,
                        height: 1.5,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      margin: EdgeInsets.only(top: 20.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '문의 / 추가 신고',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '심각한 위반 또는 긴급 사안은 [설정 → 도움말] 에서 문의해주세요.\n앱 내 신고 기능과 별도로 직접 처리해드립니다.',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.neutral700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
