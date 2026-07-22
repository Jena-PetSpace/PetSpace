import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/shared/models/navigation_item.dart';

void main() {
  group('root navigation contract', () {
    test('uses the approved five equal-priority destinations', () {
      expect(rootNavigationItems.map((item) => item.label), <String>[
        '홈',
        '건강',
        'AI 분석',
        '피드',
        'MY',
      ]);
      expect(
        rootNavigationItems.map((item) => item.route),
        rootNavigationPaths,
      );
    });

    test('shows the root bar only on the five exact root routes', () {
      for (final path in rootNavigationPaths) {
        expect(shouldShowRootNavigation(path), isTrue, reason: path);
        expect(shouldShowRootNavigation('$path/'), isTrue, reason: '$path/');
      }

      const taskAndDetailPaths = <String>[
        '/create-post',
        '/chat',
        '/settings/my',
        '/health/alert-settings',
        '/health/weight/add',
        '/emotion/result',
        '/feed/post-1',
        '/my/posts',
        '/my/pets/edit',
      ];
      for (final path in taskAndDetailPaths) {
        expect(shouldShowRootNavigation(path), isFalse, reason: path);
      }
    });

    test('maps root descendants to the owning tab without showing the bar', () {
      expect(navigationIndexForLocation('/home/news'), 0);
      expect(navigationIndexForLocation('/health/weight/add'), 1);
      expect(navigationIndexForLocation('/emotion/result'), 2);
      expect(navigationIndexForLocation('/feed/post-1'), 3);
      expect(navigationIndexForLocation('/my/posts'), 4);
      expect(navigationIndexForLocation('/outside', fallback: 3), 3);
    });
  });
}
