import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/create_post_bottom_sheet.dart';

void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required void Function(Post post) onPostCreated,
    TextScaler textScaler = TextScaler.noScaling,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CreatePostBottomSheet(
                      currentUserId: 'author-1',
                      onPostCreated: onPostCreated,
                    ),
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('레거시 작성 sheet도 전체 공개만 생성한다', (tester) async {
    Post? created;
    await openSheet(tester, onPostCreated: (post) => created = post);

    expect(find.text('전체 공개'), findsOneWidget);
    expect(find.textContaining('전체 공개 게시물만 지원'), findsOneWidget);
    expect(find.textContaining('팔로워만'), findsNothing);
    expect(find.byType(Switch), findsNothing);

    await tester.enterText(find.byType(TextField).first, '오늘의 산책');
    await tester.tap(find.text('게시하기'));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.isPublic, isTrue);
    expect(created!.isPrivate, isFalse);
  });

  testWidgets('320x568과 200% 글자에서도 공개 안내를 확인할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await openSheet(
      tester,
      onPostCreated: (_) {},
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('전체 공개'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('다크 모드에서 시트가 테마 surface를 사용한다', (tester) async {
    final darkTheme = ThemeData.dark();
    await openSheet(
      tester,
      onPostCreated: (_) {},
      theme: darkTheme,
    );

    final sheet = tester.widget<Container>(
      find.byKey(const Key('legacy_create_post_sheet')),
    );
    final decoration = sheet.decoration! as BoxDecoration;
    expect(decoration.color, darkTheme.colorScheme.surface);
    expect(tester.takeException(), isNull);
  });
}
