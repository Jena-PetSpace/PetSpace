import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late String verifierPath;

  setUpAll(() {
    verifierPath = p.join(
      Directory.current.absolute.path,
      'tool',
      'verify_uiux_scope.dart',
    );
  });

  test('verifier detects pass, changed, missing, and unexpected inputs',
      () async {
    final fixture = await _createFixture();
    addTearDown(() => fixture.delete(recursive: true));

    final generated = await _runVerifier(
      verifierPath,
      fixture,
      printSnapshot: true,
    );
    expect(generated.exitCode, 0);
    expect(generated.stdout, contains('lib/dependency.dart'));
    expect(generated.stdout, contains('lib/conditional.dart'));
    expect(generated.stdout, isNot(contains('secrets.dart')));

    File(p.join(fixture.path, 'tool', 'snapshot.sha256'))
      ..createSync(recursive: true)
      ..writeAsStringSync(generated.stdout as String);

    final passing = await _runVerifier(verifierPath, fixture);
    expect(passing.exitCode, 0);

    final dependency = File(p.join(fixture.path, 'lib', 'dependency.dart'));
    dependency.writeAsStringSync('const changed = true;\n');
    final changed = await _runVerifier(verifierPath, fixture);
    expect(changed.exitCode, 1);
    expect(changed.stderr, contains('changed: lib/dependency.dart'));
    expect(changed.stderr, isNot(contains('const changed')));

    dependency.deleteSync();
    final missing = await _runVerifier(verifierPath, fixture);
    expect(missing.exitCode, 1);
    expect(
      missing.stderr,
      contains('Required rendering input disappeared: lib/dependency.dart'),
    );

    dependency.writeAsStringSync('const dependency = true;\n');
    File(p.join(fixture.path, 'assets', 'unexpected.txt'))
        .writeAsStringSync('new rendering input');
    final unexpected = await _runVerifier(verifierPath, fixture);
    expect(unexpected.exitCode, 1);
    expect(unexpected.stderr, contains('unexpected: assets/unexpected.txt'));
  });

  test('secret boundary failure stops before snapshot comparison', () async {
    final fixture = await _createFixture();
    addTearDown(() => fixture.delete(recursive: true));
    File(p.join(fixture.path, '.gitignore')).writeAsStringSync('');

    final result = await _runVerifier(
      verifierPath,
      fixture,
      printSnapshot: true,
    );

    expect(result.exitCode, 1);
    expect(
      result.stderr,
      contains(
        'Local validation-only configuration must remain ignored and untracked.',
      ),
    );
    expect(result.stdout, isEmpty);
    expect(result.stderr, isNot(contains('fake-local-value')));

    File(p.join(fixture.path, '.gitignore'))
        .writeAsStringSync('lib/config/secrets.dart\n');
    final tracked = await Process.run(
      'git',
      ['add', '-f', 'lib/config/secrets.dart'],
      workingDirectory: fixture.path,
    );
    expect(tracked.exitCode, 0);
    final trackedResult = await _runVerifier(
      verifierPath,
      fixture,
      printSnapshot: true,
    );
    expect(trackedResult.exitCode, 1);
    expect(trackedResult.stdout, isEmpty);
    expect(trackedResult.stderr, isNot(contains('fake-local-value')));
  });

  test('required rendering directories fail when missing or empty', () async {
    final missingAssets = await _createFixture();
    addTearDown(() => missingAssets.delete(recursive: true));
    Directory(p.join(missingAssets.path, 'assets')).deleteSync(recursive: true);
    final missingResult = await _runVerifier(
      verifierPath,
      missingAssets,
      printSnapshot: true,
    );
    expect(missingResult.exitCode, 1);
    expect(
      missingResult.stderr,
      contains('Required rendering input directory is missing.'),
    );

    final emptyAssets = await _createFixture();
    addTearDown(() => emptyAssets.delete(recursive: true));
    File(p.join(emptyAssets.path, 'assets', 'fixture.txt')).deleteSync();
    final emptyAssetsResult = await _runVerifier(
      verifierPath,
      emptyAssets,
      printSnapshot: true,
    );
    expect(emptyAssetsResult.exitCode, 1);
    expect(
      emptyAssetsResult.stderr,
      contains('Required rendering input directory is empty.'),
    );

    final emptyLocalizations = await _createFixture();
    addTearDown(() => emptyLocalizations.delete(recursive: true));
    File(
      p.join(
        emptyLocalizations.path,
        'lib',
        'l10n',
        'fixture.arb',
      ),
    ).deleteSync();
    final emptyLocalizationResult = await _runVerifier(
      verifierPath,
      emptyLocalizations,
      printSnapshot: true,
    );
    expect(emptyLocalizationResult.exitCode, 1);
    expect(
      emptyLocalizationResult.stderr,
      contains('Required rendering input directory is empty.'),
    );
  });
}

Future<Directory> _createFixture() async {
  final root = await Directory.systemTemp.createTemp('uiux-scope-test-');
  void write(String path, String contents) {
    final file = File(p.join(root.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  write('pubspec.yaml', 'name: verifier_fixture\n');
  write('pubspec.lock', '# fixture\n');
  write('assets/fixture.txt', 'asset\n');
  write('lib/l10n/fixture.arb', '{}\n');
  write(
    'lib/entry.dart',
    "import 'dependency.dart'\n"
        "  if (dart.library.io) 'conditional.dart';\n"
        "import 'config/secrets.dart';\n"
        'const entry = true;\n',
  );
  write('lib/dependency.dart', 'const dependency = true;\n');
  write('lib/conditional.dart', 'const conditional = true;\n');
  write('lib/root.dart', 'const root = true;\n');
  write('lib/config/secrets.dart', "const value = 'fake-local-value';\n");
  write('.gitignore', 'lib/config/secrets.dart\n');

  final git = await Process.run('git', ['init', '--quiet'],
      workingDirectory: root.path);
  if (git.exitCode != 0) {
    throw StateError('Unable to initialize verifier fixture.');
  }
  return root;
}

Future<ProcessResult> _runVerifier(
  String verifierPath,
  Directory fixture, {
  bool printSnapshot = false,
}) {
  return Process.run(
    'dart',
    [
      verifierPath,
      '--root=${fixture.path}',
      '--entry=lib/entry.dart',
      '--explicit=lib/root.dart',
      '--snapshot-file=tool/snapshot.sha256',
      if (printSnapshot) '--snapshot',
    ],
    workingDirectory: Directory.current.path,
  );
}
