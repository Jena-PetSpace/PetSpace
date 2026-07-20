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
    fail(`Forbidden path in integration manifest: ${normalized}`);
  }
  return normalized;
}

function parseArgs(argv) {
  const result = {
    sourceRoots: new Map(),
    apply: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--apply') {
      result.apply = true;
      continue;
    }
    if (!value.startsWith('--')) fail(`Unexpected argument: ${value}`);
    if (index + 1 >= argv.length) fail(`${value} requires a value.`);
    const next = argv[++index];
    if (value === '--manifest') result.manifest = next;
    else if (value === '--target') result.target = next;
    else if (value === '--expected-head') result.expectedHead = next;
    else if (value === '--acknowledge') result.acknowledge = next;
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
  if (!result.target) fail('--target is required.');
  if (!result.expectedHead) fail('--expected-head is required.');
  if (result.sourceRoots.size === 0) {
    fail('At least one --source-root NAME=ABSOLUTE_PATH is required.');
  }
  if (result.apply && result.acknowledge !== 'exact-manifest-reviewed') {
    fail(
      '--apply requires --acknowledge exact-manifest-reviewed after consensus.',
    );
  }
  return result;
}

function run(command, args, cwd) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: 'utf8',
    shell: false,
    windowsHide: true,
  });
  if (result.error) fail(result.error.message);
  if (result.status !== 0) {
    fail(
      `${command} ${args.join(' ')} failed in ${cwd}\n` +
        `${result.stderr || result.stdout}`,
    );
  }
  return result.stdout.trim();
}

function isWithin(parent, child) {
  const relative = path.relative(parent, child);
  return (
    relative === '' ||
    (!relative.startsWith('..') && !path.isAbsolute(relative))
  );
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

function inspectRows(rows, roots) {
  return rows.map((row) => {
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
      return {
        ...row,
        root,
        absolute: null,
        action: 'DELETE',
        actualSha256: 'DELETE',
      };
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
    return {
      ...row,
      root,
      absolute,
      action: 'COPY',
      actualSha256,
    };
  });
}

function buildPlan(rows) {
  const grouped = new Map();
  for (const row of rows) {
    const values = grouped.get(row.path) ?? [];
    values.push(row);
    grouped.set(row.path, values);
  }

  const automatic = [];
  const overlaps = [];
  for (const [relative, variants] of grouped) {
    const hashes = new Set(variants.map((variant) => variant.actualSha256));
    if (hashes.size === 1) {
      automatic.push({
        path: relative,
        chosen: variants[0],
        equivalentSources: variants.map((variant) => variant.source),
      });
    } else {
      overlaps.push({
        path: relative,
        variants: variants.map((variant) => ({
          source: variant.source,
          sha256: variant.actualSha256,
          action: variant.action,
        })),
      });
    }
  }

  automatic.sort((left, right) => left.path.localeCompare(right.path));
  overlaps.sort((left, right) => left.path.localeCompare(right.path));
  return { automatic, overlaps };
}

function inspectTarget(args) {
  const target = path.resolve(args.target);
  if (!fs.existsSync(target) || !fs.statSync(target).isDirectory()) {
    fail(`Target is not a directory: ${target}`);
  }
  const topLevel = path.resolve(run('git', ['rev-parse', '--show-toplevel'], target));
  if (topLevel !== target) {
    fail(`Target must be a Git worktree root: ${target}`);
  }
  const head = run('git', ['rev-parse', 'HEAD'], target);
  if (head !== args.expectedHead) {
    fail(`Target HEAD mismatch. Expected ${args.expectedHead}, got ${head}.`);
  }
  const status = run('git', ['status', '--porcelain=v1', '-uall'], target);
  if (status) {
    fail('Target worktree must be clean before materialization.');
  }
  for (const sourceRoot of args.sourceRoots.values()) {
    if (path.resolve(sourceRoot) === target) {
      fail('Target must not be one of the source roots.');
    }
  }
  return target;
}

function applyPlan(target, plan) {
  for (const entry of plan.automatic) {
    const destination = path.resolve(target, entry.path);
    if (!isWithin(target, destination)) {
      fail(`Destination escaped target worktree: ${entry.path}`);
    }
    if (entry.chosen.action === 'DELETE') {
      if (fs.existsSync(destination)) {
        if (!fs.statSync(destination).isFile()) {
          fail(`Refusing to delete non-file path: ${destination}`);
        }
        fs.rmSync(destination);
      }
      continue;
    }
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(entry.chosen.absolute, destination);
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const rows = inspectRows(
    parseTsv(path.resolve(args.manifest)),
    args.sourceRoots,
  );
  const plan = buildPlan(rows);

  let target = null;
  if (args.apply) {
    target = inspectTarget(args);
    applyPlan(target, plan);
  }

  const report = {
    version: 1,
    mode: args.apply ? 'applied' : 'dry-run',
    manifest: path.resolve(args.manifest),
    manifest_file_sha256: sha256(fs.readFileSync(path.resolve(args.manifest))),
    expected_head: args.expectedHead,
    target: path.resolve(args.target),
    source_rows: rows.length,
    union_paths: plan.automatic.length + plan.overlaps.length,
    automatic_paths: plan.automatic.length,
    semantic_overlap_paths: plan.overlaps.length,
    automatic: plan.automatic.map((entry) => ({
      path: entry.path,
      source: entry.chosen.source,
      action: entry.chosen.action,
      sha256: entry.chosen.actualSha256,
      equivalent_sources: entry.equivalentSources,
    })),
    overlaps: plan.overlaps,
  };
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);

  if (args.apply && plan.overlaps.length > 0) {
    process.stderr.write(
      `Applied ${plan.automatic.length} deterministic paths; ` +
        `${plan.overlaps.length} semantic overlaps remain untouched.\n`,
    );
  }
}

main();
