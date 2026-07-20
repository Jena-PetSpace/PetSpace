import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  actualChangedManifest,
  allowedVerification,
  canonicalJson,
  changedManifestFromSnapshot,
  copyDirtyBaseline,
  copyLocalRuntimeMetadata,
  createLocalSecretsStub,
  globToRegExp,
  normalizeRelativePath,
  normalizeVerificationCwd,
  policyAllows,
  repositorySnapshot,
  resolveVerificationProcess,
  statusPath,
  validateImplementationManifest,
  validateReviewManifest,
} from './agent-consensus.mjs';

function createGitRepo() {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-consensus-'));
  execFileSync('git', ['init', '--quiet'], { cwd: repo });
  execFileSync('git', ['config', 'user.email', 'test@example.invalid'], {
    cwd: repo,
  });
  execFileSync('git', ['config', 'user.name', 'Test'], { cwd: repo });
  fs.writeFileSync(path.join(repo, 'modify.txt'), 'before\n');
  fs.writeFileSync(path.join(repo, 'delete.txt'), 'delete\n');
  execFileSync('git', ['add', '.'], { cwd: repo });
  execFileSync('git', ['commit', '--quiet', '-m', 'base'], { cwd: repo });
  return repo;
}

test('canonical JSON is stable across object key order', () => {
  assert.equal(
    canonicalJson({ b: 2, a: { d: 4, c: 3 } }),
    canonicalJson({ a: { c: 3, d: 4 }, b: 2 }),
  );
});

test('path normalization rejects escapes and protected files', () => {
  assert.equal(
    normalizeRelativePath('.\\pjh\\lib\\main.dart'),
    'pjh/lib/main.dart',
  );
  assert.throws(() => normalizeRelativePath('../outside.txt'));
  assert.throws(() => normalizeRelativePath('C:\\temp\\file.txt'));
  assert.throws(() => normalizeRelativePath('pjh/lib/config/secrets.dart'));
  assert.throws(() => normalizeRelativePath('.env.local'));
});

test('glob policy includes source while excluding secrets', () => {
  const policy = {
    includes: ['pjh/lib/**', 'pjh/test/**'],
    excludes: ['**/secrets.dart', '**/.env*'],
  };
  assert.equal(policyAllows(policy, 'pjh/lib/main.dart'), true);
  assert.equal(policyAllows(policy, 'pjh/lib/config/secrets.dart'), false);
  assert.equal(policyAllows(policy, 'supabase/petspace_setup.sql'), false);
  assert.equal(globToRegExp('pjh/lib/**').test('pjh/lib/a/b.dart'), true);
});

test('implementation manifest is exact and deduplicated', () => {
  const value = validateImplementationManifest([
    { action: 'MODIFY', path: 'b.dart', reason: 'b' },
    { action: 'ADD', path: 'a.dart', reason: 'a' },
  ]);
  assert.deepEqual(
    value.map((entry) => entry.path),
    ['a.dart', 'b.dart'],
  );
  assert.throws(() =>
    validateImplementationManifest([
      { action: 'ADD', path: 'a.dart', reason: 'a' },
      { action: 'MODIFY', path: './a.dart', reason: 'duplicate' },
    ]),
  );
});

test('implementation actions must match the baseline repository', (t) => {
  const repo = createGitRepo();
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  assert.doesNotThrow(() =>
    validateImplementationManifest(
      [
        { action: 'MODIFY', path: 'modify.txt', reason: 'modify' },
        { action: 'DELETE', path: 'delete.txt', reason: 'delete' },
        { action: 'ADD', path: 'add.txt', reason: 'add' },
      ],
      repo,
    ),
  );
  assert.throws(() =>
    validateImplementationManifest(
      [{ action: 'ADD', path: 'modify.txt', reason: 'wrong' }],
      repo,
    ),
  );
  assert.throws(() =>
    validateImplementationManifest(
      [{ action: 'MODIFY', path: 'missing.txt', reason: 'wrong' }],
      repo,
    ),
  );
});

test('review manifest accepts tracked and untracked files but rejects ignored files', (t) => {
  const repo = createGitRepo();
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  fs.writeFileSync(path.join(repo, 'untracked.txt'), 'review me\n');
  fs.writeFileSync(path.join(repo, '.gitignore'), 'ignored.txt\n');
  fs.writeFileSync(path.join(repo, 'ignored.txt'), 'do not review\n');

  assert.deepEqual(
    validateReviewManifest(repo, ['modify.txt', 'untracked.txt']),
    ['modify.txt', 'untracked.txt'],
  );
  assert.throws(() => validateReviewManifest(repo, ['ignored.txt']));
});

test('actual changes preserve ADD, MODIFY, and DELETE actions', (t) => {
  const repo = createGitRepo();
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  fs.writeFileSync(path.join(repo, 'modify.txt'), 'after\n');
  fs.rmSync(path.join(repo, 'delete.txt'));
  fs.writeFileSync(path.join(repo, 'add.txt'), 'add\n');
  assert.deepEqual(actualChangedManifest(repo), [
    { action: 'ADD', path: 'add.txt' },
    { action: 'DELETE', path: 'delete.txt' },
    { action: 'MODIFY', path: 'modify.txt' },
  ]);
});

test('snapshot comparison isolates changes made after a dirty baseline', (t) => {
  const repo = createGitRepo();
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  fs.writeFileSync(path.join(repo, 'modify.txt'), 'approved baseline\n');
  fs.writeFileSync(path.join(repo, 'baseline-add.txt'), 'approved add\n');
  const baseline = repositorySnapshot(repo);

  fs.writeFileSync(path.join(repo, 'modify.txt'), 'new implementation\n');
  fs.writeFileSync(path.join(repo, 'implementation-add.txt'), 'new add\n');

  assert.deepEqual(changedManifestFromSnapshot(repo, baseline), [
    { action: 'ADD', path: 'implementation-add.txt' },
    { action: 'MODIFY', path: 'modify.txt' },
  ]);
});

test('dirty baseline copy preserves tracked edits, deletions, and untracked files', (t) => {
  const repo = createGitRepo();
  const target = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-baseline-'));
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  t.after(() => fs.rmSync(target, { recursive: true, force: true }));

  fs.copyFileSync(path.join(repo, 'modify.txt'), path.join(target, 'modify.txt'));
  fs.copyFileSync(path.join(repo, 'delete.txt'), path.join(target, 'delete.txt'));
  fs.writeFileSync(path.join(repo, 'modify.txt'), 'approved baseline\n');
  fs.rmSync(path.join(repo, 'delete.txt'));
  fs.mkdirSync(path.join(repo, 'new'), { recursive: true });
  fs.writeFileSync(path.join(repo, 'new', 'file.txt'), 'approved add\n');
  const dirty = execFileSync('git', ['status', '--porcelain'], {
    cwd: repo,
    encoding: 'utf8',
  })
    .split(/\r?\n/)
    .filter(Boolean);

  copyDirtyBaseline(repo, target, dirty);

  assert.equal(
    fs.readFileSync(path.join(target, 'modify.txt'), 'utf8'),
    'approved baseline\n',
  );
  assert.equal(fs.existsSync(path.join(target, 'delete.txt')), false);
  assert.equal(
    fs.readFileSync(path.join(target, 'new', 'file.txt'), 'utf8'),
    'approved add\n',
  );
});

test('runtime metadata copy is limited to Flutter dependency metadata', (t) => {
  const source = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-runtime-source-'));
  const target = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-runtime-target-'));
  t.after(() => fs.rmSync(source, { recursive: true, force: true }));
  t.after(() => fs.rmSync(target, { recursive: true, force: true }));
  const tool = path.join(source, 'pjh', '.dart_tool');
  fs.mkdirSync(tool, { recursive: true });
  fs.writeFileSync(path.join(tool, 'package_config.json'), '{}\n');
  fs.writeFileSync(path.join(tool, 'package_graph.json'), '{}\n');
  fs.writeFileSync(path.join(tool, 'ignored.bin'), 'no\n');
  fs.writeFileSync(
    path.join(source, 'pjh', '.flutter-plugins-dependencies'),
    '{}\n',
  );

  assert.deepEqual(copyLocalRuntimeMetadata(source, target), [
    'pjh/.dart_tool/package_config.json',
    'pjh/.dart_tool/package_graph.json',
    'pjh/.flutter-plugins-dependencies',
  ]);
  assert.equal(
    fs.existsSync(path.join(target, 'pjh', '.dart_tool', 'ignored.bin')),
    false,
  );
});

test('local secrets stub derives names without copying secret values', (t) => {
  const repo = createGitRepo();
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  const config = path.join(repo, 'pjh', 'lib', 'config');
  fs.mkdirSync(config, { recursive: true });
  fs.writeFileSync(
    path.join(config, 'api_config.dart'),
    'final values = [Secrets.betaKey, Secrets.alphaKey];\n',
  );
  execFileSync('git', ['add', 'pjh/lib/config/api_config.dart'], { cwd: repo });

  assert.equal(
    createLocalSecretsStub(repo),
    'pjh/lib/config/secrets.dart',
  );
  const stub = fs.readFileSync(path.join(config, 'secrets.dart'), 'utf8');
  assert.match(stub, /static const String alphaKey = '';/);
  assert.match(stub, /static const String betaKey = '';/);
  assert.doesNotMatch(stub, /secret-value/);
});

test('dirty baseline paths reject rename entries', () => {
  assert.equal(
    statusPath(' M scripts/agent-consensus.mjs'),
    'scripts/agent-consensus.mjs',
  );
  assert.equal(
    statusPath('?? scripts/agent-consensus.test.mjs'),
    'scripts/agent-consensus.test.mjs',
  );
  assert.throws(() => statusPath('R  old.dart -> new.dart'));
});

test('verification cwd normalizes absolute paths inside the repository', () => {
  const repo = path.resolve('C:/repo');
  assert.equal(normalizeVerificationCwd(repo, repo), '.');
  assert.equal(
    normalizeVerificationCwd(repo, path.join(repo, 'pjh')),
    'pjh',
  );
  assert.throws(() =>
    normalizeVerificationCwd(repo, path.resolve(repo, '..', 'outside')),
  );
});

test('verification allowlist rejects shell chaining and unsafe commands', () => {
  assert.equal(
    allowedVerification({ cwd: '.', command: 'git diff --check' }),
    true,
  );
  assert.equal(
    allowedVerification({
      cwd: 'pjh',
      command: 'flutter analyze --no-pub',
    }),
    true,
  );
  assert.equal(
    allowedVerification({
      cwd: '.',
      command: 'flutter test --no-pub; git push',
    }),
    false,
  );
  assert.equal(
    allowedVerification({ cwd: '.', command: 'supabase db push' }),
    false,
  );
});

test('changes-required implementation can be corrected and re-reviewed', () => {
  const source = fs.readFileSync(
    path.join(import.meta.dirname, 'agent-consensus.mjs'),
    'utf8',
  );
  assert.match(source, /implementation_changes_required/);
  assert.match(
    source,
    /const reviewHash = bundle\.manifestSha256\.slice\(0, 12\)/,
  );
  assert.match(source, /implementation-review-claude-\$\{reviewHash\}/);
  assert.match(source, /implementation-review-codex-\$\{reviewHash\}/);
});

test(
  'Windows verification resolves Flutter through the Dart snapshot',
  { skip: process.platform !== 'win32' },
  () => {
    const dart = resolveVerificationProcess(['dart', 'format', 'a.dart']);
    const flutter = resolveVerificationProcess([
      'flutter',
      'analyze',
      '--no-pub',
    ]);
    assert.match(dart.command, /dart\.exe$/i);
    assert.equal(fs.existsSync(dart.command), true);
    assert.equal(flutter.command, dart.command);
    assert.match(flutter.args[0], /flutter_tools\.snapshot$/i);
    assert.equal(fs.existsSync(flutter.args[0]), true);
  },
);
