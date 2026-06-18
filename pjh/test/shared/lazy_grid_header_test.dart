import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/shared/widgets/lazy_load_list.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          // 작은 기기 모사: 좁은 높이에서도 오버플로우 없어야 함
          body: SizedBox(height: 300, child: child),
        ),
      );

  testWidgets('header가 있으면 헤더+그리드가 한 스크롤로 렌더되고 오버플로우 없음',
      (tester) async {
    await tester.pumpWidget(host(
      LazyGridView<int>(
        header: const SizedBox(
          height: 180,
          child: Center(child: Text('PET-HEADER')),
        ),
        onLoadInitial: () async => List.generate(30, (i) => i),
        onLoadMore: () async => <int>[],
        crossAxisCount: 3,
        itemBuilder: (_, item, __) => ColoredBox(
          color: Colors.blue,
          child: Center(child: Text('item$item')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PET-HEADER'), findsOneWidget);
    // 그리드 첫 항목도 렌더(헤더 아래 그리드 존재)
    expect(find.text('item0'), findsOneWidget);
  });

  testWidgets('데이터가 0개여도 header(빈 상태 포함)는 노출된다', (tester) async {
    await tester.pumpWidget(host(
      LazyGridView<int>(
        header: const SizedBox(
          height: 180,
          child: Center(child: Text('PET-HEADER')),
        ),
        emptyWidget: const Center(child: Text('글 없음')),
        onLoadInitial: () async => <int>[],
        onLoadMore: () async => <int>[],
        crossAxisCount: 3,
        itemBuilder: (_, item, __) => const SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PET-HEADER'), findsOneWidget);
    expect(find.text('글 없음'), findsOneWidget);
  });
}
