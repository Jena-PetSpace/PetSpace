import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/edit_post_bottom_sheet.dart';

Post _legacyPrivatePost() => Post(
      id: 'post-1',
      authorId: 'author-1',
      authorName: '보리네',
      type: PostType.text,
      content: '기존 글',
      createdAt: DateTime(2026, 7, 22),
      isPublic: false,
      isPrivate: true,
    );

void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required void Function(Post post) onSave,
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
                    builder: (_) => EditPostBottomSheet(
                      post: _legacyPrivatePost(),
                      onSave: onSave,
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

  testWidgets('공개 범위를 약속하거나 바꾸지 않고 기존 값을 보존한다', (tester) async {
    Post? saved;
    await openSheet(tester, onSave: (post) => saved = post);

    expect(find.text('공개 범위 유지'), findsOneWidget);
    expect(find.textContaining('현재 값을 변경하지 않습니다'), findsOneWidget);
    expect(find.textContaining('팔로워만'), findsNothing);
    expect(find.byType(Switch), findsNothing);

    await tester.ensureVisible(find.text('저장'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.isPublic, isFalse);
    expect(saved!.isPrivate, isTrue);
  });

  testWidgets('320x568과 200% 글자에서도 안내와 저장 동작이 overflow하지 않는다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openSheet(
      tester,
      onSave: (_) {},
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('공개 범위 유지'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('다크 모드에서 시트가 테마 surface를 사용한다', (tester) async {
    final darkTheme = ThemeData.dark();
    await openSheet(
      tester,
      onSave: (_) {},
      theme: darkTheme,
    );

    final sheet = tester.widget<Container>(
      find.byKey(const Key('legacy_edit_post_sheet')),
    );
    final decoration = sheet.decoration! as BoxDecoration;
    expect(decoration.color, darkTheme.colorScheme.surface);
    expect(tester.takeException(), isNull);
  });
}
