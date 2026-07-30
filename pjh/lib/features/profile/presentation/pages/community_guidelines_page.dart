import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/app_config.dart';
import '../../../../core/constants/legal_documents.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';
import '../../../../shared/widgets/petspace_uiux_v3.dart';

/// 커뮤니티 가이드라인 페이지.
///
/// App Store Review Guideline 1.2 / Google Play UGC 정책:
///   - 금지 콘텐츠 명시
///   - 신고·차단·이의 제기 경로 안내
///   - 차단 / 신고 / 회원탈퇴 안내
class CommunityGuidelinesPage extends StatelessWidget {
  const CommunityGuidelinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PetSpaceV3Tokens.canvas,
      appBar: PetSpaceAppBar.page(
        title: '커뮤니티 가이드라인',
        backgroundColor: PetSpaceV3Tokens.canvas,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 20.h),
            for (final section in LegalDocuments.communityGuidelineSections)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _buildSection(section.title, section.items),
              ),
            _buildContactSection(),
            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return PetSpaceV3Card(
      backgroundColor: PetSpaceV3Tokens.paleBlue,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: PetSpaceV3Tokens.action,
                size: 24.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '안전한 펫페이스를 위해',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: PetSpaceV3Tokens.brandDeep,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '버전: ${LegalDocuments.communityGuidelinesVersion}\n'
            '시행일: ${LegalDocuments.communityGuidelinesEffectiveDate}\n'
            '승인자: ${LegalDocuments.communityGuidelinesApprover}',
            key: const Key('community_guidelines_metadata'),
            style: TextStyle(
              fontSize: 12.sp,
              color: PetSpaceV3Tokens.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<String> items,
  ) {
    return PetSpaceV3Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: PetSpaceV3Tokens.text,
            ),
          ),
          SizedBox(height: 10.h),
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
                        color: PetSpaceV3Tokens.action,
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
                        color: PetSpaceV3Tokens.text,
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
    return PetSpaceV3Card(
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '문의 / 추가 신고',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4.h),
          Text(
            LegalDocuments.communityGuidelinesContact,
            key: const Key('community_guidelines_contact'),
            style: TextStyle(
              fontSize: 12.sp,
              color: PetSpaceV3Tokens.textMuted,
              height: 1.5,
            ),
          ),
          SizedBox(height: 6.h),
          SelectableText(
            AppConfig.supportEmail,
            style: TextStyle(
              fontSize: 12.sp,
              color: PetSpaceV3Tokens.action,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
