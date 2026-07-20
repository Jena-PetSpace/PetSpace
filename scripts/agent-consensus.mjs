#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scriptFile = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(scriptFile);
const defaultRepoRoot = path.resolve(scriptDir, '..');
const defaultRounds = 3;
const processTimeoutMs = 30 * 60 * 1000;
const claudePrimaryModel = process.env.CLAUDE_MODEL ?? 'claude-opus-4-8';
const claudeFallbackModel = process.env.CLAUDE_FALLBACK_MODEL ?? null;
const bootstrapDirtyPaths = new Set([
  'docs/AUTO_ORCHESTRATOR.md',
  'scripts/agent-consensus.mjs',
  'scripts/agent-consensus.test.mjs',
]);

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

const proposalSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'summary',
    'objective',
    'facts',
    'assumptions',
    'risks',
    'recommended_executor',
    'executor_reason',
    'review_manifest',
    'implementation_manifest',
    'verification',
    'human_decisions',
    'work_order_markdown',
  ],
  properties: {
    summary: { type: 'string' },
    objective: { type: 'string' },
    facts: { type: 'array', items: { type: 'string' } },
    assumptions: { type: 'array', items: { type: 'string' } },
    risks: { type: 'array', items: { type: 'string' } },
    recommended_executor: { enum: ['codex', 'claude', 'human'] },
    executor_reason: { type: 'string' },
    review_manifest: {
      type: 'array',
      items: { type: 'string' },
    },
    implementation_manifest: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['action', 'path', 'reason'],
        properties: {
          action: { enum: ['ADD', 'MODIFY', 'DELETE'] },
          path: { type: 'string' },
          reason: { type: 'string' },
        },
      },
    },
    verification: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['cwd', 'command'],
        properties: {
          cwd: { type: 'string' },
          command: { type: 'string' },
        },
      },
    },
    human_decisions: { type: 'array', items: { type: 'string' } },
    work_order_markdown: { type: 'string' },
  },
};

const reviewSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'decision',
    'reviewed_manifest_sha256',
    'summary',
    'issues',
    'required_changes',
    'recommended_executor',
    'executor_reason',
    'required_context',
  ],
  properties: {
    decision: { enum: ['agree', 'revise', 'block'] },
    reviewed_manifest_sha256: { type: 'string' },
    summary: { type: 'string' },
    issues: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'location', 'issue', 'minimum_fix'],
        properties: {
          severity: { enum: ['blocker', 'high', 'medium', 'low'] },
          location: { type: 'string' },
          issue: { type: 'string' },
          minimum_fix: { type: 'string' },
        },
      },
    },
    required_changes: { type: 'array', items: { type: 'string' } },
    recommended_executor: { enum: ['codex', 'claude', 'human'] },
    executor_reason: { type: 'string' },
    required_context: { type: 'array', items: { type: 'string' } },
  },
};

const reconciliationSchema = {
  ...proposalSchema,
  required: [
    ...proposalSchema.required,
    'decision',
    'adopted_findings',
    'rejected_findings',
  ],
  properties: {
    ...proposalSchema.properties,
    decision: { enum: ['accept', 'revise', 'block'] },
    adopted_findings: { type: 'array', items: { type: 'string' } },
    rejected_findings: { type: 'array', items: { type: 'string' } },
  },
};

const ratificationSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'decision',
    'plan_sha256',
    'manifest_sha256',
    'recommended_executor',
    'reason',
    'blocker_high',
  ],
  properties: {
    decision: { enum: ['accept', 'reject'] },
    plan_sha256: { type: 'string' },
    manifest_sha256: { type: 'string' },
    recommended_executor: { enum: ['codex', 'claude', 'human'] },
    reason: { type: 'string' },
    blocker_high: { type: 'array', items: { type: 'string' } },
  },
};

const executionSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['status', 'summary', 'changed_files', 'verification', 'issues'],
  properties: {
    status: { enum: ['complete', 'blocked'] },
    summary: { type: 'string' },
    changed_files: { type: 'array', items: { type: 'string' } },
    verification: { type: 'array', items: { type: 'string' } },
    issues: { type: 'array', items: { type: 'string' } },
  },
};

const implementationReviewSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'verdict',
    'reviewed_manifest_sha256',
    'summary',
    'findings',
    'verification_gaps',
  ],
  properties: {
    verdict: { enum: ['approve', 'changes_required', 'block'] },
    reviewed_manifest_sha256: { type: 'string' },
    summary: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'location', 'issue', 'minimum_fix'],
        properties: {
          severity: { enum: ['blocker', 'high', 'medium', 'low'] },
          location: { type: 'string' },
          issue: { type: 'string' },
          minimum_fix: { type: 'string' },
        },
      },
    },
    verification_gaps: { type: 'array', items: { type: 'string' } },
  },
};

const selfTestSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['ok', 'agent', 'note'],
  properties: {
    ok: { type: 'boolean' },
    agent: { enum: ['codex', 'claude'] },
    note: { type: 'string' },
  },
};

function fail(message, details = '') {
  const error = new Error(message);
  error.details = details;
  throw error;
}

function ensureDir(target) {
  fs.mkdirSync(target, { recursive: true });
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function writeJson(target, value) {
  ensureDir(path.dirname(target));
  const temp = `${target}.${process.pid}.tmp`;
  fs.writeFileSync(temp, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
  fs.renameSync(temp, target);
}

function readJson(target) {
  return JSON.parse(fs.readFileSync(target, 'utf8'));
}

function parseArgs(argv) {
  const result = { _: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (!value.startsWith('--')) {
      result._.push(value);
      continue;
    }
    const key = value.slice(2);
    if (['execute', 'local'].includes(key)) {
      result[key] = true;
      continue;
    }
    if (index + 1 >= argv.length) fail(`--${key} requires a value.`);
    result[key] = argv[++index];
  }
  return result;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd,
    input: options.input,
    encoding: 'utf8',
    windowsHide: true,
    timeout: options.timeout ?? processTimeoutMs,
    maxBuffer: options.maxBuffer ?? 64 * 1024 * 1024,
    env: { ...process.env, ...(options.env ?? {}) },
  });
  if (options.stdoutFile) {
    fs.writeFileSync(options.stdoutFile, result.stdout ?? '', 'utf8');
  }
  if (options.stderrFile) {
    fs.writeFileSync(options.stderrFile, result.stderr ?? '', 'utf8');
  }
  if (result.error) throw result.error;
  if (result.status !== 0 && !options.allowedStatuses?.includes(result.status)) {
    fail(
      `${command} exited with code ${result.status}.`,
      `${result.stdout ?? ''}\n${result.stderr ?? ''}`.trim(),
    );
  }
  return {
    status: result.status,
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? '',
  };
}

function git(repoRoot, args, options = {}) {
  return run(
    'git',
    ['-c', `safe.directory=${repoRoot.replaceAll('\\', '/')}`, ...args],
    {
      cwd: options.cwd ?? repoRoot,
      allowedStatuses: options.allowedStatuses,
    },
  ).stdout.trim();
}

function normalizeRelativePath(value) {
  if (typeof value !== 'string' || !value.trim()) {
    fail('Manifest paths must be non-empty strings.');
  }
  const normalized = value.trim().replaceAll('\\', '/').replace(/^\.\/+/, '');
  if (
    path.posix.isAbsolute(normalized) ||
    /^[a-z]:\//i.test(normalized) ||
    normalized.split('/').includes('..')
  ) {
    fail(`Unsafe manifest path: ${value}`);
  }
  if (forbiddenPathPatterns.some((pattern) => pattern.test(normalized))) {
    fail(`Forbidden manifest path: ${normalized}`);
  }
  return normalized;
}

function uniqueSorted(values) {
  return [...new Set(values)].sort((left, right) =>
    left < right ? -1 : left > right ? 1 : 0,
  );
}

function statusPath(row) {
  const relative = row.slice(3).replaceAll('\\', '/');
  if (!relative || relative.includes(' -> ')) {
    fail(`Unsupported dirty baseline entry: ${row}`);
  }
  return relative;
}

function validateReviewManifest(repoRoot, values) {
  const paths = uniqueSorted(values.map(normalizeRelativePath));
  for (const relative of paths) {
    const absolute = path.join(repoRoot, relative);
    if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
      fail(`Claude review path does not exist: ${relative}`);
    }
    const tracked = git(
      repoRoot,
      ['ls-files', '--error-unmatch', '--', relative],
      { allowedStatuses: [1] },
    );
    if (!tracked) {
      const untracked = git(repoRoot, [
        'ls-files',
        '--others',
        '--exclude-standard',
        '--',
        relative,
      ])
        .split(/\r?\n/)
        .filter(Boolean)
        .map((entry) => entry.replaceAll('\\', '/'));
      if (!untracked.includes(relative)) {
        fail(`Claude review path is neither tracked nor untracked: ${relative}`);
      }
    }
  }
  return paths;
}

function validateImplementationManifest(values, repoRoot = null) {
  const seen = new Set();
  return values
    .map((entry) => ({
      action: entry.action,
      path: normalizeRelativePath(entry.path),
      reason: entry.reason,
    }))
    .sort((left, right) =>
      left.path < right.path ? -1 : left.path > right.path ? 1 : 0,
    )
    .map((entry) => {
      if (seen.has(entry.path)) fail(`Duplicate implementation path: ${entry.path}`);
      seen.add(entry.path);
      if (repoRoot) {
        const absolute = path.join(repoRoot, entry.path);
        const exists = fs.existsSync(absolute);
        const tracked =
          run(
            'git',
            ['ls-files', '--error-unmatch', '--', entry.path],
            {
              cwd: repoRoot,
              allowedStatuses: [1],
            },
          ).status === 0;
        if (entry.action === 'ADD' && exists) {
          fail(`ADD path already exists: ${entry.path}`);
        }
        if (
          ['MODIFY', 'DELETE'].includes(entry.action) &&
          (!exists || !tracked)
        ) {
          fail(
            `${entry.action} path must be an existing tracked file: ${entry.path}`,
          );
        }
      }
      return entry;
    });
}

function normalizePlan(plan, repoRoot) {
  return {
    ...plan,
    review_manifest: validateReviewManifest(
      repoRoot,
      plan.review_manifest ?? [],
    ),
    implementation_manifest: validateImplementationManifest(
      plan.implementation_manifest ?? [],
      repoRoot,
    ),
    verification: (plan.verification ?? []).map((entry) => ({
      cwd: normalizeVerificationCwd(repoRoot, entry.cwd),
      command: entry.command.trim(),
    })),
  };
}

function normalizeVerificationCwd(repoRoot, value) {
  if (typeof value !== 'string' || !value.trim()) {
    fail('Verification cwd must be a non-empty string.');
  }
  const trimmed = value.trim();
  if (!path.isAbsolute(trimmed)) {
    return trimmed === '.' ? '.' : normalizeRelativePath(trimmed);
  }
  const relative = path.relative(repoRoot, trimmed).replaceAll('\\', '/');
  if (!relative) return '.';
  if (
    relative === '..' ||
    relative.startsWith('../') ||
    path.posix.isAbsolute(relative)
  ) {
    fail(`Verification cwd escapes the repository: ${value}`);
  }
  return normalizeRelativePath(relative);
}

function isUsageLimit(text) {
  const value = String(text).toLowerCase();
  return [
    /\b429\b/,
    /usage[ _-]?limit/,
    /rate[ _-]?limit/,
    /session[ _-]?limit/,
    /reached .*limit/,
    /limit .*reset/,
    /resets? at/,
    /사용량.*한도/,
    /한도.*도달/,
  ].some((pattern) => pattern.test(value));
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

function locateCodexLauncher() {
  if (process.env.CODEX_BIN && fs.existsSync(process.env.CODEX_BIN)) {
    return process.env.CODEX_BIN.toLowerCase().endsWith('.js')
      ? {
          command: process.execPath,
          prefix: [process.env.CODEX_BIN],
          display: process.env.CODEX_BIN,
        }
      : {
          command: process.env.CODEX_BIN,
          prefix: [],
          display: process.env.CODEX_BIN,
        };
  }
  const npmEntry = path.join(
    process.env.APPDATA ?? '',
    'npm',
    'node_modules',
    '@openai',
    'codex',
    'bin',
    'codex.js',
  );
  if (fs.existsSync(npmEntry)) {
    return {
      command: process.execPath,
      prefix: [npmEntry],
      display: npmEntry,
    };
  }
  const where = run('where.exe', ['codex'], {
    cwd: defaultRepoRoot,
    allowedStatuses: [1],
  });
  const candidate = where.stdout.split(/\r?\n/).find(Boolean);
  if (candidate) {
    return { command: candidate, prefix: [], display: candidate };
  }
  fail('Codex CLI was not found. Run `codex --version` in PowerShell.');
}

function extractClaudeStructured(stdout) {
  const wrapper = JSON.parse(stdout.trim());
  if (wrapper.structured_output) return wrapper.structured_output;
  if (typeof wrapper.result === 'string') return JSON.parse(wrapper.result);
  if (wrapper.result && typeof wrapper.result === 'object') {
    return wrapper.result;
  }
  fail('Claude did not return structured output.');
}

function invokeClaude({
  prompt,
  schema,
  runDir,
  label,
  cwd,
  mode = 'review',
}) {
  const resultFile = path.join(runDir, `${label}.result.json`);
  if (fs.existsSync(resultFile)) return readJson(resultFile);

  const promptFile = path.join(runDir, `${label}.prompt.md`);
  const modelFile = path.join(runDir, `${label}.model.json`);
  const claude = locateClaude();
  fs.writeFileSync(promptFile, prompt, 'utf8');

  const createArgs = (model) => {
    const args = [
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
    ];
    if (mode === 'implementation') {
      args.push(
        '--permission-mode',
        'acceptEdits',
        '--setting-sources',
        'user,project,local',
        '--allowed-tools',
        'Read,Grep,Glob,Edit,Write,Bash(dart format *),Bash(flutter analyze *),Bash(flutter test *),Bash(node --check *),Bash(node --test *),Bash(git diff --check)',
        '--disallowed-tools',
        'Bash(git add *),Bash(git commit *),Bash(git push *),Bash(git merge *),Bash(git rebase *),Bash(git reset *),Bash(git clean *),Bash(git stash *),Bash(supabase *),Bash(rm *),Bash(mv *)',
      );
    } else {
      args.push(
        '--permission-mode',
        'plan',
        '--setting-sources',
        '',
        '--tools',
        '',
      );
    }
    return args;
  };

  function execute(model) {
    return run(claude, createArgs(model), {
      cwd,
      input: prompt,
      stdoutFile: path.join(runDir, `${label}.${model}.stdout.log`),
      stderrFile: path.join(runDir, `${label}.${model}.stderr.log`),
    });
  }

  let modelUsed = claudePrimaryModel;
  let fallbackReason = null;
  let raw;
  try {
    raw = execute(claudePrimaryModel);
  } catch (error) {
    const message = `${error.message}\n${error.details ?? ''}`;
    const fallbackEnabled =
      claudeFallbackModel &&
      claudeFallbackModel.toLowerCase() !== 'none' &&
      claudeFallbackModel !== claudePrimaryModel;
    if (!fallbackEnabled || !isUsageLimit(message)) throw error;
    modelUsed = claudeFallbackModel;
    fallbackReason = 'primary_model_usage_limit';
    raw = execute(modelUsed);
  }

  const structured = extractClaudeStructured(raw.stdout);
  writeJson(resultFile, structured);
  writeJson(modelFile, {
    primary_model: claudePrimaryModel,
    model_used: modelUsed,
    fallback_model: claudeFallbackModel,
    fallback_reason: fallbackReason,
  });
  return structured;
}

function invokeCodex({
  prompt,
  schema,
  runDir,
  label,
  cwd,
  mode = 'read',
}) {
  const resultFile = path.join(runDir, `${label}.result.json`);
  if (fs.existsSync(resultFile)) return readJson(resultFile);

  const launcher = locateCodexLauncher();
  const schemaFile = path.join(runDir, `${label}.schema.json`);
  const outputFile = path.join(runDir, `${label}.output.json`);
  fs.writeFileSync(
    path.join(runDir, `${label}.prompt.md`),
    prompt,
    'utf8',
  );
  writeJson(schemaFile, schema);
  fs.rmSync(outputFile, { force: true });

  run(
    launcher.command,
    [
      ...launcher.prefix,
      '--strict-config',
      '--sandbox',
      mode === 'write' ? 'workspace-write' : 'read-only',
      '--ask-for-approval',
      'never',
      '-C',
      cwd,
      'exec',
      '-',
      '--ephemeral',
      '--output-schema',
      schemaFile,
      '--output-last-message',
      outputFile,
      '--color',
      'never',
    ],
    {
      cwd,
      input: prompt,
      stdoutFile: path.join(runDir, `${label}.events.log`),
      stderrFile: path.join(runDir, `${label}.stderr.log`),
    },
  );
  const structured = readJson(outputFile);
  writeJson(resultFile, structured);
  return structured;
}

function globToRegExp(glob) {
  const normalized = glob.replaceAll('\\', '/');
  let source = '^';
  for (let index = 0; index < normalized.length; index += 1) {
    const character = normalized[index];
    if (character === '*' && normalized[index + 1] === '*') {
      source += '.*';
      index += 1;
    } else if (character === '*') {
      source += '[^/]*';
    } else if (character === '?') {
      source += '[^/]';
    } else {
      source += character.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }
  }
  return new RegExp(`${source}$`, 'i');
}

function policyFile(repoRoot) {
  return path.join(runsRoot(repoRoot), '_external-review-policy.json');
}

function loadPolicy(repoRoot) {
  const target = policyFile(repoRoot);
  if (!fs.existsSync(target)) {
    return {
      provider: 'anthropic',
      includes: [],
      excludes: [
        '.env*',
        '**/.env*',
        '**/secrets.dart',
        '**/key.properties',
        '**/*.jks',
        '**/*.keystore',
        '**/*.pem',
        '**/*.key',
      ],
    };
  }
  return readJson(target);
}

function policyAllows(policy, relative) {
  const included = policy.includes.some((glob) =>
    globToRegExp(glob).test(relative),
  );
  const excluded = policy.excludes.some((glob) =>
    globToRegExp(glob).test(relative),
  );
  return included && !excluded;
}

function externalScopeMissing(state, paths) {
  const policy = loadPolicy(state.repo_root);
  const perRun = new Set(state.external_review_approved_paths ?? []);
  return paths.filter(
    (relative) => !policyAllows(policy, relative) && !perRun.has(relative),
  );
}

function scanSecrets(entries) {
  const contaminated = entries
    .filter(({ content }) =>
      secretValuePatterns.some((pattern) => pattern.test(content)),
    )
    .map(({ relative }) => relative);
  if (contaminated.length > 0) {
    fail(
      `Secret-like value detected. Anthropic transfer stopped: ${contaminated.join(', ')}`,
    );
  }
}

function buildSourceBundle(repoRoot, reviewManifest, plan, heading) {
  const entries = reviewManifest.map((relative) => {
    const absolute = path.join(repoRoot, relative);
    const buffer = fs.readFileSync(absolute);
    return {
      relative,
      hash: sha256(buffer),
      content: buffer.toString('utf8'),
    };
  });
  scanSecrets(entries);
  const manifestRows = entries
    .map(({ relative, hash }) => `${relative}|${hash}\n`)
    .join('');
  const manifestSha256 = sha256(Buffer.from(manifestRows, 'utf8'));
  const sections = [
    `# ${heading}`,
    '',
    `- Git HEAD: ${git(repoRoot, ['rev-parse', 'HEAD'])}`,
    `- Approved source manifest SHA-256: ${manifestSha256}`,
    '- The user-approved local orchestrator supplied only the listed files.',
    '- Secrets, tokens, production row data, and forbidden files are excluded.',
    '',
    '## Candidate work order',
    '',
    plan.work_order_markdown,
    '',
    '## Structured plan',
    '',
    '```json',
    JSON.stringify(plan, null, 2),
    '```',
  ];
  for (const entry of entries) {
    const extension = path.extname(entry.relative).slice(1) || 'text';
    sections.push(
      '',
      `## ${entry.relative}`,
      `SHA-256: ${entry.hash}`,
      `\`\`\`${extension}`,
      entry.content,
      '```',
    );
  }
  return {
    text: sections.join('\n'),
    manifestSha256,
    entries,
  };
}

function runId(topic) {
  const date = new Date().toISOString().slice(0, 10).replaceAll('-', '');
  const slug =
    topic
      .normalize('NFKD')
      .replace(/[^\p{L}\p{N}]+/gu, '-')
      .replace(/^-|-$/g, '')
      .slice(0, 36) || 'task';
  return `${date}-${slug}-${crypto.randomBytes(2).toString('hex')}`;
}

function runsRoot(repoRoot) {
  return path.join(repoRoot, '.agent-collab', 'runs');
}

function saveState(state) {
  state.updated_at = new Date().toISOString();
  writeJson(path.join(state.run_dir, 'state.json'), state);
}

function loadState(repoRoot, id) {
  const target = path.join(runsRoot(repoRoot), id, 'state.json');
  if (!fs.existsSync(target)) fail(`Run not found: ${id}`);
  return readJson(target);
}

function plannerPrompt(state, previous = null) {
  return `
You are the fixed Codex planner and reconciler for PetSpace.
Inspect the repository read-only and produce an implementation-ready work order.
Follow AGENTS.md and current code evidence. Never read .env, secrets.dart, keys,
tokens, production data, or forbidden files. Do not edit files, run network
commands, or make Git changes.

Topic:
${state.topic}

Baseline:
- repository: ${state.repo_root}
- branch: ${state.base_branch}
- HEAD: ${state.base_commit}

Requirements:
1. review_manifest lists only existing tracked files Claude must receive.
2. implementation_manifest is exact and uses ADD/MODIFY/DELETE.
3. verification commands must be limited to git diff --check, node --check,
   node --test, dart format, flutter analyze --no-pub, or flutter test --no-pub.
4. Separate facts, assumptions, human decisions, deployment/DB/legal gates.
5. Default to Codex implementation unless Claude has a concrete advantage.
6. No commit, merge, push, deploy, production DB, or operational mutation.
7. Return only the requested JSON schema.

${previous ? `Previous round evidence:\n${JSON.stringify(previous, null, 2)}` : ''}
`;
}

function claudeReviewPrompt(state, bundle, manifestSha256) {
  return `
You are the fixed Claude Fable 5 independent reviewer.
The local user approved Anthropic transmission of exactly the files in the
bundle. Use only this bundle. Do not use tools, inspect other files, edit code,
or contact any service.

Review the Codex plan for correctness, scope, security, privacy, DB/RLS,
legal language, verification completeness, and executor choice.
- reviewed_manifest_sha256 must equal ${manifestSha256}.
- Use blocker/high only for material correctness or safety defects.
- Do not use changes_required for stylistic preference alone.
- If more source is essential, list exact relative paths in required_context.
- Return only the requested JSON schema.

${bundle}
`;
}

function reconciliationPrompt(state, proposal, review) {
  return `
You are the fixed Codex planner/reconciler for PetSpace.
Inspect the repository read-only. Reconcile Claude's findings one by one.
Adopt valid findings and reject invalid ones with evidence. Produce the complete
revised plan, not a patch. Never edit files or access forbidden files.

Topic:
${state.topic}

Codex proposal:
${JSON.stringify(proposal, null, 2)}

Claude review:
${JSON.stringify(review, null, 2)}

Keep review_manifest and implementation_manifest exact. New review files are
allowed only when truly required and will trigger a separate external-transfer
gate. Return only the requested JSON schema.
`;
}

function ratificationPrompt(
  state,
  bundle,
  plan,
  planSha256,
  manifestSha256,
) {
  return `
You are the final Claude Fable 5 ratifier for PetSpace.
Use only the supplied bundle and revised plan. Do not use tools.
Accept only if the plan is implementation-ready, blocker/high is empty, the
executor is justified, and both hashes match exactly.

Expected plan_sha256: ${planSha256}
Expected manifest_sha256: ${manifestSha256}

Revised plan:
${JSON.stringify(plan, null, 2)}

Bundle:
${bundle}
`;
}

function hasSevere(findings) {
  return findings.some((finding) =>
    ['blocker', 'high'].includes(finding.severity),
  );
}

function setExternalApprovalWait(state, paths) {
  state.status = 'awaiting_external_review_approval';
  state.pending_external_review_paths = paths;
  state.external_review_approval_code = crypto
    .randomBytes(3)
    .toString('hex')
    .toUpperCase();
  saveState(state);
  printState(state);
}

function driveConsensus(state) {
  state.status = 'planning';
  saveState(state);
  for (
    let roundNumber = state.current_round;
    roundNumber <= state.max_rounds;
    roundNumber += 1
  ) {
    state.current_round = roundNumber;
    const index = roundNumber - 1;
    const round = state.rounds[index] ?? { round: roundNumber };
    state.rounds[index] = round;
    saveState(state);

    if (!round.proposal) {
      const previous =
        index === 0
          ? null
          : {
              reconciliation: state.rounds[index - 1].reconciliation,
              ratification: state.rounds[index - 1].ratification,
            };
      round.proposal = normalizePlan(
        invokeCodex({
          prompt: plannerPrompt(state, previous),
          schema: proposalSchema,
          runDir: state.run_dir,
          label: `round-${roundNumber}-codex-plan`,
          cwd: state.repo_root,
        }),
        state.repo_root,
      );
      saveState(state);
    }

    let proposalBundle;
    while (true) {
      let missing = externalScopeMissing(
        state,
        round.proposal.review_manifest,
      );
      if (missing.length > 0) {
        setExternalApprovalWait(state, missing);
        return state;
      }

      proposalBundle = buildSourceBundle(
        state.repo_root,
        round.proposal.review_manifest,
        round.proposal,
        `PetSpace consensus round ${roundNumber} review bundle`,
      );
      round.proposal_manifest_sha256 = proposalBundle.manifestSha256;
      fs.writeFileSync(
        path.join(state.run_dir, `round-${roundNumber}-review-bundle.md`),
        proposalBundle.text,
        'utf8',
      );

      if (
        !round.claude_review ||
        round.claude_review_manifest_sha256 !==
          proposalBundle.manifestSha256
      ) {
        round.claude_review = invokeClaude({
          prompt: claudeReviewPrompt(
            state,
            proposalBundle.text,
            proposalBundle.manifestSha256,
          ),
          schema: reviewSchema,
          runDir: state.run_dir,
          label: `round-${roundNumber}-claude-review-${proposalBundle.manifestSha256.slice(0, 12)}`,
          cwd: state.run_dir,
        });
        if (
          round.claude_review.reviewed_manifest_sha256 !==
          proposalBundle.manifestSha256
        ) {
          fail('Claude reviewed manifest hash does not match the local bundle.');
        }
        round.claude_review_manifest_sha256 =
          proposalBundle.manifestSha256;
        saveState(state);
      }

      const required = validateReviewManifest(
        state.repo_root,
        round.claude_review.required_context,
      );
      const additional = required.filter(
        (relative) => !round.proposal.review_manifest.includes(relative),
      );
      if (additional.length === 0) break;

      round.proposal.review_manifest = uniqueSorted([
        ...round.proposal.review_manifest,
        ...additional,
      ]);
      round.claude_review = null;
      round.claude_review_manifest_sha256 = null;
      saveState(state);

      missing = externalScopeMissing(state, additional);
      if (missing.length > 0) {
        round.proposal.review_manifest = uniqueSorted([
          ...round.proposal.review_manifest,
          ...additional,
        ]);
        setExternalApprovalWait(state, missing);
        return state;
      }
    }

    if (!round.reconciliation) {
      round.reconciliation = normalizePlan(
        invokeCodex({
          prompt: reconciliationPrompt(
            state,
            round.proposal,
            round.claude_review,
          ),
          schema: reconciliationSchema,
          runDir: state.run_dir,
          label: `round-${roundNumber}-codex-reconciliation`,
          cwd: state.repo_root,
        }),
        state.repo_root,
      );
      saveState(state);
    }

    const missing = externalScopeMissing(
      state,
      round.reconciliation.review_manifest,
    );
    if (missing.length > 0) {
      setExternalApprovalWait(state, missing);
      return state;
    }

    const finalBundle = buildSourceBundle(
      state.repo_root,
      round.reconciliation.review_manifest,
      round.reconciliation,
      `PetSpace consensus round ${roundNumber} ratification bundle`,
    );
    const planSha256 = sha256(
      Buffer.from(canonicalJson(round.reconciliation), 'utf8'),
    );
    round.plan_sha256 = planSha256;
    round.final_manifest_sha256 = finalBundle.manifestSha256;

    if (!round.ratification) {
      round.ratification = invokeClaude({
        prompt: ratificationPrompt(
          state,
          finalBundle.text,
          round.reconciliation,
          planSha256,
          finalBundle.manifestSha256,
        ),
        schema: ratificationSchema,
        runDir: state.run_dir,
        label: `round-${roundNumber}-claude-ratification-${planSha256.slice(0, 12)}-${finalBundle.manifestSha256.slice(0, 12)}`,
        cwd: state.run_dir,
      });
      saveState(state);
    }

    const accepted =
      round.reconciliation.decision === 'accept' &&
      round.ratification.decision === 'accept' &&
      round.ratification.plan_sha256 === planSha256 &&
      round.ratification.manifest_sha256 === finalBundle.manifestSha256 &&
      round.ratification.blocker_high.length === 0 &&
      round.ratification.recommended_executor ===
        round.reconciliation.recommended_executor &&
      round.reconciliation.recommended_executor !== 'human';

    if (accepted) {
      const workOrderFile = path.join(state.run_dir, 'work-order.md');
      fs.writeFileSync(
        workOrderFile,
        `${round.reconciliation.work_order_markdown.trim()}\n`,
        'utf8',
      );
      state.status = 'awaiting_implementation_approval';
      state.consensus = {
        round: roundNumber,
        plan_sha256: planSha256,
        manifest_sha256: finalBundle.manifestSha256,
        executor: round.reconciliation.recommended_executor,
        executor_reason: round.reconciliation.executor_reason,
        review_manifest: round.reconciliation.review_manifest,
        implementation_manifest:
          round.reconciliation.implementation_manifest,
        verification: round.reconciliation.verification,
        work_order_file: workOrderFile,
      };
      state.implementation_approval_code = crypto
        .randomBytes(3)
        .toString('hex')
        .toUpperCase();
      saveState(state);
      printState(state);
      return state;
    }
  }

  state.status = 'needs_human_decision';
  saveState(state);
  printState(state);
  return state;
}

function preflight(repoRoot) {
  const claude = locateClaude();
  const codex = locateCodexLauncher();
  const claudeVersion = run(claude, ['--version'], { cwd: repoRoot }).stdout.trim();
  const claudeAuth = JSON.parse(
    run(claude, ['auth', 'status'], { cwd: repoRoot }).stdout.trim(),
  );
  const codexVersion = run(codex.command, [...codex.prefix, '--version'], {
    cwd: repoRoot,
  }).stdout.trim();
  const codexAuthResult = run(
    codex.command,
    [...codex.prefix, 'login', 'status'],
    { cwd: repoRoot },
  );
  return {
    repo_root: repoRoot,
    branch: git(repoRoot, ['branch', '--show-current']),
    head: git(repoRoot, ['rev-parse', 'HEAD']),
    working_tree_clean: git(repoRoot, ['status', '--porcelain']).length === 0,
    claude: {
      binary: claude,
      version: claudeVersion,
      logged_in: claudeAuth.loggedIn,
      auth_method: claudeAuth.authMethod,
      subscription_type: claudeAuth.subscriptionType,
      primary_model: claudePrimaryModel,
      fallback_model: claudeFallbackModel,
    },
    codex: {
      launcher: codex.display,
      version: codexVersion,
      auth: (codexAuthResult.stdout || codexAuthResult.stderr).trim(),
    },
  };
}

function commandSelfTest(repoRoot, localOnly) {
  const result = { preflight: preflight(repoRoot) };
  if (!localOnly) {
    const runDir = path.join(runsRoot(repoRoot), `self-test-v2-${Date.now()}`);
    ensureDir(runDir);
    result.codex = invokeCodex({
      prompt:
        'Do not inspect or edit files. Return ok=true, agent=codex, and a short note confirming structured output.',
      schema: selfTestSchema,
      runDir,
      label: 'codex',
      cwd: repoRoot,
    });
    result.claude = invokeClaude({
      prompt:
        'Do not use tools or inspect files. Return ok=true, agent=claude, and a short note confirming structured output.',
      schema: selfTestSchema,
      runDir,
      label: 'claude',
      cwd: runDir,
    });
    result.ok = result.codex.ok === true && result.claude.ok === true;
    result.logs = runDir;
  } else {
    result.ok = true;
  }
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

function printState(state) {
  const output = {
    run_id: state.id,
    status: state.status,
    topic: state.topic,
    current_round: state.current_round,
  };
  if (state.status === 'awaiting_external_review_approval') {
    output.provider = 'Anthropic Claude';
    output.external_review_paths = state.pending_external_review_paths;
    output.approval_code = state.external_review_approval_code;
    output.next_command = `node scripts/agent-consensus.mjs approve-review ${state.id} --code ${state.external_review_approval_code}`;
  }
  if (state.status === 'awaiting_implementation_approval') {
    output.executor = state.consensus.executor;
    output.plan_sha256 = state.consensus.plan_sha256;
    output.manifest_sha256 = state.consensus.manifest_sha256;
    output.implementation_manifest = state.consensus.implementation_manifest;
    output.approval_effects = [
      'Create an isolated local worktree and implement only the exact manifest.',
      'Send the exact changed implementation bundle to Anthropic Claude for final read-only review.',
      'Run the allowlisted local verification commands and Codex final review.',
      'Do not commit, merge, push, deploy, or mutate production.',
    ];
    if (state.consensus.executor === 'claude') {
      output.claude_executor_notice =
        'Claude implementation requires explicit acknowledgement that Claude Code can inspect the isolated worktree while following secret exclusions.';
    }
    output.approval_code = state.implementation_approval_code;
    output.next_command =
      `node scripts/agent-consensus.mjs approve ${state.id} --code ${state.implementation_approval_code}` +
      (state.consensus.executor === 'claude'
        ? ' --acknowledge-claude-worktree-access yes'
        : '') +
      ' --execute';
  }
  if (state.execution?.worktree) output.worktree = state.execution.worktree;
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
}

function commandStart(repoRoot, args) {
  const topic = args.topic ?? args._.slice(1).join(' ');
  if (!topic) fail('start requires --topic "..."');
  const maxRounds = Number(args.rounds ?? defaultRounds);
  if (!Number.isInteger(maxRounds) || maxRounds < 1 || maxRounds > 5) {
    fail('--rounds must be an integer from 1 to 5.');
  }
  const id = runId(topic);
  const runDir = path.join(runsRoot(repoRoot), id);
  ensureDir(runDir);
  const state = {
    version: 2,
    id,
    topic,
    status: 'created',
    repo_root: repoRoot,
    run_dir: runDir,
    base_branch: git(repoRoot, ['branch', '--show-current']),
    base_commit: git(repoRoot, ['rev-parse', 'HEAD']),
    baseline_status: git(repoRoot, ['status', '--porcelain']).split(/\r?\n/).filter(Boolean),
    max_rounds: maxRounds,
    current_round: 1,
    rounds: [],
    external_review_approved_paths: [],
    created_at: new Date().toISOString(),
  };
  saveState(state);
  driveConsensus(state);
}

function commandApproveReview(repoRoot, id, args) {
  const state = loadState(repoRoot, id);
  if (state.status !== 'awaiting_external_review_approval') {
    fail(`Run is not waiting for external review approval: ${state.status}`);
  }
  if (args.code !== state.external_review_approval_code) {
    fail('External review approval code does not match.');
  }
  state.external_review_approved_paths = uniqueSorted([
    ...(state.external_review_approved_paths ?? []),
    ...state.pending_external_review_paths,
  ]);
  state.external_review_approved_at = new Date().toISOString();
  delete state.pending_external_review_paths;
  delete state.external_review_approval_code;
  state.status = 'planning';
  saveState(state);
  driveConsensus(state);
}

function commandAuthorize(repoRoot, args) {
  if (args['acknowledge-anthropic-transfer'] !== 'yes') {
    fail(
      'Standing policy requires --acknowledge-anthropic-transfer yes.',
    );
  }
  const includes = uniqueSorted(
    String(args.include ?? '')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean),
  );
  if (includes.length === 0) fail('authorize-source-review requires --include.');
  const policy = loadPolicy(repoRoot);
  policy.includes = includes;
  policy.updated_at = new Date().toISOString();
  policy.authorization_note =
    'The local user explicitly acknowledged that matching source files may be transmitted to Anthropic Claude for review.';
  writeJson(policyFile(repoRoot), policy);
  process.stdout.write(`${JSON.stringify(policy, null, 2)}\n`);
}

function commandResume(repoRoot, id) {
  const state = loadState(repoRoot, id);
  if (state.status === 'awaiting_external_review_approval') {
    printState(state);
    return;
  }
  if (['planning', 'created', 'needs_human_decision'].includes(state.status)) {
    driveConsensus(state);
    return;
  }
  printState(state);
}

function commandStatus(repoRoot, id) {
  const state = loadState(repoRoot, id);
  process.stdout.write(`${JSON.stringify(state, null, 2)}\n`);
  printState(state);
}

function allowedVerification(entry) {
  const command = entry.command.trim();
  if (
    /[;&|><`$]/.test(command) ||
    command.includes('..') ||
    path.isAbsolute(entry.cwd)
  ) {
    return false;
  }
  return [
    /^git diff --check$/,
    /^node --check [\w./-]+$/,
    /^node --test [\w./*?-]+$/,
    /^dart format(?: --output=none)?(?: --set-exit-if-changed)? [\w./ -]+$/,
    /^flutter analyze --no-pub$/,
    /^flutter test --no-pub(?: [\w./*? -]+)?$/,
  ].some((pattern) => pattern.test(command));
}

function splitCommand(command) {
  const values = [];
  const pattern = /"([^"]*)"|'([^']*)'|([^\s]+)/g;
  let match;
  while ((match = pattern.exec(command))) {
    values.push(match[1] ?? match[2] ?? match[3]);
  }
  return values;
}

function resolveVerificationProcess(parts) {
  if (process.platform !== 'win32' || !['dart', 'flutter'].includes(parts[0])) {
    return { command: parts[0], args: parts.slice(1) };
  }
  const flutterRoots = uniqueSorted(
    [
      process.env.FLUTTER_ROOT,
      process.env.FLUTTER_HOME,
      'C:\\flutter',
    ].filter(Boolean),
  );
  for (const root of flutterRoots) {
    const dart = path.join(root, 'bin', 'cache', 'dart-sdk', 'bin', 'dart.exe');
    if (!fs.existsSync(dart)) continue;
    if (parts[0] === 'dart') {
      return { command: dart, args: parts.slice(1) };
    }
    const snapshot = path.join(root, 'bin', 'cache', 'flutter_tools.snapshot');
    if (fs.existsSync(snapshot)) {
      return { command: dart, args: [snapshot, ...parts.slice(1)] };
    }
  }
  return { command: parts[0], args: parts.slice(1) };
}

function actualChangedManifest(repoRoot) {
  const changes = [];
  const tracked = git(repoRoot, [
    'diff',
    '--name-status',
    '--no-renames',
    'HEAD',
    '--',
  ])
    .split(/\r?\n/)
    .filter(Boolean);
  for (const row of tracked) {
    const [rawStatus, ...pathParts] = row.split('\t');
    const action = rawStatus.slice(0, 1);
    const relative = pathParts.join('\t').replaceAll('\\', '/');
    if (!['A', 'M', 'D'].includes(action) || !relative) {
      fail(`Unsupported Git change detected: ${row}`);
    }
    changes.push({
      action: { A: 'ADD', M: 'MODIFY', D: 'DELETE' }[action],
      path: relative,
    });
  }
  const untracked = git(repoRoot, [
    'ls-files',
    '--others',
    '--exclude-standard',
  ])
    .split(/\r?\n/)
    .filter(Boolean);
  changes.push(
    ...untracked.map((relative) => ({
      action: 'ADD',
      path: relative.replaceAll('\\', '/'),
    })),
  );
  return changes.sort((left, right) =>
    left.path < right.path ? -1 : left.path > right.path ? 1 : 0,
  );
}

function repositorySnapshot(repoRoot) {
  const relativePaths = uniqueSorted(
    git(repoRoot, ['ls-files', '--cached', '--others', '--exclude-standard'])
      .split(/\r?\n/)
      .filter(Boolean)
      .map((relative) => relative.replaceAll('\\', '/')),
  );
  const snapshot = {};
  for (const relative of relativePaths) {
    const absolute = path.join(repoRoot, relative);
    if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) continue;
    snapshot[relative] = sha256(fs.readFileSync(absolute));
  }
  return snapshot;
}

function changedManifestFromSnapshot(repoRoot, baselineSnapshot) {
  const currentSnapshot = repositorySnapshot(repoRoot);
  const changes = [];
  const paths = uniqueSorted([
    ...Object.keys(baselineSnapshot),
    ...Object.keys(currentSnapshot),
  ]);
  for (const relative of paths) {
    const before = baselineSnapshot[relative];
    const after = currentSnapshot[relative];
    if (before === after) continue;
    changes.push({
      action: before === undefined ? 'ADD' : after === undefined ? 'DELETE' : 'MODIFY',
      path: relative,
    });
  }
  return changes;
}

function copyDirtyBaseline(repoRoot, worktree, dirtyRows) {
  for (const row of dirtyRows) {
    if (row.includes(' -> ')) {
      fail(`Unsupported dirty baseline entry: ${row}`);
    }
  }
  const dirtyPaths = new Set(
    git(repoRoot, ['diff', '--name-only', '--no-renames', 'HEAD', '--'])
      .split(/\r?\n/)
      .filter(Boolean)
      .map(normalizeRelativePath),
  );
  const untracked = git(repoRoot, [
    'ls-files',
    '--others',
    '--exclude-standard',
  ])
    .split(/\r?\n/)
    .filter(Boolean)
    .map(normalizeRelativePath);
  for (const relative of untracked) dirtyPaths.add(relative);

  for (const relative of uniqueSorted([...dirtyPaths])) {
    const source = path.resolve(repoRoot, relative);
    const target = path.resolve(worktree, relative);
    const worktreeRoot = path.resolve(worktree);
    if (
      target !== worktreeRoot &&
      !target.startsWith(`${worktreeRoot}${path.sep}`)
    ) {
      fail(`Dirty baseline path escapes isolated worktree: ${relative}`);
    }
    if (!fs.existsSync(source)) {
      if (fs.existsSync(target) && fs.statSync(target).isFile()) {
        fs.rmSync(target);
      }
      continue;
    }
    if (!fs.statSync(source).isFile()) {
      fail(`Dirty baseline entry is not a file: ${relative}`);
    }
    ensureDir(path.dirname(target));
    fs.copyFileSync(source, target);
  }
}

function copyLocalRuntimeMetadata(repoRoot, worktree) {
  const relativePaths = [
    'pjh/.dart_tool/package_config.json',
    'pjh/.dart_tool/package_graph.json',
    'pjh/.flutter-plugins-dependencies',
  ];
  const copied = [];
  for (const relative of relativePaths) {
    const source = path.join(repoRoot, relative);
    if (!fs.existsSync(source) || !fs.statSync(source).isFile()) continue;
    const target = path.join(worktree, relative);
    ensureDir(path.dirname(target));
    fs.copyFileSync(source, target);
    copied.push(relative);
  }
  return copied;
}

function createLocalSecretsStub(worktree) {
  const target = path.join(worktree, 'pjh', 'lib', 'config', 'secrets.dart');
  if (fs.existsSync(target)) return null;
  const dartFiles = git(worktree, ['ls-files', '--', 'pjh/lib'])
    .split(/\r?\n/)
    .filter((relative) => relative.endsWith('.dart'));
  const symbols = new Set();
  const pattern = /\bSecrets\.([A-Za-z_][A-Za-z0-9_]*)/g;
  for (const relative of dartFiles) {
    const source = fs.readFileSync(path.join(worktree, relative), 'utf8');
    let match;
    while ((match = pattern.exec(source))) symbols.add(match[1]);
  }
  if (symbols.size === 0) return null;
  const fields = uniqueSorted([...symbols]).map(
    (symbol) => `  static const String ${symbol} = '';`,
  );
  ensureDir(path.dirname(target));
  fs.writeFileSync(
    target,
    [
      'class Secrets {',
      '  Secrets._();',
      '',
      ...fields,
      '}',
      '',
    ].join('\n'),
    'utf8',
  );
  return 'pjh/lib/config/secrets.dart';
}

function executeVerification(worktree, entries, runDir) {
  const results = [];
  for (const [index, entry] of entries.entries()) {
    if (!allowedVerification(entry)) {
      fail(`Verification command is not allowlisted: ${entry.command}`);
    }
    const parts = splitCommand(entry.command);
    const resolved = resolveVerificationProcess(parts);
    const cwd = path.resolve(worktree, entry.cwd);
    if (!cwd.startsWith(path.resolve(worktree))) {
      fail(`Verification cwd escapes the worktree: ${entry.cwd}`);
    }
    const result = run(resolved.command, resolved.args, {
      cwd,
      stdoutFile: path.join(runDir, `verification-${index + 1}.stdout.log`),
      stderrFile: path.join(runDir, `verification-${index + 1}.stderr.log`),
      allowedStatuses: [],
    });
    results.push({
      cwd: entry.cwd,
      command: entry.command,
      status: result.status,
    });
  }
  return results;
}

function buildImplementationBundle(worktree, changedManifest, workOrder) {
  const entries = changedManifest.map(({ action, path: relative }) => {
    const absolute = path.join(worktree, relative);
    if (action === 'DELETE') {
      return {
        relative,
        status: 'D',
        hash: 'deleted',
        content: '',
      };
    }
    const buffer = fs.readFileSync(absolute);
    return {
      relative,
      status: { ADD: 'A', MODIFY: 'M' }[action],
      hash: sha256(buffer),
      content: buffer.toString('utf8'),
    };
  });
  scanSecrets(entries);
  const rows = entries
    .map(({ status, relative, hash }) => `${status}|${relative}|${hash}\n`)
    .join('');
  const manifestSha256 = sha256(Buffer.from(rows, 'utf8'));
  const sections = [
    '# PetSpace implementation review bundle',
    '',
    `- manifest SHA-256: ${manifestSha256}`,
    '- Exact changed paths only; secrets and production data are excluded.',
    '',
    '## Approved work order',
    '',
    workOrder,
  ];
  for (const entry of entries) {
    sections.push('', `## [${entry.status}] ${entry.relative}`, `SHA-256: ${entry.hash}`);
    if (entry.status !== 'D') {
      const extension = path.extname(entry.relative).slice(1) || 'text';
      sections.push(`\`\`\`${extension}`, entry.content, '```');
    }
  }
  return { text: sections.join('\n'), manifestSha256 };
}

function implementationPrompt(state, executor) {
  return `
You are the approved ${executor} implementation agent for PetSpace.
Implement the exact work order in this isolated worktree.

Allowed implementation manifest:
${JSON.stringify(state.consensus.implementation_manifest, null, 2)}

Work order:
${fs.readFileSync(state.consensus.work_order_file, 'utf8')}

Rules:
- Change exactly the listed paths and no others.
- Never read or print .env, secrets.dart, keys, tokens, or production data.
- Preserve unrelated behavior and pre-existing user work.
- Do not commit, merge, push, deploy, invoke Supabase, or mutate production.
- Run only the approved verification commands when applicable.
- Return only the requested JSON schema.
`;
}

function reviewImplementationPrompt(bundle, manifestSha256, reviewer) {
  return `
You are the independent ${reviewer} implementation reviewer for PetSpace.
Review only the supplied exact bundle. Do not edit files or contact services.
Return approve only when blocker/high is empty and reviewed_manifest_sha256
equals ${manifestSha256}. Style preferences alone are not changes_required.

${bundle}
`;
}

function commandApprove(repoRoot, id, args) {
  const state = loadState(repoRoot, id);
  if (state.status !== 'awaiting_implementation_approval') {
    fail(`Run is not waiting for implementation approval: ${state.status}`);
  }
  if (args.code !== state.implementation_approval_code) {
    fail('Implementation approval code does not match.');
  }
  const executor = args.executor ?? state.consensus.executor;
  if (!['codex', 'claude'].includes(executor)) {
    fail('--executor must be codex or claude.');
  }
  if (
    executor === 'claude' &&
    args['acknowledge-claude-worktree-access'] !== 'yes'
  ) {
    fail(
      'Claude execution requires --acknowledge-claude-worktree-access yes.',
    );
  }
  state.execution = {
    executor,
    consensus_executor: state.consensus.executor,
    human_override: executor !== state.consensus.executor,
    approved_at: new Date().toISOString(),
  };
  state.status = 'approved';
  delete state.implementation_approval_code;
  saveState(state);
  if (args.execute) commandExecute(repoRoot, id);
  else printState(state);
}

function commandExecute(repoRoot, id) {
  const state = loadState(repoRoot, id);
  if (
    ![
      'approved',
      'execution_failed',
      'implementation_changes_required',
    ].includes(state.status)
  ) {
    fail(`Run cannot execute from status: ${state.status}`);
  }
  if (git(repoRoot, ['rev-parse', 'HEAD']) !== state.base_commit) {
    fail('Repository HEAD changed after consensus. Start a new run.');
  }
  const dirty = git(repoRoot, ['status', '--porcelain'])
    .split(/\r?\n/)
    .filter(Boolean);
  const baseline = state.baseline_status ?? [];
  if (canonicalJson(dirty) !== canonicalJson(baseline)) {
    fail(
      'Working tree changed after consensus. Start a new run.',
      `baseline=${baseline.join('\n')}\ncurrent=${dirty.join('\n')}`,
    );
  }

  const slug = state.id.replace(/^\d{8}-/, '').slice(0, 32);
  const branch = `feature/auto-${slug}`;
  const root =
    process.env.AGENT_WORKTREES_ROOT ??
    path.join(path.dirname(repoRoot), '.agent-worktrees');
  const worktree = path.join(root, state.id);
  if (!state.execution.worktree) {
    if (fs.existsSync(worktree)) fail(`Worktree path already exists: ${worktree}`);
    ensureDir(root);
    git(repoRoot, ['worktree', 'add', '-b', branch, worktree, state.base_commit]);
    copyDirtyBaseline(repoRoot, worktree, dirty);
    state.execution.runtime_metadata = copyLocalRuntimeMetadata(
      repoRoot,
      worktree,
    );
    state.execution.local_secrets_stub = createLocalSecretsStub(worktree);
    const baselineSnapshot = repositorySnapshot(worktree);
    const baselineSnapshotFile = path.join(
      state.run_dir,
      'execution-baseline-snapshot.json',
    );
    fs.writeFileSync(
      baselineSnapshotFile,
      `${JSON.stringify(baselineSnapshot, null, 2)}\n`,
      'utf8',
    );
    validateImplementationManifest(
      state.consensus.implementation_manifest,
      worktree,
    );
    state.execution.branch = branch;
    state.execution.worktree = worktree;
    state.execution.baseline_snapshot_file = baselineSnapshotFile;
    state.execution.baseline_snapshot_sha256 = sha256(
      Buffer.from(canonicalJson(baselineSnapshot), 'utf8'),
    );
    state.status = 'executing';
    saveState(state);
  }

  try {
    if (
      !state.execution.baseline_snapshot_file ||
      !fs.existsSync(state.execution.baseline_snapshot_file)
    ) {
      fail('Execution baseline snapshot is missing.');
    }
    const baselineSnapshot = readJson(
      state.execution.baseline_snapshot_file,
    );
    if (!state.execution.result) {
      const prompt = implementationPrompt(state, state.execution.executor);
      state.execution.result =
        state.execution.executor === 'codex'
          ? invokeCodex({
              prompt,
              schema: executionSchema,
              runDir: state.run_dir,
              label: 'implementation-codex',
              cwd: state.execution.worktree,
              mode: 'write',
            })
          : invokeClaude({
              prompt,
              schema: executionSchema,
              runDir: state.run_dir,
              label: 'implementation-claude',
              cwd: state.execution.worktree,
              mode: 'implementation',
            });
    }

    const actualManifest = changedManifestFromSnapshot(
      state.execution.worktree,
      baselineSnapshot,
    );
    const expectedManifest = state.consensus.implementation_manifest.map(
      ({ action, path: relative }) => ({ action, path: relative }),
    );
    const actualRows = new Set(
      actualManifest.map(({ action, path: relative }) => `${action}|${relative}`),
    );
    const expectedRows = new Set(
      expectedManifest.map(
        ({ action, path: relative }) => `${action}|${relative}`,
      ),
    );
    const extra = [...actualRows].filter((row) => !expectedRows.has(row));
    const missing = [...expectedRows].filter((row) => !actualRows.has(row));
    if (extra.length > 0 || missing.length > 0) {
      fail(
        'Actual changes do not match the approved action/path manifest.',
        `extra=${extra.join(',')} missing=${missing.join(',')}`,
      );
    }
    state.execution.actual_changed_manifest = actualManifest;
    state.execution.actual_changed_paths = actualManifest.map(
      (entry) => entry.path,
    );
    delete state.execution.error;
    state.execution.verification = executeVerification(
      state.execution.worktree,
      state.consensus.verification,
      state.run_dir,
    );

    const bundle = buildImplementationBundle(
      state.execution.worktree,
      actualManifest,
      fs.readFileSync(state.consensus.work_order_file, 'utf8'),
    );
    fs.writeFileSync(
      path.join(state.run_dir, 'implementation-review-bundle.md'),
      bundle.text,
      'utf8',
    );
    state.execution.review_manifest_sha256 = bundle.manifestSha256;
    const reviewHash = bundle.manifestSha256.slice(0, 12);
    state.execution.reviews = {
      claude: invokeClaude({
        prompt: reviewImplementationPrompt(
          bundle.text,
          bundle.manifestSha256,
          'Claude Fable 5',
        ),
        schema: implementationReviewSchema,
        runDir: state.run_dir,
        label: `implementation-review-claude-${reviewHash}`,
        cwd: state.run_dir,
      }),
      codex: invokeCodex({
        prompt: reviewImplementationPrompt(
          bundle.text,
          bundle.manifestSha256,
          'Codex',
        ),
        schema: implementationReviewSchema,
        runDir: state.run_dir,
        label: `implementation-review-codex-${reviewHash}`,
        cwd: state.execution.worktree,
      }),
    };
    const approved = Object.values(state.execution.reviews).every(
      (review) =>
        review.verdict === 'approve' &&
        review.reviewed_manifest_sha256 === bundle.manifestSha256 &&
        !hasSevere(review.findings),
    );
    state.status = approved
      ? 'implementation_review_approved'
      : 'implementation_changes_required';
    saveState(state);
    printState(state);
  } catch (error) {
    state.status = 'execution_failed';
    state.execution.error = {
      message: error.message,
      details: error.details ?? '',
    };
    saveState(state);
    throw error;
  }
}

function commandPreflight(repoRoot) {
  process.stdout.write(`${JSON.stringify(preflight(repoRoot), null, 2)}\n`);
}

function usage() {
  process.stdout.write(`
PetSpace Codex × Claude consensus V2

  node scripts/agent-consensus.mjs preflight [--repo PATH]
  node scripts/agent-consensus.mjs self-test [--local] [--repo PATH]
  node scripts/agent-consensus.mjs authorize-source-review --include "glob,glob" --acknowledge-anthropic-transfer yes
  node scripts/agent-consensus.mjs start --topic "..." [--rounds 1..5]
  node scripts/agent-consensus.mjs approve-review <run-id> --code CODE
  node scripts/agent-consensus.mjs resume <run-id>
  node scripts/agent-consensus.mjs status <run-id>
  node scripts/agent-consensus.mjs approve <run-id> --code CODE [--executor codex|claude] [--acknowledge-claude-worktree-access yes] [--execute]
  node scripts/agent-consensus.mjs execute <run-id>
`);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0];
  const repoRoot = path.resolve(args.repo ?? defaultRepoRoot);
  if (!command || ['help', '--help', '-h'].includes(command)) {
    usage();
    return;
  }
  try {
    if (command === 'preflight') commandPreflight(repoRoot);
    else if (command === 'self-test') {
      commandSelfTest(repoRoot, args.local === true);
    } else if (command === 'authorize-source-review') {
      commandAuthorize(repoRoot, args);
    } else if (command === 'start') commandStart(repoRoot, args);
    else if (command === 'approve-review') {
      commandApproveReview(repoRoot, args._[1], args);
    } else if (command === 'resume') commandResume(repoRoot, args._[1]);
    else if (command === 'status') commandStatus(repoRoot, args._[1]);
    else if (command === 'approve') commandApprove(repoRoot, args._[1], args);
    else if (command === 'execute') commandExecute(repoRoot, args._[1]);
    else fail(`Unknown command: ${command}`);
  } catch (error) {
    process.stderr.write(`ERROR: ${error.message}\n`);
    if (error.details) process.stderr.write(`${error.details}\n`);
    process.exitCode = 1;
  }
}

export {
  actualChangedManifest,
  allowedVerification,
  canonicalJson,
  globToRegExp,
  normalizeRelativePath,
  normalizeVerificationCwd,
  policyAllows,
  repositorySnapshot,
  resolveVerificationProcess,
  statusPath,
  changedManifestFromSnapshot,
  copyDirtyBaseline,
  copyLocalRuntimeMetadata,
  createLocalSecretsStub,
  validateImplementationManifest,
  validateReviewManifest,
};

if (path.resolve(process.argv[1] ?? '') === path.resolve(scriptFile)) {
  main();
}
