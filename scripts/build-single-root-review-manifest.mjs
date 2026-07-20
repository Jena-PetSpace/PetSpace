#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

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

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function isWithin(parent, child) {
  const relative = path.relative(parent, child);
  return (
    relative === '' ||
    (!relative.startsWith('..') && !path.isAbsolute(relative))
  );
}

function normalizeRelative(value) {
  const normalized = value.replaceAll('\\', '/').replace(/^\.\/+/, '');
  if (
    !normalized ||
    path.isAbsolute(normalized) ||
    normalized === '..' ||
    normalized.startsWith('../') ||
    normalized.includes('/../')
  ) {
    fail(`Unsafe relative path: ${value}`);
  }
  if (forbiddenPathPatterns.some((pattern) => pattern.test(normalized))) {
    fail(`Forbidden path in review manifest: ${normalized}`);
  }
  return normalized;
}

function parseArgs(argv) {
  const result = { source: 'FINAL' };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (!value.startsWith('--')) fail(`Unexpected argument: ${value}`);
    if (index + 1 >= argv.length) fail(`${value} requires a value.`);
    const next = argv[++index];
    if (value === '--root') result.root = next;
    else if (value === '--workspace') result.workspace = next;
    else if (value === '--paths-file') result.pathsFile = next;
    else if (value === '--out') result.out = next;
    else if (value === '--source') result.source = next;
    else fail(`Unknown argument: ${value}`);
  }
  for (const key of ['root', 'workspace', 'pathsFile', 'out']) {
    if (!result[key]) fail(`--${key.replace(/[A-Z]/g, (v) => `-${v.toLowerCase()}`)} is required.`);
  }
  if (!/^[A-Za-z0-9_-]+$/.test(result.source)) {
    fail('--source must contain only letters, digits, underscore, or hyphen.');
  }
  return result;
}

function parsePaths(file) {
  const text = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
  const rows = [];
  for (const raw of text.split(/\r?\n/)) {
    const trimmed = raw.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const action = trimmed.startsWith('DELETE ')
      ? 'DELETE'
      : trimmed.startsWith('COPY ')
        ? 'COPY'
        : 'COPY';
    const rawPath =
      action === 'DELETE'
        ? trimmed.slice('DELETE '.length)
        : trimmed.startsWith('COPY ')
          ? trimmed.slice('COPY '.length)
          : trimmed;
    rows.push({ action, path: normalizeRelative(rawPath) });
  }
  if (rows.length === 0) fail('Paths file contains no entries.');
  const duplicates = rows
    .map((row) => row.path)
    .filter((value, index, values) => values.indexOf(value) !== index);
  if (duplicates.length > 0) {
    fail(`Duplicate paths: ${[...new Set(duplicates)].join(', ')}`);
  }
  return rows.sort((left, right) => left.path.localeCompare(right.path));
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const root = path.resolve(args.root);
  const workspace = path.resolve(args.workspace);
  const allowedRoot = path.resolve(workspace, '.agent-collab', 'runs');
  const output = path.resolve(args.out);
  if (!isWithin(allowedRoot, output) || output === allowedRoot) {
    fail(`Output must be a child of ${allowedRoot}`);
  }
  if (fs.existsSync(output)) fail(`Refusing to overwrite: ${output}`);
  if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
    fail(`Root is not a directory: ${root}`);
  }

  const rows = parsePaths(path.resolve(args.pathsFile)).map((row) => {
    const absolute = path.resolve(root, row.path);
    if (!isWithin(root, absolute)) fail(`Path escaped source root: ${row.path}`);
    if (row.action === 'DELETE') {
      if (fs.existsSync(absolute)) {
        fail(`DELETE path still exists: ${row.path}`);
      }
      return { ...row, sha256: 'DELETE', bytes: 0 };
    }
    if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
      fail(`Source file missing: ${row.path}`);
    }
    const buffer = fs.readFileSync(absolute);
    if (
      secretValuePatterns.some((pattern) => pattern.test(buffer.toString('utf8')))
    ) {
      fail(`Secret-like value detected: ${row.path}`);
    }
    return { ...row, sha256: sha256(buffer), bytes: buffer.length };
  });

  fs.mkdirSync(path.dirname(output), { recursive: true });
  const tsv = [
    'path\tsource\tsha256',
    ...rows.map((row) => `${row.path}\t${args.source}\t${row.sha256}`),
    '',
  ].join('\n');
  fs.writeFileSync(output, tsv, 'utf8');

  process.stdout.write(
    `${JSON.stringify(
      {
        ok: true,
        output,
        source: args.source,
        paths: rows.length,
        copied: rows.filter((row) => row.action === 'COPY').length,
        deleted: rows.filter((row) => row.action === 'DELETE').length,
        bytes: rows.reduce((sum, row) => sum + row.bytes, 0),
        file_sha256: sha256(Buffer.from(tsv, 'utf8')),
      },
      null,
      2,
    )}\n`,
  );
}

main();
