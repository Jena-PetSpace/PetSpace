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
  /(^|\/)\.claude\/settings\.local\.json$/i,
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
  const result = {
    sourceRoots: new Map(),
    docs: [],
    dryRun: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--dry-run') {
      result.dryRun = true;
      continue;
    }
    if (!value.startsWith('--')) fail(`Unexpected argument: ${value}`);
    if (index + 1 >= argv.length) fail(`${value} requires a value.`);
    const next = argv[++index];
    if (value === '--manifest') result.manifest = next;
    else if (value === '--workspace') result.workspace = next;
    else if (value === '--out') result.out = next;
    else if (value === '--doc') result.docs.push(next);
    else if (value === '--source-root') {
      const separator = next.indexOf('=');
      if (separator <= 0 || separator === next.length - 1) {
        fail('--source-root must use NAME=ABSOLUTE_PATH.');
      }
      result.sourceRoots.set(
        next.slice(0, separator),
        path.resolve(next.slice(separator + 1)),
      );
    } else {
      fail(`Unknown argument: ${value}`);
    }
  }

  if (!result.manifest) fail('--manifest is required.');
  if (!result.workspace) fail('--workspace is required.');
  if (!result.dryRun && !result.out) fail('--out is required unless --dry-run.');
  if (result.sourceRoots.size === 0) {
    fail('At least one --source-root NAME=ABSOLUTE_PATH is required.');
  }
  return result;
}

function parseTsv(file) {
  const text = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
  const lines = text.split(/\r?\n/).filter((line) => line.length > 0);
  if (lines.length < 2) fail('Manifest TSV contains no source rows.');
  if (lines[0] !== 'path\tsource\tsha256') {
    fail('Manifest TSV header must be: path<TAB>source<TAB>sha256');
  }
  return lines.slice(1).map((line, index) => {
    const fields = line.split('\t');
    if (fields.length !== 3) fail(`Invalid TSV row ${index + 2}.`);
    return {
      path: normalizeRelative(fields[0]),
      source: fields[1],
      expectedSha256: fields[2],
    };
  });
}

function isWithin(parent, child) {
  const relative = path.relative(parent, child);
  return (
    relative === '' ||
    (!relative.startsWith('..') && !path.isAbsolute(relative))
  );
}

function assertSafeOutput(workspace, output) {
  const allowedRoot = path.resolve(workspace, '.agent-collab', 'runs');
  const resolvedOutput = path.resolve(output);
  if (!isWithin(allowedRoot, resolvedOutput) || resolvedOutput === allowedRoot) {
    fail(`Output must be a child of ${allowedRoot}`);
  }
  if (fs.existsSync(resolvedOutput)) {
    fail(`Output already exists; refusing to overwrite: ${resolvedOutput}`);
  }
  return resolvedOutput;
}

function inspectSourceRows(rows, roots) {
  const entries = [];
  for (const row of rows) {
    const root = roots.get(row.source);
    if (!root) fail(`No source root supplied for ${row.source}.`);
    if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
      fail(`Source root is not a directory: ${root}`);
    }

    const absolute = path.resolve(root, row.path);
    if (!isWithin(root, absolute)) fail(`Source escaped its root: ${row.path}`);
    if (row.expectedSha256 === 'DELETE') {
      if (fs.existsSync(absolute)) {
        fail(`DELETE entry still exists: ${row.source}:${row.path}`);
      }
      entries.push({
        ...row,
        action: 'DELETE',
        absolute: null,
        actualSha256: 'DELETE',
        bytes: 0,
      });
      continue;
    }

    if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
      fail(`Source file missing: ${row.source}:${row.path}`);
    }
    const buffer = fs.readFileSync(absolute);
    const actualSha256 = sha256(buffer);
    if (actualSha256 !== row.expectedSha256) {
      fail(
        `SHA-256 mismatch for ${row.source}:${row.path}\n` +
          `expected ${row.expectedSha256}\nactual   ${actualSha256}`,
      );
    }
    const content = buffer.toString('utf8');
    if (secretValuePatterns.some((pattern) => pattern.test(content))) {
      fail(`Secret-like value detected: ${row.source}:${row.path}`);
    }
    entries.push({
      ...row,
      action: 'COPY',
      absolute,
      actualSha256,
      bytes: buffer.length,
    });
  }
  return entries;
}

function inspectDocs(values) {
  return values.map((value) => {
    const absolute = path.resolve(value);
    const relative = normalizeRelative(path.basename(absolute));
    if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
      fail(`Review document missing: ${absolute}`);
    }
    const buffer = fs.readFileSync(absolute);
    const content = buffer.toString('utf8');
    if (secretValuePatterns.some((pattern) => pattern.test(content))) {
      fail(`Secret-like value detected in review document: ${absolute}`);
    }
    return {
      absolute,
      relative,
      sha256: sha256(buffer),
      bytes: buffer.length,
    };
  });
}

function canonicalManifest(entries, docs) {
  const sourceRows = entries.map(
    (entry) =>
      `SOURCE\t${entry.source}\t${entry.path}\t${entry.actualSha256}\t${entry.action}\n`,
  );
  const docRows = docs
    .slice()
    .sort((left, right) => left.relative.localeCompare(right.relative))
    .map((doc) => `DOC\t${doc.relative}\t${doc.sha256}\n`);
  return [...sourceRows, ...docRows].join('');
}

function writeSnapshot(output, entries, docs, manifestSha256) {
  fs.mkdirSync(output, { recursive: false });

  for (const entry of entries) {
    const target = path.join(output, 'sources', entry.source, entry.path);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    if (entry.action === 'DELETE') {
      fs.writeFileSync(
        `${target}.DELETE.json`,
        `${JSON.stringify(
          {
            source: entry.source,
            path: entry.path,
            action: 'DELETE',
          },
          null,
          2,
        )}\n`,
        'utf8',
      );
    } else {
      fs.copyFileSync(entry.absolute, target);
    }
  }

  for (const doc of docs) {
    const target = path.join(output, 'docs', doc.relative);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(doc.absolute, target);
  }

  const publicManifest = {
    version: 1,
    generated_at: new Date().toISOString(),
    manifest_sha256: manifestSha256,
    exclusions: [
      '.env',
      'secrets.dart',
      'key.properties',
      'keys',
      'tokens',
      'credentials',
      'production row data',
    ],
    source_entries: entries.map((entry) => ({
      source: entry.source,
      path: entry.path,
      action: entry.action,
      sha256: entry.actualSha256,
      bytes: entry.bytes,
    })),
    documents: docs.map((doc) => ({
      path: `docs/${doc.relative}`,
      sha256: doc.sha256,
      bytes: doc.bytes,
    })),
  };
  fs.writeFileSync(
    path.join(output, 'manifest.json'),
    `${JSON.stringify(publicManifest, null, 2)}\n`,
    'utf8',
  );
}

const args = parseArgs(process.argv.slice(2));
const workspace = path.resolve(args.workspace);
const manifest = path.resolve(args.manifest);
const rows = parseTsv(manifest);
const entries = inspectSourceRows(rows, args.sourceRoots);
const docs = inspectDocs(args.docs);
const canonical = canonicalManifest(entries, docs);
const manifestSha256 = sha256(Buffer.from(canonical, 'utf8'));
const totalBytes =
  entries.reduce((sum, entry) => sum + entry.bytes, 0) +
  docs.reduce((sum, doc) => sum + doc.bytes, 0);

let output = null;
if (!args.dryRun) {
  output = assertSafeOutput(workspace, args.out);
  writeSnapshot(output, entries, docs, manifestSha256);
}

process.stdout.write(
  `${JSON.stringify(
    {
      ok: true,
      dry_run: args.dryRun,
      output,
      source_versions: entries.length,
      copied_source_files: entries.filter((entry) => entry.action === 'COPY')
        .length,
      deleted_source_markers: entries.filter(
        (entry) => entry.action === 'DELETE',
      ).length,
      documents: docs.length,
      total_bytes: totalBytes,
      manifest_sha256: manifestSha256,
    },
    null,
    2,
  )}\n`,
);
