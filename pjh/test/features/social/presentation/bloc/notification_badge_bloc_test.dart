import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/notification_badge/notification_badge_bloc.dart';

class _MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late _MockSocialRepository repository;

  setUp(() {
    repository = _MockSocialRepository();
  });

  blocTest<NotificationBadgeBloc, NotificationBadgeState>(
    'load uses the server exact unread count',
    build: () {
      when(
        () => repository.getUnreadNotificationsCount('user-1'),
      ).thenAnswer((_) async => const Right(27));
      return NotificationBadgeBloc(socialRepository: repository);
    },
    act: (bloc) =>
        bloc.add(const NotificationBadgeLoadRequested(userId: 'user-1')),
    expect: () => const <NotificationBadgeState>[
      NotificationBadgeState(isRefreshing: true),
      NotificationBadgeState(count: 27),
    ],
    verify: (_) {
      verify(() => repository.getUnreadNotificationsCount('user-1')).called(1);
    },
  );

  blocTest<NotificationBadgeBloc, NotificationBadgeState>(
    'realtime refresh re-queries instead of incrementing cached count',
    seed: () => const NotificationBadgeState(count: 4),
    build: () {
      when(
        () => repository.getUnreadNotificationsCount('user-1'),
      ).thenAnswer((_) async => const Right(9));
      return NotificationBadgeBloc(socialRepository: repository);
    },
    act: (bloc) =>
        bloc.add(const NotificationBadgeRefreshRequested(userId: 'user-1')),
    expect: () => const <NotificationBadgeState>[
      NotificationBadgeState(count: 4, isRefreshing: true),
      NotificationBadgeState(count: 9),
    ],
  );

  blocTest<NotificationBadgeBloc, NotificationBadgeState>(
    'refresh failure keeps the previous count and exposes an error state',
    seed: () => const NotificationBadgeState(count: 6),
    build: () {
      when(() => repository.getUnreadNotificationsCount('user-1')).thenAnswer(
        (_) async =>
            const Left(ServerFailure(message: 'unread count unavailable')),
      );
      return NotificationBadgeBloc(socialRepository: repository);
    },
    act: (bloc) =>
        bloc.add(const NotificationBadgeRefreshRequested(userId: 'user-1')),
    expect: () => const <NotificationBadgeState>[
      NotificationBadgeState(count: 6, isRefreshing: true),
      NotificationBadgeState(
        count: 6,
        errorMessage: 'unread count unavailable',
      ),
    ],
  );
}
