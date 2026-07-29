import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/features/emotion/domain/repositories/emotion_repository.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/pages/emotion_timeline_page.dart';

class _MockEmotionRepository extends Mock implements EmotionRepository {}

void main() {
  late _MockEmotionRepository repository;

  setUp(() async {
    await sl.reset();
    repository = _MockEmotionRepository();
    sl.registerSingleton<EmotionRepository>(repository);
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('비소유 또는 삭제된 반려동물은 타임라인 RPC 전에 차단한다', (tester) async {
    when(
      () => repository.canAccessOwnedPet('pet-not-owned'),
    ).thenAnswer((_) async => const Right(false));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 800),
        builder: (_, __) => const MaterialApp(
          home: EmotionTimelinePage(
            petId: 'pet-not-owned',
            petName: '알 수 없는 반려동물',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('이 기록을 열 수 없어요'), findsOneWidget);
    expect(find.text('돌아가기'), findsOneWidget);
    verify(() => repository.canAccessOwnedPet('pet-not-owned')).called(1);
    verifyNever(
      () => repository.getEmotionTimeline(
        petId: any(named: 'petId'),
        days: any(named: 'days'),
      ),
    );
  });
}
