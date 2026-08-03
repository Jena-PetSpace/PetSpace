import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _secretPath = 'lib/config/secrets.dart';
const _v3Import = 'petspace_uiux_v3.dart';
const _protectedScopeManifestDigest =
    'ca791eadea334a45844db77ea9d1f6b95148ee3acb8bb2a0098f0f7fde22a460';
const _protectedDigests = <String, String>{
  'lib/shared/themes/app_theme.dart':
      '53d3be329febc1b9c0e9581f707f2f5376ed74723c1a5217ca47c37649d24bcb',
  'lib/shared/widgets/petspace_page_scaffold.dart':
      'f045eeb73197ba772ea4d2155dae9f52e2e6d5b7bcc12a86d6828407adb9d8be',
  'lib/shared/widgets/petspace_app_bar.dart':
      'ee24af4abbc21e2a12af453e9fade220c4b12e470862928faef7b4ea27d4f983',
  'lib/shared/widgets/petspace_state_view.dart':
      '44f12af40d9582e064a5f4649489c89659417a088b0d6510e6b173ff3cb3308e',
  'lib/shared/widgets/petspace_bottom_action_bar.dart':
      '7face4bcb1a9c3e5f229d9b38396787ecd596438a557ab37d0f1bd78bc5958da',
  'lib/features/social/presentation/pages/home_page.dart':
      'f9b05b08e1e76f22a6e6885ceef7c92d6b56c3001a29f00563b5bf588782f133',
  'lib/features/emotion/presentation/pages/emotion_result_loader_page.dart':
      'ff32396aa434ef54b6b04b3f1918bf2121295dabf621a29e566cd8ede9c56471',
  'lib/features/emotion/presentation/pages/emotion_result_page.dart':
      'd2f4f513fd1de1bb38580332b4e0d20afc0dc850b9e263eaf3c24be357f0c102',
  'lib/features/emotion/presentation/pages/health_result_page.dart':
      '2e9f26d9691d6039bbb5bd2a508ed41c2cc6a6dfc6ca5a0e3e1a824974799e3d',
  'lib/features/emotion/presentation/theme/emotion_result_tokens.dart':
      'a0ce6f675e94c6578bbd01bd3ec3752245e11b445fbce129ad82798016b8b824',
};

void main() {
  test('frozen scope snapshot never records secret contents or hashes', () {
    final lines = File('tool/uiux_frozen_scope.sha256').readAsLinesSync();
    expect(lines.where((line) => line.contains(_secretPath)), isEmpty);
  });

  test('manifest protected SHA values match files and snapshot', () {
    final snapshot = _snapshotByPath();
    for (final entry in _protectedDigests.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is required');
      final actual = _stableTextDigest(file);
      expect(actual, entry.value, reason: '${entry.key} changed');
      expect(snapshot[entry.key], entry.value);
    }
  });

  test('all 52 protected rendering inputs match disk and full snapshot', () {
    final snapshot = _snapshotByPath();
    final protectedFile = File('tool/uiux_protected_scope.sha256');
    final protectedManifestDigest = _stableTextDigest(protectedFile);
    expect(protectedManifestDigest, _protectedScopeManifestDigest);

    final protected = _snapshotByPath(
      'tool/uiux_protected_scope.sha256',
    );
    expect(protected, hasLength(52));
    for (final entry in protected.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is required');
      final actual = _stableTextDigest(file);
      expect(actual, entry.value, reason: '${entry.key} changed');
      expect(snapshot[entry.key], entry.value);
    }
  });

  test('Home and AI result frozen surfaces cannot opt into UIUX v3', () {
    final frozenFiles = <File>[
      File('lib/features/social/presentation/pages/home_page.dart'),
      ..._requiredDartFiles('lib/features/home/presentation/widgets'),
      File(
        'lib/features/emotion/presentation/pages/'
        'emotion_result_loader_page.dart',
      ),
      File(
        'lib/features/emotion/presentation/pages/emotion_result_page.dart',
      ),
      File('lib/features/emotion/presentation/pages/health_result_page.dart'),
      File(
        'lib/features/emotion/presentation/theme/emotion_result_tokens.dart',
      ),
      ..._requiredDartFiles(
        'lib/features/emotion/presentation/widgets/result',
      ),
    ];

    for (final file in frozenFiles) {
      expect(
        file.readAsStringSync(),
        isNot(contains(_v3Import)),
        reason: '${file.path} must remain outside the opt-in UIUX v3 scope.',
      );
    }
  });

  test('AI history list widgets do not consume result-only UI components', () {
    for (final file in _requiredDartFiles(
      'lib/features/emotion/presentation/widgets/history',
    )) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('/widgets/result/')));
      expect(source, isNot(contains('emotion_result_tokens.dart')));
    }
  });

  test('opt-in UIUX v3 has no reverse dependency on existing app UI', () {
    final source =
        File('lib/shared/widgets/petspace_uiux_v3.dart').readAsStringSync();
    final imports = RegExp(
      r'''^\s*import\s+['"]([^'"]+)['"]''',
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1)).toList();

    expect(imports, ['package:flutter/material.dart']);
    expect(source, isNot(contains('AppTheme')));
    expect(source, isNot(contains('/widgets/result/')));
    expect(source, isNot(contains('petspace_state_view.dart')));
  });
}

String _stableTextDigest(File file) {
  final normalized =
      file.readAsStringSync().replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return sha256.convert(utf8.encode(normalized)).toString();
}

List<File> _requiredDartFiles(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    throw StateError('Required frozen directory is missing: $path');
  }
  final files = directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));
  if (files.isEmpty) {
    throw StateError('Required frozen directory is empty: $path');
  }
  return files;
}

Map<String, String> _snapshotByPath([
  String path = 'tool/uiux_frozen_scope.sha256',
]) {
  final result = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    final separator = line.indexOf('  ');
    if (separator < 0) continue;
    result[line.substring(separator + 2)] = line.substring(0, separator);
  }
  return result;
}
