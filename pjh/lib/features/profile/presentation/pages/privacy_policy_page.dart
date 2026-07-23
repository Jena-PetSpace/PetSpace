import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/legal_documents.dart';

/// 설정 메뉴 열람용 개인정보처리방침 화면.
/// (세션4) 온보딩 동의 화면과 동일한 단일 정본(LegalDocuments.privacyPolicy)을 표시한다.
/// 이전에는 별도 요약본을 두어 온보딩본과 내용·시행일·연락처가 불일치했음 → 단일 통일.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '개인정보처리방침',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: SelectableText(
          LegalDocuments.privacyPolicy,
          style: TextStyle(
            fontSize: 13.sp,
            height: 1.6,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
