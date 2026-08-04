import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const inventoryPath = '../docs/reviews/2026-08-04-full-app-uiux-inventory.md';
  const masterPath = '../docs/reviews/2026-08-04-full-app-uiux-master-plan.md';
  const expectedInventorySha =
      '4ca3e3de408e4ccaafb936912c58ce10614ce832ca83fc69eccce40aac85bc05';
  const expectedMasterSha =
      'cb7e5d28f193a4327619723f8ffed86fa355e786e49c4de5b03f6f73d5945d6a';

  test('정본과 80-screen inventory SHA가 고정돼 있다', () {
    String sha(String path) =>
        sha256.convert(File(path).readAsBytesSync()).toString();

    expect(sha(inventoryPath), expectedInventorySha);
    expect(sha(masterPath), expectedMasterSha);
  });

  test('presentation bullet과 mapping table이 정확히 같은 80개 파일이다', () {
    final source = File(inventoryPath).readAsStringSync();
    final bulletPattern = RegExp(
      r'^- `(pjh/lib/features/.+/presentation/pages/.+\.dart)`$',
      multiLine: true,
    );
    final tablePattern = RegExp(
      r'^\| `(pjh/lib/features/.+/presentation/pages/.+\.dart)` \|',
      multiLine: true,
    );
    final bullets = bulletPattern
        .allMatches(source)
        .map((match) => match.group(1)!)
        .toList();
    final table = tablePattern
        .allMatches(source)
        .map((match) => match.group(1)!)
        .toList();

    expect(bullets, hasLength(80));
    expect(table, hasLength(80));
    expect(bullets.toSet(), hasLength(80));
    expect(table.toSet(), hasLength(80));
    expect(table.toSet().difference(bullets.toSet()), isEmpty);
    expect(bullets.toSet().difference(table.toSet()), isEmpty);

    final missing = bullets
        .where((path) => !File('../$path').existsSync())
        .toList(growable: false);
    expect(missing, isEmpty);
  });
}
