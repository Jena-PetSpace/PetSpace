import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/shared/widgets/petspace_uiux_v3.dart';

void main() {
  Widget host(Widget child, {double textScale = 1}) {
    return MaterialApp(
      builder: (context, built) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: built!,
      ),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('card uses the opt-in surface, outline, and 12 radius', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      host(
        PetSpaceV3Card(
          semanticLabel: '반려동물 카드',
          onTap: () => taps++,
          child: const Text('보리'),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(PetSpaceV3Card),
        matching: find.byType(Material),
      ),
    );
    final shape = material.shape! as RoundedRectangleBorder;

    expect(material.color, PetSpaceV3Tokens.surface);
    expect(shape.side.color, PetSpaceV3Tokens.outline);
    expect(shape.borderRadius, BorderRadius.circular(12));
    expect(find.bySemanticsLabel('반려동물 카드'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('반려동물 카드'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    // Flutter's own semantics tests still dispatch actions through this owner.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.tap,
    );
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('primary CTA keeps contrast, tap target, and loading semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      host(
        PetSpaceV3PrimaryButton(
          label: '기록 저장',
          onPressed: () => taps++,
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(PetSpaceV3PrimaryButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, PetSpaceV3Tokens.action);
    expect(
      tester.getSize(find.byType(PetSpaceV3PrimaryButton)).height,
      greaterThanOrEqualTo(52),
    );

    final buttonNode = tester.getSemantics(find.bySemanticsLabel('기록 저장'));
    expect(
      buttonNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    // Flutter's own semantics tests still dispatch actions through this owner.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      buttonNode.id,
      SemanticsAction.tap,
    );
    expect(taps, 1);

    await tester.pumpWidget(
      host(
        PetSpaceV3PrimaryButton(
          label: '기록 저장',
          onPressed: () => taps++,
          loading: true,
        ),
      ),
    );
    final loadingNode =
        tester.getSemantics(find.bySemanticsLabel('기록 저장, 처리 중'));
    expect(
      loadingNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
    await tester.tap(find.byType(PetSpaceV3PrimaryButton));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('empty has no decorative icon and recovery states stay distinct',
      (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var retries = 0;
    await tester.pumpWidget(
      host(
        const PetSpaceV3StateView(
          kind: PetSpaceV3StateKind.empty,
          title: '아직 게시글이 없어요',
          message: '첫 게시글을 작성해보세요.',
        ),
      ),
    );
    expect(find.byType(Icon), findsNothing);

    await tester.pumpWidget(
      host(
        PetSpaceV3StateView(
          kind: PetSpaceV3StateKind.network,
          title: '연결이 불안정해요',
          message: '인터넷 연결을 확인한 뒤 다시 시도해주세요.',
          primaryActionLabel: '다시 시도',
          onPrimaryAction: () => retries++,
        ),
      ),
    );
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '연결이 불안정해요. 인터넷 연결을 확인한 뒤 다시 시도해주세요.',
      ),
      findsOneWidget,
    );
    final retryNode = tester.getSemantics(find.bySemanticsLabel('다시 시도'));
    expect(
      retryNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    // Flutter's own semantics tests still dispatch actions through this owner.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      retryNode.id,
      SemanticsAction.tap,
    );
    expect(retries, 1);
    semantics.dispose();
  });

  testWidgets('320x568 and 200% text keep the primary action reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(
        PetSpaceV3StateView(
          kind: PetSpaceV3StateKind.permission,
          title: '사진 접근 권한이 필요해요',
          message: '분석할 사진을 선택하려면 설정에서 사진 접근을 허용해주세요.',
          primaryActionLabel: '설정에서 사진 접근 권한 허용하기',
          onPrimaryAction: () {},
          secondaryActionLabel: '나중에',
          onSecondaryAction: () {},
        ),
        textScale: 2,
      ),
    );

    await tester.ensureVisible(find.text('설정에서 사진 접근 권한 허용하기'));
    expect(find.text('설정에서 사진 접근 권한 허용하기'), findsOneWidget);
    expect(find.text('나중에'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('검색 결과 없음과 차단 숨김은 서로 다른 상태 값으로 렌더링한다', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            Expanded(
              child: PetSpaceV3StateView(
                kind: PetSpaceV3StateKind.searchEmpty,
                title: '검색 결과가 없어요',
                message: '다른 검색어를 입력해보세요.',
              ),
            ),
            Expanded(
              child: PetSpaceV3StateView(
                kind: PetSpaceV3StateKind.blockedHidden,
                title: '차단한 사용자의 글을 숨겼어요',
                message: '새 글이 등록되면 표시됩니다.',
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('검색 결과가 없어요'), findsOneWidget);
    expect(find.text('차단한 사용자의 글을 숨겼어요'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('section action moves below its copy at 200% text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(
        PetSpaceV3SectionHeader(
          title: '대표 반려동물',
          description: '홈과 기록에 표시할 반려동물을 선택하세요.',
          actionLabel: '반려동물 관리',
          onAction: () {},
        ),
        textScale: 2,
      ),
    );

    final titleBottom = tester.getBottomLeft(find.text('대표 반려동물')).dy;
    final actionTop = tester.getTopLeft(find.text('반려동물 관리')).dy;
    expect(actionTop, greaterThan(titleBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('state view scrolls inside a bounded page slot', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(
        Column(
          children: [
            const Text('페이지 제목'),
            Expanded(
              child: PetSpaceV3StateView(
                kind: PetSpaceV3StateKind.server,
                title: '잠시 후 다시 시도해주세요',
                message: '요청을 처리하지 못했어요. 입력한 내용은 유지됩니다.',
                primaryActionLabel: '입력 내용을 유지하고 다시 시도하기',
                onPrimaryAction: () {},
              ),
            ),
          ],
        ),
        textScale: 2,
      ),
    );

    await tester.ensureVisible(find.text('입력 내용을 유지하고 다시 시도하기'));
    expect(find.text('입력 내용을 유지하고 다시 시도하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
