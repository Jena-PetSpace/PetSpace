#!/usr/bin/env node

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const defaultPrimaryModel = 'claude-opus-4-8';
const defaultFallbackModel = null;
const timeoutMs = 30 * 60 * 1000;

function fail(message, details = '') {
  process.stderr.write(`${message}\n`);
  if (details) process.stderr.write(`${details}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--help') {
      result.help = true;
      continue;
    }
    if (!value.startsWith('--')) fail(`Unexpected argument: ${value}`);
    if (index + 1 >= argv.length) fail(`${value} requires a value.`);
    const next = argv[++index];
    const key = value.slice(2).replaceAll('-', '_');
    result[key] = next;
  }
  return result;
}

function locateClaude() {
  if (process.env.CLAUDE_BIN && fs.existsSync(process.env.CLAUDE_BIN)) {
    return process.env.CLAUDE_BIN;
  }
  const extensionsRoot = path.join(os.homedir(), '.vscode', 'extensions');
  if (fs.existsSync(extensionsRoot)) {
    const candidates = fs
      .readdirSync(extensionsRoot)
      .filter((name) =>
        /^anthropic\.claude-code-.*-win32-x64$/i.test(name),
      )
      .sort((left, right) =>
        right.localeCompare(left, undefined, { numeric: true }),
      )
      .map((name) =>
        path.join(
          extensionsRoot,
          name,
          'resources',
          'native-binary',
          'claude.exe',
        ),
      )
      .filter(fs.existsSync);
    if (candidates[0]) return candidates[0];
  }
  return 'claude';
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeJson(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function parseClaudeEnvelope(stdout) {
  const wrapper = JSON.parse(stdout.trim());
  if (wrapper.structured_output) return wrapper.structured_output;
  if (typeof wrapper.result === 'string') return JSON.parse(wrapper.result);
  if (wrapper.result && typeof wrapper.result === 'object') {
    return wrapper.result;
  }
  fail('Claude did not return structured output.', stdout);
}

function isRateLimited(value) {
  const text = value.toLowerCase();
  return [
    /api_error_status["':\s]+429/,
    /\b429\b/,
    /rate[ _-]?limit/,
    /session[ _-]?limit/,
    /reached .*limit/,
    /hit .*limit/,
    /limit .*reset/,
    /resets? [^.\r\n]+/,
    /사용량.*한도/,
    /한도.*도달/,
  ].some((pattern) => pattern.test(text));
}

function resetHint(value) {
  const matches = [
    value.match(/resets?\s+([^"\r\n}]+)/i),
    value.match(/reset(?:s|ting)?(?:\s+at|\s+in)?\s+([^"\r\n}]+)/i),
  ];
  return matches.find(Boolean)?.[1]?.trim() ?? null;
}

function runClaude({ executable, model, cwd, prompt, schema }) {
  return spawnSync(
    executable,
    [
      '-p',
      '--model',
      model,
      '--output-format',
      'json',
      '--json-schema',
      JSON.stringify(schema),
      '--no-session-persistence',
      '--effort',
      'high',
      '--permission-mode',
      'dontAsk',
      '--setting-sources',
      '',
      '--tools',
      'Read,Grep,Glob',
      '--add-dir',
      cwd,
    ],
    {
      cwd,
      input: prompt,
      encoding: 'utf8',
      windowsHide: true,
      timeout: timeoutMs,
      maxBuffer: 64 * 1024 * 1024,
    },
  );
}

function printHelp() {
  process.stdout.write(`Usage:
  node scripts/run-snapshot-claude-review.mjs \\
    --snapshot ABSOLUTE_PATH \\
    --prompt PROMPT_FILE \\
    --schema JSON_SCHEMA_FILE \\
    --out OUTPUT_DIRECTORY \\
    [--label integration-planning] \\
    [--primary-model claude-opus-4-8] \\
    [--fallback-model MODEL]

The snapshot must contain manifest.json produced by
prepare-multiroot-review-snapshot.mjs. Claude receives read-only Read/Grep/Glob
access to that snapshot only. The default model is Claude Opus 4.8. A fallback
is attempted only when --fallback-model or CLAUDE_FALLBACK_MODEL is explicitly
provided. If every configured model is rate-limited it writes retry.json and
exits with code 75.
`);
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  printHelp();
  process.exit(0);
}

for (const required of ['snapshot', 'prompt', 'schema', 'out']) {
  if (!args[required]) fail(`--${required.replaceAll('_', '-')} is required.`);
}

const snapshot = path.resolve(args.snapshot);
const promptFile = path.resolve(args.prompt);
const schemaFile = path.resolve(args.schema);
const output = path.resolve(args.out);
const label = args.label ?? 'claude-review';
const primaryModel =
  args.primary_model ?? process.env.CLAUDE_MODEL ?? defaultPrimaryModel;
const fallbackModel =
  args.fallback_model ??
  process.env.CLAUDE_FALLBACK_MODEL ??
  defaultFallbackModel;

const snapshotManifestFile = path.join(snapshot, 'manifest.json');
if (!fs.existsSync(snapshotManifestFile)) {
  fail(`Snapshot manifest not found: ${snapshotManifestFile}`);
}
if (!fs.existsSync(promptFile)) fail(`Prompt not found: ${promptFile}`);
if (!fs.existsSync(schemaFile)) fail(`Schema not found: ${schemaFile}`);

const snapshotManifest = readJson(snapshotManifestFile);
const manifestSha256 = snapshotManifest.manifest_sha256;
if (!/^[a-f0-9]{64}$/i.test(manifestSha256 ?? '')) {
  fail('Snapshot manifest_sha256 is invalid.');
}
const schema = readJson(schemaFile);
const taskPrompt = fs.readFileSync(promptFile, 'utf8');

fs.mkdirSync(output, { recursive: true });
const resultFile = path.join(output, `${label}.result.json`);
if (fs.existsSync(resultFile)) {
  process.stdout.write(fs.readFileSync(resultFile, 'utf8'));
  process.exit(0);
}

const prompt = `You are Claude, the independent PetSpace reviewer.
The local user approved Anthropic transmission of the exact files in this
isolated snapshot. You may use only Read, Grep, and Glob inside the current
snapshot directory. Never inspect a parent or external path. Never read or
request .env, secrets.dart, keys, tokens, credentials, or production row data.
Do not edit files, run commands, use network tools, or contact another service.

Read manifest.json first. Its approved manifest SHA-256 is:
${manifestSha256}

Every reviewed_manifest_sha256 field must equal that exact value. Treat source
variants as provenance evidence; do not confuse P1, SOCIAL, and P2 copies as one
already-integrated tree. Use blocker/high only for material correctness,
security, privacy, data, accessibility, or test defects. Do not require changes
for style preference alone. Return only the requested JSON schema.

Task:
${taskPrompt}
`;

fs.writeFileSync(path.join(output, `${label}.prompt.md`), prompt, 'utf8');
writeJson(path.join(output, `${label}.schema.json`), schema);

const executable = locateClaude();
const attempts = [];
let structured = null;
let modelUsed = null;
let fallbackReason = null;

for (const model of [primaryModel, fallbackModel]) {
  if (!model || attempts.some((attempt) => attempt.model === model)) continue;
  const result = runClaude({
    executable,
    model,
    cwd: snapshot,
    prompt,
    schema,
  });
  const stdout = result.stdout ?? '';
  const stderr = result.stderr ?? '';
  fs.writeFileSync(
    path.join(output, `${label}.${model}.stdout.log`),
    stdout,
    'utf8',
  );
  fs.writeFileSync(
    path.join(output, `${label}.${model}.stderr.log`),
    stderr,
    'utf8',
  );
  const combined = `${stdout}\n${stderr}\n${result.error?.message ?? ''}`;
  attempts.push({
    model,
    status: result.status,
    rate_limited: isRateLimited(combined),
    reset_hint: resetHint(combined),
  });

  if (result.status === 0) {
    structured = parseClaudeEnvelope(stdout);
    modelUsed = model;
    if (model !== primaryModel) fallbackReason = 'primary_usage_limit';
    break;
  }
  if (!isRateLimited(combined)) {
    fail(
      `Claude ${model} failed with status ${result.status}.`,
      combined.trim(),
    );
  }
}

if (!structured) {
  const retry = {
    status: 'rate_limited',
    manifest_sha256: manifestSha256,
    attempts,
    next_action:
      'Resume the same snapshot and output directory after the latest reset hint. Do not create a new review run.',
  };
  writeJson(path.join(output, 'retry.json'), retry);
  process.stdout.write(`${JSON.stringify(retry, null, 2)}\n`);
  process.exit(75);
}

if (
  Object.hasOwn(structured, 'reviewed_manifest_sha256') &&
  structured.reviewed_manifest_sha256 !== manifestSha256
) {
  fail(
    'Claude reviewed_manifest_sha256 does not match the snapshot manifest.',
    JSON.stringify(structured, null, 2),
  );
}

writeJson(resultFile, structured);
writeJson(path.join(output, `${label}.model.json`), {
  primary_model: primaryModel,
  fallback_model: fallbackModel,
  model_used: modelUsed,
  fallback_reason: fallbackReason,
  manifest_sha256: manifestSha256,
  attempts,
});
process.stdout.write(`${JSON.stringify(structured, null, 2)}\n`);
