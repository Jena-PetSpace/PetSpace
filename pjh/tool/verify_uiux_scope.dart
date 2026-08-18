import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const _defaultSnapshotPath = 'tool/uiux_frozen_scope.sha256';
const _defaultProtectedSnapshotPath = 'tool/uiux_protected_scope.sha256';
const _localSecretPath = 'lib/config/secrets.dart';

const _defaultEntryPoints = <String>[
  'lib/features/social/presentation/pages/home_page.dart',
  'lib/features/emotion/presentation/pages/emotion_result_loader_page.dart',
  'lib/features/emotion/presentation/pages/emotion_result_page.dart',
  'lib/features/emotion/presentation/pages/health_result_page.dart',
];

/// 앱 루트·라우터·실사용 shell과 manifest에 명시된 제외 화면을 폐포와 별도로
/// 동결한다. 이 목록은 앱 전체 import graph를 확장하지 않으면서 상위 렌더링
/// 경로가 Home/AI 결과를 간접 변경하는 우회를 막는다.
const _explicitFrozenFiles = <String>[
  'lib/main.dart',
  'lib/core/navigation/app_router.dart',
  'lib/core/navigation/auth_guard.dart',
  'lib/main_navigation.dart',
  'lib/shared/models/navigation_item.dart',
  'lib/shared/themes/app_theme.dart',
  'lib/shared/widgets/petspace_page_scaffold.dart',
  'lib/shared/widgets/petspace_app_bar.dart',
  'lib/shared/widgets/petspace_state_view.dart',
  'lib/shared/widgets/petspace_bottom_action_bar.dart',
  'lib/features/social/presentation/pages/home_page.dart',
  'lib/features/home/presentation/widgets/community_preview.dart',
  'lib/features/home/presentation/widgets/feed_preview_widget.dart',
  'lib/features/home/presentation/widgets/home_ad_banner.dart',
  'lib/features/home/presentation/widgets/home_dashboard_header.dart',
  'lib/features/home/presentation/widgets/home_news_section.dart',
  'lib/features/home/presentation/widgets/home_quest_card.dart',
  'lib/features/home/presentation/widgets/home_quick_actions.dart',
  'lib/features/home/presentation/widgets/hot_issue_card.dart',
  'lib/features/home/presentation/widgets/hot_topic_banner.dart',
  'lib/features/home/presentation/widgets/magazine_grid.dart',
  'lib/features/home/presentation/widgets/passport_mood_mapper.dart',
  'lib/features/home/presentation/widgets/pet_passport_card.dart',
  'lib/features/home/presentation/widgets/pet_passport_carousel.dart',
  'lib/features/home/presentation/widgets/pet_profile_card.dart',
  'lib/features/home/presentation/widgets/quick_actions_widget.dart',
  'lib/features/home/presentation/widgets/recent_emotion_card.dart',
  'lib/features/home/presentation/widgets/statistics_summary_card.dart',
  'lib/features/emotion/presentation/pages/emotion_result_loader_page.dart',
  'lib/features/emotion/presentation/pages/emotion_result_page.dart',
  'lib/features/emotion/presentation/pages/health_result_page.dart',
  'lib/features/emotion/presentation/theme/emotion_result_tokens.dart',
  'lib/features/emotion/presentation/widgets/result/ai_insight_card.dart',
  'lib/features/emotion/presentation/widgets/result/bottom_action_bar.dart',
  'lib/features/emotion/presentation/widgets/result/breed_guide_card.dart',
  'lib/features/emotion/presentation/widgets/result/context_card.dart',
  'lib/features/emotion/presentation/widgets/result/diagnosis_findings_card.dart',
  'lib/features/emotion/presentation/widgets/result/emotion_distribution_card.dart',
  'lib/features/emotion/presentation/widgets/result/emotion_share_card.dart',
  'lib/features/emotion/presentation/widgets/result/emotion_summary_card.dart',
  'lib/features/emotion/presentation/widgets/result/fullscreen_photo_viewer.dart',
  'lib/features/emotion/presentation/widgets/result/health_disclaimer_card.dart',
  'lib/features/emotion/presentation/widgets/result/health_findings_card.dart',
  'lib/features/emotion/presentation/widgets/result/health_next_action_card.dart',
  'lib/features/emotion/presentation/widgets/result/health_score_card.dart',
  'lib/features/emotion/presentation/widgets/result/history_result_banner.dart',
  'lib/features/emotion/presentation/widgets/result/memo_save_modal.dart',
  'lib/features/emotion/presentation/widgets/result/next_action_card.dart',
  'lib/features/emotion/presentation/widgets/result/part_analysis_card.dart',
  'lib/features/emotion/presentation/widgets/result/photo_slider.dart',
  'lib/features/emotion/presentation/widgets/result/stress_card.dart',
  'lib/features/emotion/presentation/widgets/result/vet_consult_card.dart',
];

final _directivePattern = RegExp(
  r'''^\s*(?:import|export|part)\s+([\s\S]*?);''',
  multiLine: true,
);
final _quotedUriPattern = RegExp(r'''['"]([^'"]+)['"]''');

Future<void> main(List<String> arguments) async {
  try {
    final options = _Options.parse(arguments);
    final root = options.root ?? _findFlutterRoot();

    if (!await _verifyLocalSecretBoundary(root)) {
      exitCode = 1;
      return;
    }

    final snapshot = await _buildSnapshot(
      root,
      entryPoints: options.entryPoints ?? _defaultEntryPoints,
      explicitFrozenFiles: options.explicitFrozenFiles ?? _explicitFrozenFiles,
    );

    if (options.printSnapshot) {
      stdout.write(snapshot.join('\n'));
      stdout.writeln();
      return;
    }
    if (options.writeProtectedSnapshot) {
      final protectedFile = File(
        p.join(
          root.path,
          options.protectedSnapshotPath ?? _defaultProtectedSnapshotPath,
        ),
      );
      final protectedPaths = _explicitFrozenFiles.toSet();
      final protectedLines = snapshot.where((line) {
        final separator = line.indexOf('  ');
        return separator >= 0 &&
            protectedPaths.contains(line.substring(separator + 2));
      }).toList();
      if (protectedLines.length != protectedPaths.length) {
        throw StateError('Protected rendering input set is incomplete.');
      }
      await protectedFile.writeAsString('${protectedLines.join('\n')}\n');
      stdout.writeln(
        'UI/UX protected scope snapshot updated: '
        '${protectedLines.length} inputs.',
      );
      return;
    }

    final snapshotFile = File(
      p.join(root.path, options.snapshotPath ?? _defaultSnapshotPath),
    );
    if (options.writeSnapshot) {
      await snapshotFile.writeAsString('${snapshot.join('\n')}\n');
      stdout.writeln(
        'UI/UX frozen scope snapshot updated: ${snapshot.length} inputs.',
      );
      return;
    }
    if (!snapshotFile.existsSync()) {
      stderr.writeln('UI/UX frozen scope snapshot is missing.');
      exitCode = 1;
      return;
    }

    final expected = (await snapshotFile.readAsLines())
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);

    if (_sameLines(expected, snapshot)) {
      stdout.writeln(
        'UI/UX frozen scope verified: ${snapshot.length} rendering inputs.',
      );
      return;
    }

    _reportMismatch(expected, snapshot);
    exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('UI/UX frozen scope verification could not complete.');
    if (error is StateError) {
      stderr.writeln(error.message);
    }
    exitCode = 1;
  }
}

final class _Options {
  final Directory? root;
  final String? snapshotPath;
  final String? protectedSnapshotPath;
  final List<String>? entryPoints;
  final List<String>? explicitFrozenFiles;
  final bool printSnapshot;
  final bool writeSnapshot;
  final bool writeProtectedSnapshot;

  const _Options({
    required this.root,
    required this.snapshotPath,
    required this.protectedSnapshotPath,
    required this.entryPoints,
    required this.explicitFrozenFiles,
    required this.printSnapshot,
    required this.writeSnapshot,
    required this.writeProtectedSnapshot,
  });

  factory _Options.parse(List<String> arguments) {
    Directory? root;
    String? snapshotPath;
    String? protectedSnapshotPath;
    final entryPoints = <String>[];
    final explicitFrozenFiles = <String>[];
    var printSnapshot = false;
    var writeSnapshot = false;
    var writeProtectedSnapshot = false;

    for (final argument in arguments) {
      if (argument == '--snapshot') {
        printSnapshot = true;
      } else if (argument == '--write-snapshot') {
        writeSnapshot = true;
      } else if (argument == '--write-protected-snapshot') {
        writeProtectedSnapshot = true;
      } else if (argument.startsWith('--root=')) {
        root = Directory(argument.substring('--root='.length)).absolute;
      } else if (argument.startsWith('--snapshot-file=')) {
        snapshotPath = argument.substring('--snapshot-file='.length);
      } else if (argument.startsWith('--protected-snapshot-file=')) {
        protectedSnapshotPath = argument.substring(
          '--protected-snapshot-file='.length,
        );
      } else if (argument.startsWith('--entry=')) {
        entryPoints.add(argument.substring('--entry='.length));
      } else if (argument.startsWith('--explicit=')) {
        explicitFrozenFiles.add(argument.substring('--explicit='.length));
      } else {
        throw StateError('Unsupported verifier option.');
      }
    }
    if ([
          printSnapshot,
          writeSnapshot,
          writeProtectedSnapshot,
        ].where((enabled) => enabled).length >
        1) {
      throw StateError('Choose one snapshot output mode.');
    }

    return _Options(
      root: root,
      snapshotPath: snapshotPath,
      protectedSnapshotPath: protectedSnapshotPath,
      entryPoints: entryPoints.isEmpty ? null : entryPoints,
      explicitFrozenFiles: explicitFrozenFiles.isEmpty
          ? null
          : explicitFrozenFiles,
      printSnapshot: printSnapshot,
      writeSnapshot: writeSnapshot,
      writeProtectedSnapshot: writeProtectedSnapshot,
    );
  }
}

Directory _findFlutterRoot() {
  var current = Directory.current.absolute;
  while (true) {
    if (File(p.join(current.path, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(current.path, 'lib')).existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('Flutter project root not found.');
    }
    current = parent;
  }
}

Future<List<String>> _buildSnapshot(
  Directory root, {
  required List<String> entryPoints,
  required List<String> explicitFrozenFiles,
}) async {
  final dartClosure = await _collectDartClosure(root, entryPoints);
  final inputs = <String>{...dartClosure, ...explicitFrozenFiles};

  for (final path in ['pubspec.yaml', 'pubspec.lock']) {
    _requireFile(root, path);
    inputs.add(path);
  }

  await _addRequiredFilesBelow(
    root: root,
    directory: 'lib/l10n',
    target: inputs,
    where: (path) => path.endsWith('.arb'),
  );
  await _addRequiredFilesBelow(
    root: root,
    directory: 'assets',
    target: inputs,
    where: (_) => true,
  );

  final sorted = inputs.where((path) => !_isSensitivePath(path)).toList()
    ..sort();
  final lines = <String>[];
  for (final relativePath in sorted) {
    final file = _requireFile(root, relativePath);
    final digest = sha256.convert(await _stableBytes(file, relativePath));
    lines.add('$digest  $relativePath');
  }
  return lines;
}

Future<List<int>> _stableBytes(File file, String relativePath) async {
  if (_isBinaryRenderingInput(relativePath)) {
    return file.readAsBytes();
  }
  final normalized = (await file.readAsString())
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  return utf8.encode(normalized);
}

bool _isBinaryRenderingInput(String relativePath) {
  const binaryExtensions = <String>{
    '.avif',
    '.gif',
    '.ico',
    '.jpeg',
    '.jpg',
    '.otf',
    '.pdf',
    '.png',
    '.ttf',
    '.webp',
    '.woff',
    '.woff2',
  };
  return binaryExtensions.contains(
    p.posix.extension(relativePath.toLowerCase()),
  );
}

Future<Set<String>> _collectDartClosure(
  Directory root,
  List<String> entryPoints,
) async {
  final seen = <String>{};
  final pending = <String>[...entryPoints];

  while (pending.isNotEmpty) {
    final current = p.posix.normalize(pending.removeLast());
    if (_isSensitivePath(current) || !seen.add(current)) continue;

    final file = _requireFile(root, current);
    final source = await file.readAsString();

    for (final directive in _directivePattern.allMatches(source)) {
      final body = directive.group(1)!;
      for (final uriMatch in _quotedUriPattern.allMatches(body)) {
        final resolved = _resolveLocalDartImport(current, uriMatch.group(1)!);
        if (resolved != null &&
            !_isSensitivePath(resolved) &&
            !seen.contains(resolved)) {
          pending.add(resolved);
        }
      }
    }
  }

  return seen;
}

String? _resolveLocalDartImport(String importer, String uri) {
  const packagePrefix = 'package:meong_nyang_diary/';
  if (uri.startsWith(packagePrefix)) {
    return p.posix.normalize('lib/${uri.substring(packagePrefix.length)}');
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) return null;
  if (uri.contains(':')) return null;
  return p.posix.normalize(p.posix.join(p.posix.dirname(importer), uri));
}

Future<void> _addRequiredFilesBelow({
  required Directory root,
  required String directory,
  required Set<String> target,
  required bool Function(String path) where,
}) async {
  final base = Directory(p.join(root.path, directory));
  if (!base.existsSync()) {
    throw StateError('Required rendering input directory is missing.');
  }

  var added = 0;
  await for (final entity in base.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = p
        .relative(entity.path, from: root.path)
        .split(p.separator)
        .join('/');
    if (_isSensitivePath(relative) || !where(relative)) continue;
    target.add(relative);
    added++;
  }
  if (added == 0) {
    throw StateError('Required rendering input directory is empty.');
  }
}

File _requireFile(Directory root, String relativePath) {
  final file = File(p.join(root.path, relativePath));
  if (!file.existsSync()) {
    throw StateError('Required rendering input disappeared: $relativePath');
  }
  return file;
}

bool _isSensitivePath(String relativePath) {
  final normalized = p.posix.normalize(relativePath).toLowerCase();
  final name = p.posix.basename(normalized);
  if (normalized == _localSecretPath) return true;
  if (name == 'googleservice-info.plist') return true;
  if (name == 'google-services.json') return true;
  if (name == '.env' || name.startsWith('.env.')) return true;
  const sensitiveExtensions = <String>{
    '.cer',
    '.crt',
    '.der',
    '.jks',
    '.key',
    '.keystore',
    '.mobileprovision',
    '.p12',
    '.p8',
    '.pem',
    '.pfx',
    '.provisionprofile',
  };
  return sensitiveExtensions.contains(p.posix.extension(name));
}

Future<bool> _verifyLocalSecretBoundary(Directory root) async {
  final localSecret = File(p.join(root.path, _localSecretPath));
  if (!localSecret.existsSync()) return true;

  final ignored = await Process.run('git', [
    'check-ignore',
    '--quiet',
    _localSecretPath,
  ], workingDirectory: root.path);
  final tracked = await Process.run('git', [
    'ls-files',
    '--error-unmatch',
    _localSecretPath,
  ], workingDirectory: root.path);

  if (ignored.exitCode == 0 && tracked.exitCode != 0) return true;
  stderr.writeln(
    'Local validation-only configuration must remain ignored and untracked.',
  );
  return false;
}

void _reportMismatch(List<String> expected, List<String> actual) {
  final expectedByPath = _linesByPath(expected);
  final actualByPath = _linesByPath(actual);
  final allPaths = <String>{
    ...expectedByPath.keys,
    ...actualByPath.keys,
  }.toList()..sort();

  stderr.writeln('UI/UX frozen scope verification failed.');
  for (final path in allPaths) {
    final expectedLine = expectedByPath[path];
    final actualLine = actualByPath[path];
    if (expectedLine == null) {
      stderr.writeln('  unexpected: $path');
    } else if (actualLine == null) {
      stderr.writeln('  missing: $path');
    } else if (expectedLine != actualLine) {
      stderr.writeln('  changed: $path');
    }
  }
}

bool _sameLines(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Map<String, String> _linesByPath(List<String> lines) {
  final result = <String, String>{};
  for (final line in lines) {
    final separator = line.indexOf('  ');
    if (separator < 0) {
      result[line] = line;
      continue;
    }
    result[line.substring(separator + 2)] = line;
  }
  return result;
}
