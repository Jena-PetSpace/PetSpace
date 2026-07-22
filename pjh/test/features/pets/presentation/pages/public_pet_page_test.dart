import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/pets/domain/repositories/pet_repository.dart';
import 'package:meong_nyang_diary/features/pets/presentation/pages/public_pet_page.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/follow.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockPetRepository extends Mock implements PetRepository {}

class _MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPetRepository petRepository;
  late _MockSocialRepository socialRepository;

  final petRow = <String, dynamic>{
    'id': 'pet-1',
    'user_id': 'owner-1',
    'name': '보리',
    'type': '강아지',
    'breed': '말티푸',
    'avatar_url': null,
    'users': {'display_name': '제나'},
  };

  setUp(() {
    petRepository = _MockPetRepository();
    socialRepository = _MockSocialRepository();
    when(() => petRepository.getPetDetail('pet-1'))
        .thenAnswer((_) async => Right(petRow));
    when(() => socialRepository.getFollowers('owner-1'))
        .thenAnswer((_) async => const Right(<Follow>[]));
    when(() => socialRepository.isFollowing('viewer-1', 'owner-1'))
        .thenAnswer((_) async => const Right(false));
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Future<void> Function(String)? linkCopier,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: PublicPetPage(
            petId: 'pet-1',
            petRepository: petRepository,
            socialRepository: socialRepository,
            currentUserIdProvider: () => 'viewer-1',
            linkCopier: linkCopier,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('공개 프로필은 기본 정보만 표시하고 보호 대상 AI·건강 데이터는 노출하지 않는다', (tester) async {
    await pumpPage(tester);

    expect(find.text('보리'), findsOneWidget);
    expect(find.text('말티푸 · 강아지'), findsOneWidget);
    expect(find.text('제나님의 반려동물'), findsOneWidget);
    expect(find.text('건강 기록과 AI 분석 결과는 보호자에게만 표시됩니다.'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('감정 기록'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('프로필 조회 실패와 찾을 수 없음을 구분하고 원문 오류를 숨긴다', (tester) async {
    when(() => petRepository.getPetDetail('pet-1')).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'private-db-error')),
    );
    await pumpPage(tester);

    expect(find.byKey(const Key('public_pet_error')), findsOneWidget);
    expect(find.textContaining('private-db-error'), findsNothing);

    when(() => petRepository.getPetDetail('pet-1'))
        .thenAnswer((_) async => const Right(null));
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('public_pet_not_found')), findsOneWidget);
  });

  testWidgets('팔로우는 서버 성공 뒤에만 상태와 수를 갱신한다', (tester) async {
    final completer = Completer<Either<Failure, Follow>>();
    when(() => socialRepository.followUser('viewer-1', 'owner-1'))
        .thenAnswer((_) => completer.future);
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('public_pet_follow_button')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('팔로잉'), findsNothing);

    completer.complete(
      Right(
        Follow(
          id: 'follow-1',
          followerId: 'viewer-1',
          followingId: 'owner-1',
          followerName: 'viewer',
          followingName: 'owner',
          status: FollowStatus.accepted,
          createdAt: DateTime(2026, 7, 22),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('팔로잉'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('공유는 고정 프로필 링크만 복사하고 성공 문구에 URL을 다시 노출하지 않는다', (tester) async {
    String? copied;
    await pumpPage(tester, linkCopier: (value) async => copied = value);

    await tester.tap(find.byKey(const Key('public_pet_share_button')));
    await tester.pumpAndSettle();
    expect(copied, 'https://petspace.app/pet/pet-1');
    expect(find.text('프로필 링크를 복사했어요.'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
  });
}
