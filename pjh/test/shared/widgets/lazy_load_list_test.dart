import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/shared/widgets/lazy_load_list.dart';

void main() {
  Future<void> pumpGrid(
    WidgetTester tester, {
    required Future<List<int>> Function() initial,
    Future<List<int>> Function()? more,
    Widget? header,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          home: Scaffold(
            body: LazyGridView<int>(
              onLoadInitial: initial,
              onLoadMore: more ?? () async => <int>[],
              header: header,
              emptyWidget: const Center(child: Text('EMPTY')),
              errorWidget: (retry) => Center(
                child: TextButton(
                  key: const Key('grid_retry'),
                  onPressed: retry,
                  child: const Text('ERROR_RETRY'),
                ),
              ),
              itemBuilder: (_, item, __) => Text('ITEM_$item'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('최초 조회 실패는 empty가 아닌 error와 재시도를 표시한다', (tester) async {
    var shouldFail = true;
    await pumpGrid(
      tester,
      initial: () async {
        if (shouldFail) throw StateError('internal-secret');
        return <int>[1];
      },
    );

    expect(find.text('ERROR_RETRY'), findsOneWidget);
    expect(find.text('EMPTY'), findsNothing);
    expect(find.textContaining('internal-secret'), findsNothing);

    shouldFail = false;
    await tester.tap(find.byKey(const Key('grid_retry')));
    await tester.pumpAndSettle();

    expect(find.text('ITEM_1'), findsOneWidget);
    expect(find.text('ERROR_RETRY'), findsNothing);
  });

  testWidgets('성공한 빈 응답에서만 empty를 표시한다', (tester) async {
    await pumpGrid(tester, initial: () async => <int>[]);

    expect(find.text('EMPTY'), findsOneWidget);
    expect(find.text('ERROR_RETRY'), findsNothing);
  });

  testWidgets('header 경로에서도 error와 retry가 동작한다', (tester) async {
    var calls = 0;
    await pumpGrid(
      tester,
      header: const Text('HEADER'),
      initial: () async {
        calls++;
        if (calls == 1) throw Exception('failure');
        return <int>[2];
      },
    );

    expect(find.text('HEADER'), findsOneWidget);
    expect(find.text('ERROR_RETRY'), findsOneWidget);
    await tester.tap(find.byKey(const Key('grid_retry')));
    await tester.pumpAndSettle();
    expect(find.text('ITEM_2'), findsOneWidget);
  });
}
