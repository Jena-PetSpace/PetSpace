import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/navigation/app_router.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';

class MockAuthBloc extends Mock implements AuthBloc {}

/// 라우트 트리를 재귀 순회해 모든 GoRoute name을 수집한다.
Set<String> _collectRouteNames(List<RouteBase> routes) {
  final names = <String>{};
  for (final route in routes) {
    if (route is GoRoute && route.name != null) {
      names.add(route.name!);
    }
    names.addAll(_collectRouteNames(route.routes));
  }
  return names;
}

void main() {
  late MockAuthBloc authBloc;

  setUp(() {
    authBloc = MockAuthBloc();
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => authBloc.state).thenReturn(AuthInitial());
  });

  group('설정 라우트 일원화', () {
    test('정본 설정 라우트(my-settings)는 존재한다', () {
      final router = AppRouter.createRouter(authBloc);
      final names = _collectRouteNames(router.configuration.routes);
      expect(names.contains('my-settings'), isTrue);
    });

    test('죽은/중복 라우트는 제거되었다 (settings·settings-direct·profile)', () {
      final router = AppRouter.createRouter(authBloc);
      final names = _collectRouteNames(router.configuration.routes);
      expect(names.contains('settings'), isFalse,
          reason: '/profile 하위 죽은 settings 라우트 제거');
      expect(names.contains('settings-direct'), isFalse,
          reason: '중복 /settings 라우트 제거');
      expect(names.contains('profile'), isFalse,
          reason: '죽은 /profile(ProfilePage) 라우트 제거');
    });

    test('법적/기능 페이지 라우트는 유지된다', () {
      final router = AppRouter.createRouter(authBloc);
      final names = _collectRouteNames(router.configuration.routes);
      // 법적 페이지는 자체 경로(/privacy·/community-guidelines)로 생존
      expect(names.contains('notification-settings'), isTrue);
      expect(names.contains('privacy-settings'), isTrue);
      expect(names.contains('help-settings'), isTrue);
      // 타인 프로필 공용 UI는 유지
      expect(names.contains('user-profile'), isTrue);
    });
  });
}
