#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const forbiddenPathPatterns = [
  /(^|\/)\.env(?:\.|$)/i,
  /(^|\/)secrets?\.dart$/i,
  /(^|\/)key\.properties$/i,
  /\.(?:jks|keystore|p12|pem|key)$/i,
  /(^|\/)(?:credentials?|tokens?|private|secrets?)(?:\/|$)/i,
  /(^|\/)\.git(?:\/|$)/i,
];

const secretValuePatterns = [
  /eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{10,}/,
  /sk-[a-zA-Z0-9_-]{20,}/,
  /sbp_[a-zA-Z0-9_-]{20,}/,
  /AKIA[0-9A-Z]{16}/,
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\r?\n[A-Za-z0-9+/]{40,}/,
];

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function run(command, args, cwd) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: 'utf8',
    windowsHide: true,
  });
  if (result.error) fail(result.error.message);
  if (result.status !== 0) {
    fail(`${command} ${args.join(' ')} failed:\n${result.stderr || result.stdout}`);
  }
  return result.stdout.trim();
}

function normalizeRelative(value) {
  const normalized = value.replaceAll('\\', '/').replace(/^\.\/+/, '');
  if (
    !normalized ||
    path.isAbsolute(normalized) ||
    normalized === '..' ||
    normalized.startsWith('../') ||
    normalized.includes('/../') ||
    forbiddenPathPatterns.some((pattern) => pattern.test(normalized))
  ) {
    fail(`Unsafe overlap path: ${value}`);
  }
  return normalized;
}

function samePath(left, right) {
  const normalize = (value) => {
    const resolved = path.normalize(path.resolve(value));
    return process.platform === 'win32' ? resolved.toLowerCase() : resolved;
  };
  return normalize(left) === normalize(right);
}

function parseArgs(argv) {
  const result = { roots: new Map(), selections: new Map() };
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith('--') || index + 1 >= argv.length) {
      fail(`Invalid argument: ${key}`);
    }
    const value = argv[++index];
    if (key === '--manifest') result.manifest = value;
    else if (key === '--target') result.target = value;
    else if (key === '--expected-head') result.expectedHead = value;
    else if (key === '--acknowledge') result.acknowledge = value;
    else if (key === '--source-root' || key === '--selection') {
      const separator = value.indexOf('=');
      if (separator <= 0 || separator === value.length - 1) {
        fail(`${key} must use LEFT=RIGHT.`);
      }
      const left = value.slice(0, separator);
      const right = value.slice(separator + 1);
      if (key === '--source-root') result.roots.set(left, path.resolve(right));
      else result.selections.set(normalizeRelative(left), right);
    } else fail(`Unknown argument: ${key}`);
  }
  for (const required of ['manifest', 'target', 'expectedHead']) {
    if (!result[required]) fail(`--${required.replaceAll(/[A-Z]/g, (m) => `-${m.toLowerCase()}`)} is required.`);
  }
  if (result.acknowledge !== 'exact-overlap-rules-reviewed') {
    fail('--acknowledge exact-overlap-rules-reviewed is required.');
  }
  if (result.selections.size === 0) fail('At least one --selection is required.');
  return result;
}

function parseManifest(file) {
  const lines = fs
    .readFileSync(file, 'utf8')
    .replace(/^\uFEFF/, '')
    .split(/\r?\n/)
    .filter(Boolean);
  if (lines[0] !== 'path\tsource\tsha256') fail('Unexpected manifest header.');
  const grouped = new Map();
  for (const [index, line] of lines.slice(1).entries()) {
    const fields = line.split('\t');
    if (fields.length !== 3) fail(`Invalid manifest row ${index + 2}.`);
    const relative = normalizeRelative(fields[0]);
    const variants = grouped.get(relative) ?? [];
    variants.push({ path: relative, source: fields[1], sha256: fields[2] });
    grouped.set(relative, variants);
  }
  return grouped;
}

const args = parseArgs(process.argv.slice(2));
const target = path.resolve(args.target);
if (!samePath(run('git', ['rev-parse', '--show-toplevel'], target), target)) {
  fail('Target must be a Git worktree root.');
}
if (run('git', ['rev-parse', 'HEAD'], target) !== args.expectedHead) {
  fail('Target HEAD changed.');
}

const grouped = parseManifest(path.resolve(args.manifest));
const applied = [];
for (const [relative, selectedSource] of args.selections) {
  const variants = grouped.get(relative);
  if (!variants || new Set(variants.map((entry) => entry.sha256)).size < 2) {
    fail(`Selection is not a semantic overlap: ${relative}`);
  }
  const selected = variants.find((entry) => entry.source === selectedSource);
  if (!selected) fail(`Source ${selectedSource} is not a variant of ${relative}.`);
  const root = args.roots.get(selectedSource);
  if (!root) fail(`Missing source root: ${selectedSource}`);

  const destination = path.resolve(target, relative);
  run('git', ['cat-file', '-e', `HEAD:${relative}`], target);
  const targetStatus = run(
    'git',
    ['status', '--porcelain=v1', '--', relative],
    target,
  );
  if (!fs.existsSync(destination) || targetStatus) {
    fail(`Overlap was modified before selection: ${relative}`);
  }

  if (selected.sha256 === 'DELETE') {
    fs.rmSync(destination);
  } else {
    const source = path.resolve(root, relative);
    if (!fs.existsSync(source)) fail(`Selected source missing: ${source}`);
    const content = fs.readFileSync(source);
    if (sha256(content) !== selected.sha256) fail(`Selected source hash drift: ${relative}`);
    if (secretValuePatterns.some((pattern) => pattern.test(content.toString('utf8')))) {
      fail(`Secret-like value detected: ${relative}`);
    }
    fs.copyFileSync(source, destination);
  }
  applied.push({ path: relative, source: selectedSource, sha256: selected.sha256 });
}

process.stdout.write(
  `${JSON.stringify(
    {
      ok: true,
      target,
      expected_head: args.expectedHead,
      applied,
    },
    null,
    2,
  )}\n`,
);
