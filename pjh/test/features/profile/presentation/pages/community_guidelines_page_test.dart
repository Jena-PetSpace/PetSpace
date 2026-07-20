import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/config/app_config.dart';
import 'package:meong_nyang_diary/core/constants/legal_documents.dart';
import 'package:meong_nyang_diary/features/profile/presentation/pages/community_guidelines_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const CommunityGuidelinesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('승인된 버전·시행일·승인자와 지원 이메일을 표시한다', (tester) async {
    await pumpPage(tester, textScale: 1.3);

    expect(
      find.textContaining(LegalDocuments.communityGuidelinesVersion),
      findsOneWidget,
    );
    expect(
      find.textContaining(LegalDocuments.communityGuidelinesEffectiveDate),
      findsOneWidget,
    );
    expect(
      find.textContaining(LegalDocuments.communityGuidelinesApprover),
      findsOneWidget,
    );
    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
      1000,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(LegalDocuments.communityGuidelinesContact),
      findsOneWidget,
    );
    expect(find.text(AppConfig.supportEmail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('보장되지 않은 SLA·익명·즉시 영구삭제 문구를 노출하지 않는다', (tester) async {
    await pumpPage(tester);

    expect(find.textContaining('24시간 이내'), findsNothing);
    expect(find.textContaining('익명으로'), findsNothing);
    expect(find.textContaining('모두 영구 삭제'), findsNothing);
    expect(find.textContaining('7~30일'), findsNothing);
    expect(find.textContaining('운영 정책에 따라 검토합니다'), findsWidgets);
    expect(find.textContaining('30일 동안 다시 로그인'), findsOneWidget);
    expect(find.textContaining('개인정보 보호 · 차단 관리'), findsOneWidget);
  });

  test('법무 정본과 앱 설정은 동일한 지원 이메일을 사용한다', () {
    expect(LegalDocuments.supportEmail, AppConfig.supportEmail);
    expect(LegalDocuments.supportEmail, 'jera.00003@gmail.com');
  });
}
