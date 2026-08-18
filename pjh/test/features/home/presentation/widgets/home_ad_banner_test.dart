import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/home/presentation/widgets/home_ad_banner.dart';

void main() {
  Widget buildSubject({
    required VoidCallback onTap,
    double textScale = 1,
  }) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(
        home: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Center(child: HomeAdBanner(onTap: onTap)),
          ),
        ),
      ),
    );
  }

  testWidgets('빈 광고 플레이스홀더 대신 실제 플레이스 추천을 노출한다', (tester) async {
    await tester.pumpWidget(buildSubject(onTap: () {}));
    await tester.pump();

    expect(find.text('펫페이스 추천'), findsOneWidget);
    expect(find.text('가까운 반려동물 장소를 찾아보세요'), findsOneWidget);
    expect(find.text('동물병원부터 함께 가기 좋은 장소까지'), findsOneWidget);
    expect(find.text('광고 · 공지 배너 영역'), findsNothing);
    expect(find.text('AD'), findsNothing);
  });

  testWidgets('배너 전체가 하나의 명확한 접근성 버튼으로 동작한다', (tester) async {
    var tapped = false;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(buildSubject(onTap: () => tapped = true));
    await tester.pump();

    expect(
      find.bySemanticsLabel('펫페이스 추천, 플레이스에서 주변 반려동물 장소 찾아보기'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('home-promo-banner')));
    await tester.pump();
    expect(tapped, isTrue);

    semantics.dispose();
  });

  testWidgets('텍스트 200%에서도 overflow 없이 표시한다', (tester) async {
    await tester.pumpWidget(buildSubject(onTap: () {}, textScale: 2));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('가까운 반려동물 장소를 찾아보세요'), findsOneWidget);
  });
}
