import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_state_view.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('loading state is concise and announced', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_wrap(const PetSpaceStateView.loading()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(PetSpaceStateView)),
      matchesSemantics(label: '불러오는 중', isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('empty state omits decorative icon and keeps the explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const PetSpaceStateView.empty(
          icon: Icons.pets_outlined,
          title: '아직 게시물이 없어요',
          message: '첫 게시물을 작성해 보세요.',
        ),
      ),
    );

    expect(find.text('아직 게시물이 없어요'), findsOneWidget);
    expect(find.text('첫 게시물을 작성해 보세요.'), findsOneWidget);
    expect(find.byIcon(Icons.pets_outlined), findsNothing);
  });

  testWidgets('error state announces change and provides a 44pt recovery', (
    tester,
  ) async {
    var retries = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        PetSpaceStateView.error(
          title: '불러오지 못했어요',
          message: '잠시 후 다시 시도해 주세요.',
          actionLabel: '다시 시도',
          onAction: () => retries++,
        ),
      ),
    );

    final button = find.widgetWithText(ElevatedButton, '다시 시도');
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    expect(
      tester
          .getSemantics(find.byType(PetSpaceStateView))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    await tester.tap(button);
    expect(retries, 1);
    semantics.dispose();
  });
}
