import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '개인정보처리방침',
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
            _buildSection('1. 수집하는 개인정보 항목', [
              '이메일 주소, 비밀번호 (회원가입 시)',
              '소셜 로그인 정보 (Google, Kakao 계정 연동 시)',
              '닉네임, 프로필 사진 (선택)',
              '반려동물 이름, 종류, 나이, 사진',
              '게시글, 댓글, 채팅 내용',
              '반려동물 감정 분석 이미지 및 결과',
              '건강 기록 (예방접종, 검진, 체중 등)',
              '기기 정보, 앱 사용 로그',
            ]),
            _buildSection('2. 개인정보 수집 및 이용 목적', [
              '회원 식별 및 서비스 제공',
              'AI 기반 반려동물 감정 분석 서비스',
              '커뮤니티 및 소셜 기능 제공',
              '건강 기록 관리 서비스',
              '서비스 개선 및 맞춤형 콘텐츠 제공',
              '고객 문의 응대 및 공지사항 전달',
              '부정 이용 방지 및 보안',
            ]),
            _buildSection('3. 개인정보 보유 및 이용 기간', [
              '회원 탈퇴 시까지 보유',
              '탈퇴 후 지체 없이 파기 (단, 관계 법령에 따라 보존 필요한 경우 해당 기간 보존)',
              '전자상거래 기록: 5년 (전자상거래법)',
              '접속 로그: 3개월 (통신비밀보호법)',
            ]),
            _buildSection('4. 개인정보 제3자 제공', [
              'PetSpace는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다.',
              '단, 이용자의 동의가 있거나 법령에 의해 요구되는 경우 예외적으로 제공할 수 있습니다.',
              'AI 분석 서비스: Google Gemini API (분석 이미지, 개인 식별 정보 미포함)',
              '인증 서비스: Supabase Auth (암호화된 인증 정보)',
            ]),
            _buildSection('5. 개인정보 처리 위탁', [
              'Supabase Inc. - 데이터베이스 및 인증 서비스',
              'Google LLC - AI 분석, FCM 푸시알림',
              'Kakao Corp. - 카카오 소셜 로그인',
              '위탁 업체는 위탁된 업무 수행 외 개인정보를 활용하지 않습니다.',
            ]),
            _buildSection('6. 이용자 권리', [
              '개인정보 열람 요청',
              '개인정보 수정 및 삭제 요청',
              '개인정보 처리 정지 요청',
              '동의 철회 (앱 내 회원 탈퇴 또는 고객센터 문의)',
            ]),
            _buildSection('7. 개인정보 보호 조치', [
              '비밀번호 암호화 저장 (bcrypt)',
              'HTTPS 통신 암호화',
              '접근 권한 최소화 (Row Level Security)',
              '정기적 보안 점검',
            ]),
            _buildSection('8. 개인정보 파기 방법', [
              '전자적 파일 형태: 복구 불가능한 방법으로 삭제',
              '종이 문서: 분쇄 또는 소각',
            ]),
            _buildSection('9. 개인정보 보호책임자', [
              '이름: Jena Team 개인정보 보호 담당자',
              '이메일: support@petspace.kr',
              '기타 문의: 앱 내 고객센터',
            ]),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PetSpace 개인정보처리방침',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '시행일: 2026년 4월 1일\nJena Team (이하 "회사")은 이용자의 개인정보를 중요시하며, 「개인정보보호법」을 준수합니다.',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.secondaryTextColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
        ),
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.only(left: 8.w, bottom: 6.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 5.h, right: 8.w),
                  child: Container(
                    width: 4.w,
                    height: 4.w,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryTextColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.secondaryTextColor,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackground,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        '본 방침은 2026년 4월 1일부터 시행됩니다.\n변경 사항은 앱 공지사항 또는 이메일로 사전 통보합니다.',
        style: TextStyle(
          fontSize: 11.sp,
          color: AppTheme.secondaryTextColor,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
