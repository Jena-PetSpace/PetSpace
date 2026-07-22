import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/health/domain/entities/health_record.dart';
import 'package:meong_nyang_diary/features/health/presentation/bloc/health_bloc.dart';
import 'package:meong_nyang_diary/features/health/presentation/pages/health_record_editor_page.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:mocktail/mocktail.dart';

class _MockHealthBloc extends Mock implements HealthBloc {}

final _pet = Pet(
  id: 'pet-1',
  userId: 'user-1',
  name: '보리',
  type: PetType.dog,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

HealthRecord _legacyVaccine() => HealthRecord(
      id: 'record-1',
      petId: _pet.id,
      userId: _pet.userId,
      recordType: HealthRecordType.vaccination,
      title: '예방접종',
      recordDate: DateTime(2026, 7, 20),
      status: HealthRecordStatus.completed,
      createdAt: DateTime(2026, 7, 20),
      updatedAt: DateTime(2026, 7, 20),
    );

Widget _wrap(_MockHealthBloc bloc, {HealthRecord? record}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      home: HealthRecordEditorPage(
        pet: _pet,
        userId: _pet.userId,
        healthBloc: bloc,
        record: record,
        now: () => DateTime(2026, 7, 22),
      ),
    ),
  );
}

void _setSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late _MockHealthBloc bloc;

  setUp(() {
    bloc = _MockHealthBloc();
    when(() => bloc.state).thenReturn(
      HealthLoaded(
        petId: _pet.id,
        userId: _pet.userId,
        records: const [],
      ),
    );
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<HealthState>.empty());
  });

  testWidgets('five type inputs retain values and validation stays inline',
      (tester) async {
    _setSurface(tester);
    await tester.pumpWidget(_wrap(bloc));

    expect(find.text('건강 기록 추가'), findsOneWidget);
    expect(find.text('어떤 기록을 남길까요?'), findsOneWidget);
    expect(find.byKey(const Key('health_vaccine_type_field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('health_editor_submit')));
    await tester.pump();
    expect(find.text('백신 종류를 입력해주세요.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('health_vaccine_type_field')),
      '종합 예방접종',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('health_record_type_selector')),
      const Offset(-180, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('health_type_weight')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('health_weight_field')),
      '5.4',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('health_record_type_selector')),
      const Offset(180, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('health_type_vaccination')));
    await tester.pump();

    final vaccineField = tester.widget<TextField>(
      find.byKey(const Key('health_vaccine_type_field')),
    );
    expect(vaccineField.controller!.text, '종합 예방접종');
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy empty vaccine opens and asks for completion only on save',
      (tester) async {
    _setSurface(tester);
    await tester.pumpWidget(_wrap(bloc, record: _legacyVaccine()));

    expect(find.text('건강 기록 수정'), findsOneWidget);
    expect(find.text('백신 종류를 입력해주세요.'), findsNothing);
    await tester.tap(find.byKey(const Key('health_editor_submit')));
    await tester.pump();
    expect(find.text('백신 종류를 입력해주세요.'), findsOneWidget);
  });

  testWidgets(
      'delete confirmation names target, downstream impact and recovery',
      (tester) async {
    _setSurface(tester);
    await tester.pumpWidget(_wrap(bloc, record: _legacyVaccine()));
    await tester.ensureVisible(find.byKey(const Key('health_editor_delete')));
    await tester.tap(find.byKey(const Key('health_editor_delete')));
    await tester.pumpAndSettle();

    expect(find.text('예방접종 기록을 삭제할까요?'), findsOneWidget);
    expect(
      find.text('2026년 7월 20일의 예방접종 기록을 삭제합니다.'),
      findsOneWidget,
    );
    expect(find.textContaining('건강 목록·변화 추이·PDF 리포트'), findsOneWidget);
    expect(find.textContaining('복구할 수 없습니다'), findsOneWidget);
  });
}
