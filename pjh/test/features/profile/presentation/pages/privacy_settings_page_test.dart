import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/profile/presentation/pages/privacy_settings_page.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/blocked_user.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';

class _Repository extends Mock implements SocialRepository {}

BlockedUser _user(String id, {String? name}) => BlockedUser(
      id: id,
      blockId: 'block-$id',
      displayName: name ?? '사용자 $id',
      username: id,
      blockedAt: DateTime.utc(2026, 7, 19),
    );

Right<Failure, BlockedUsersPage> _page(
  List<BlockedUser> users, {
  BlockedUsersCursor? cursor,
}) =>
    Right(
      BlockedUsersPage(
        users: users,
        nextCursor: cursor,
      ),
    );

Widget _host(SocialRepository repository) => ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: PrivacySettingsPage(repository: repository),
      ),
    );

Widget _routerHost(SocialRepository repository) {
  final router = GoRouter(
    initialLocation: '/settings/privacy',
    routes: [
      GoRoute(
        path: '/settings/privacy',
        builder: (_, __) => PrivacySettingsPage(repository: repository),
      ),
      GoRoute(
        path: '/settings/my',
        builder: (_, __) => const Scaffold(
          body: Text('settings-route-probe', key: Key('settings-route-probe')),
        ),
      ),
    ],
  );
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late _Repository repository;

  setUp(() {
    repository = _Repository();
  });

  testWidgets('renders loaded and empty states from repository results', (
    tester,
  ) async {
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async => _page([_user('one')]));

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('blocked-user-one')), findsOneWidget);
    expect(find.text('@one'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    repository = _Repository();
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async => _page(const []));

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.text('차단한 사용자가 없습니다.'), findsOneWidget);
  });

  testWidgets('normalizes search and renders search-empty separately', (
    tester,
  ) async {
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async => _page(const []));
    when(
      () => repository.getBlockedUsers(
        query: 'nobody',
        limit: 20,
        cursor: null,
      ),
    ).thenAnswer((_) async => _page(const []));

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('blocked-user-search')), '@@@');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('차단한 사용자가 없습니다.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('blocked-user-search')),
      '  @@nobody  ',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
    verify(
      () => repository.getBlockedUsers(
        query: 'nobody',
        limit: 20,
        cursor: null,
      ),
    ).called(1);
  });

  testWidgets('initial error retries without leaving an ambiguous state', (
    tester,
  ) async {
    var calls = 0;
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async {
      calls += 1;
      return calls == 1
          ? const Left<Failure, BlockedUsersPage>(
              ServerFailure(message: 'temporary'),
            )
          : _page(const []);
    });

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();
    expect(find.text('차단 목록을 불러오지 못했습니다.'), findsOneWidget);

    final retry = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '다시 시도'),
    );
    retry.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('차단한 사용자가 없습니다.'), findsOneWidget);
  });

  testWidgets('stale search response cannot replace the newest result', (
    tester,
  ) async {
    final firstSearch = Completer<Either<Failure, BlockedUsersPage>>();
    final secondSearch = Completer<Either<Failure, BlockedUsersPage>>();
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async => _page(const []));
    when(
      () => repository.getBlockedUsers(query: 'first', limit: 20, cursor: null),
    ).thenAnswer((_) => firstSearch.future);
    when(
      () => repository.getBlockedUsers(
        query: 'second',
        limit: 20,
        cursor: null,
      ),
    ).thenAnswer((_) => secondSearch.future);

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    final search = find.byKey(const Key('blocked-user-search'));
    await tester.enterText(search, 'first');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(search, 'second');
    await tester.pump(const Duration(milliseconds: 350));

    secondSearch.complete(_page([_user('new', name: '최신 결과')]));
    await tester.pump();
    firstSearch.complete(_page([_user('old', name: '오래된 결과')]));
    await tester.pumpAndSettle();

    expect(find.text('최신 결과'), findsOneWidget);
    expect(find.text('오래된 결과'), findsNothing);
  });

  testWidgets('unblock removes only the successful item', (tester) async {
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async => _page([_user('one'), _user('two')]));
    when(
      () => repository.unblockUser('one'),
    ).thenAnswer((_) async => const Right<Failure, void>(null));
    when(
      () => repository.unblockUser('two'),
    ).thenAnswer(
      (_) async => const Left<Failure, void>(
        ServerFailure(message: 'temporary'),
      ),
    );

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('blocked-user-two')),
        matching: find.text('차단 해제'),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('blocked-user-two')), findsOneWidget);
    expect(find.text('차단을 해제하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('blocked-user-one')),
        matching: find.text('차단 해제'),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('blocked-user-one')), findsNothing);
    expect(find.byKey(const ValueKey('blocked-user-two')), findsOneWidget);
  });

  testWidgets('serializes duplicate unblock taps per user and exposes progress',
      (
    tester,
  ) async {
    final pending = Completer<Either<Failure, void>>();
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async => _page([_user('one'), _user('two')]));
    when(() => repository.unblockUser('one')).thenAnswer((_) => pending.future);

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    final firstButton = find.byKey(const ValueKey('unblock-user-one'));
    await tester.tap(firstButton);
    await tester.tap(firstButton);
    await tester.pump();

    verify(() => repository.unblockUser('one')).called(1);
    expect(find.text('해제 중'), findsOneWidget);
    expect(tester.widget<TextButton>(firstButton).onPressed, isNull);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('unblock-user-two')),
          )
          .onPressed,
      isNotNull,
    );
    final semantics = tester.getSemantics(firstButton);
    expect(semantics.label, contains('차단 해제 중'));
    expect(tester.getSize(firstButton).height, greaterThanOrEqualTo(44));

    pending.complete(const Right<Failure, void>(null));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('blocked-user-one')), findsNothing);
  });

  testWidgets(
      'root deep link back falls through to the registered settings page', (
    tester,
  ) async {
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async => _page(const []));

    await tester.pumpWidget(_routerHost(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-route-probe')), findsOneWidget);
  });

  testWidgets('load-more retries the same cursor and rejects duplicate ids', (
    tester,
  ) async {
    final cursor = BlockedUsersCursor(
      blockedAt: DateTime.utc(2026, 7, 18),
      blockId: 'cursor-row',
    );
    final firstPage = List.generate(20, (index) => _user('user-$index'));
    var loadMoreCalls = 0;
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async => _page(firstPage, cursor: cursor));
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: cursor),
    ).thenAnswer((_) async {
      loadMoreCalls += 1;
      if (loadMoreCalls == 1) {
        return const Left<Failure, BlockedUsersPage>(
          ServerFailure(message: 'temporary'),
        );
      }
      return _page([_user('user-0')]);
    });

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    final retryFinder = find.byKey(
      const Key('blocked-users-load-more-retry'),
    );
    expect(retryFinder, findsOneWidget);
    tester.widget<TextButton>(retryFinder).onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('blocked-user-user-0')), findsOneWidget);
    expect(retryFinder, findsOneWidget);
    expect(loadMoreCalls, 2);
    verify(
      () => repository.getBlockedUsers(
        query: '',
        limit: 20,
        cursor: cursor,
      ),
    ).called(2);
  });

  testWidgets('unblocking the last loaded item continues with next cursor', (
    tester,
  ) async {
    final cursor = BlockedUsersCursor(
      blockedAt: DateTime.utc(2026, 7, 18),
      blockId: 'cursor-row',
    );
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async => _page([_user('one')], cursor: cursor));
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: cursor),
    ).thenAnswer((_) async => _page([_user('next')]));
    when(
      () => repository.unblockUser('one'),
    ).thenAnswer((_) async => const Right<Failure, void>(null));

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('blocked-user-one')),
        matching: find.text('차단 해제'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('blocked-user-one')), findsNothing);
    expect(find.byKey(const ValueKey('blocked-user-next')), findsOneWidget);
  });

  testWidgets('failed continuation after unblock keeps a visible retry', (
    tester,
  ) async {
    final cursor = BlockedUsersCursor(
      blockedAt: DateTime.utc(2026, 7, 18),
      blockId: 'cursor-row',
    );
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenAnswer((_) async => _page([_user('one')], cursor: cursor));
    when(
      () => repository.getBlockedUsers(query: '', limit: 20, cursor: cursor),
    ).thenAnswer(
      (_) async => const Left<Failure, BlockedUsersPage>(
        ServerFailure(message: 'temporary'),
      ),
    );
    when(
      () => repository.unblockUser('one'),
    ).thenAnswer((_) async => const Right<Failure, void>(null));

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('blocked-user-one')),
        matching: find.text('차단 해제'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('차단 목록을 더 불러오지 못했습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('차단한 사용자가 없습니다.'), findsNothing);
  });

  test('does not use direct Supabase or local privacy toggles', () {
    final source = File(
      'lib/features/profile/presentation/pages/privacy_settings_page.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('Supabase.instance')));
    expect(source, isNot(contains('SharedPreferences')));
    expect(source, isNot(contains('SwitchListTile')));
  });
}
