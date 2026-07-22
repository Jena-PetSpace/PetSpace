import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home removes the cached router listener without using disposed context',
      () {
    final home = File(
      'lib/features/social/presentation/pages/home_page.dart',
    ).readAsStringSync();
    final dispose = home.substring(
      home.indexOf('void dispose()'),
      home.indexOf('@override\n  Widget build'),
    );

    expect(home, contains('Listenable? _routerDelegate;'));
    expect(home,
        contains('_routerDelegate = GoRouter.of(context).routerDelegate'));
    expect(dispose, contains('_routerDelegate?.removeListener'));
    expect(dispose, isNot(contains('GoRouter.of(context)')));
  });
}
