import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';

import 'package:meong_nyang_diary/features/health/presentation/pages/health_pdf_preview_page.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

final _pet = Pet(
  id: 'pet-1',
  userId: 'user-1',
  name: '보리',
  type: PetType.dog,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<void> _pumpPage(
  WidgetTester tester, {
  required HealthPdfPreviewFactory previewFactory,
  Size surface = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

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
        home: HealthPdfPreviewPage(
          pet: _pet,
          ownerName: '보호자',
          records: const [],
          previewFactory: previewFactory,
          buildPdf: (_) async => Uint8List(0),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('생성 실패 화면의 재시도는 새 generation으로 미리보기를 다시 만든다', (tester) async {
    var generations = 0;
    Widget factory({
      required Key key,
      required LayoutCallback build,
      required String fileName,
      required Widget Function(BuildContext, Object) onError,
      required void Function(BuildContext) onPrinted,
      required void Function(BuildContext, Object) onPrintError,
      required void Function(BuildContext) onShared,
      required void Function(BuildContext, Object) onShareError,
    }) {
      generations++;
      return Builder(
        key: key,
        builder: (context) => onError(context, StateError('local-test')),
      );
    }

    await _pumpPage(tester, previewFactory: factory);
    expect(generations, 1);
    expect(find.text('건강 리포트를 만들지 못했어요'), findsOneWidget);

    await tester.tap(find.text('다시 생성'));
    await tester.pump();

    expect(generations, 2);
    expect(find.text('건강 리포트를 만들지 못했어요'), findsOneWidget);
  });

  testWidgets('저장·공유 실패는 내부 오류 대신 재시도 가능한 안내만 표시한다', (tester) async {
    Widget factory({
      required Key key,
      required LayoutCallback build,
      required String fileName,
      required Widget Function(BuildContext, Object) onError,
      required void Function(BuildContext) onPrinted,
      required void Function(BuildContext, Object) onPrintError,
      required void Function(BuildContext) onShared,
      required void Function(BuildContext, Object) onShareError,
    }) {
      return Builder(
        key: key,
        builder: (context) => Column(
          children: [
            TextButton(
              key: const Key('fake_print_failure'),
              onPressed: () =>
                  onPrintError(context, StateError('private-print-error')),
              child: const Text('PRINT FAIL'),
            ),
            TextButton(
              key: const Key('fake_share_failure'),
              onPressed: () =>
                  onShareError(context, StateError('private-share-error')),
              child: const Text('SHARE FAIL'),
            ),
          ],
        ),
      );
    }

    await _pumpPage(tester, previewFactory: factory);

    await tester.tap(find.byKey(const Key('fake_print_failure')));
    await tester.pump();
    expect(
      find.text('저장·인쇄를 완료하지 못했어요. 기기 설정을 확인한 뒤 다시 시도해주세요.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-print-error'), findsNothing);

    await tester.tap(find.byKey(const Key('fake_share_failure')));
    await tester.pump();
    expect(
      find.text('공유가 완료되지 않았어요. 기기 공유 기능을 확인한 뒤 다시 시도해주세요.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-share-error'), findsNothing);
  });

  testWidgets('320x568·글자 200%에서 범위 안내와 미리보기가 겹치지 않는다', (tester) async {
    Widget factory({
      required Key key,
      required LayoutCallback build,
      required String fileName,
      required Widget Function(BuildContext, Object) onError,
      required void Function(BuildContext) onPrinted,
      required void Function(BuildContext, Object) onPrintError,
      required void Function(BuildContext) onShared,
      required void Function(BuildContext, Object) onShareError,
    }) {
      return ColoredBox(
        key: key,
        color: Colors.white,
        child: const Center(
          child: Text(
            'PDF PREVIEW',
            key: Key('fake_pdf_preview'),
          ),
        ),
      );
    }

    await _pumpPage(
      tester,
      previewFactory: factory,
      surface: const Size(320, 568),
      textScale: 2,
    );

    final notice = find.byKey(const Key('health_pdf_scope_notice'));
    final preview = find.byKey(const Key('fake_pdf_preview'));
    expect(notice, findsOneWidget);
    expect(preview, findsOneWidget);
    expect(tester.getBottomLeft(notice).dy,
        lessThan(tester.getTopLeft(preview).dy));
    expect(tester.takeException(), isNull);
  });

  test('generated report includes a reference-only disclaimer', () {
    final generator = File(
      'lib/features/health/presentation/widgets/health_pdf_generator.dart',
    ).readAsStringSync();

    expect(generator, contains('보호자가 입력한 건강 기록을 정리한 참고 자료'));
    expect(generator, contains('수의사의 판단을 대신하지 않습니다.'));
    expect(generator.toLowerCase(), isNot(contains('confidence')));
    expect(generator, isNot(contains('신뢰도')));
  });
}
