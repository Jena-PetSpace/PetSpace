#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '..');
const runsRoot = path.join(repoRoot, '.agent-collab', 'runs');
const defaultBaseBranch = 'win-android-release';
const defaultMaxRounds = 3;
const claudeModel = process.env.CLAUDE_MODEL ?? 'claude-opus-4-8';
const processTimeoutMs = 30 * 60 * 1000;

const proposalSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'summary', 'assumptions', 'risks', 'questions', 'recommended_executor',
    'executor_reason', 'work_order_markdown'
  ],
  properties: {
    summary: { type: 'string' },
    assumptions: { type: 'array', items: { type: 'string' } },
    risks: { type: 'array', items: { type: 'string' } },
    questions: { type: 'array', items: { type: 'string' } },
    recommended_executor: { enum: ['claude', 'codex', 'human'] },
    executor_reason: { type: 'string' },
    work_order_markdown: { type: 'string' }
  }
};

const reviewSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'decision', 'summary', 'issues', 'recommended_executor', 'executor_reason',
    'final_work_order_markdown', 'human_decisions'
  ],
  properties: {
    decision: { enum: ['agree', 'revise', 'block'] },
    summary: { type: 'string' },
    issues: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'point', 'required_change'],
        properties: {
          severity: { enum: ['blocker', 'high', 'medium', 'low'] },
          point: { type: 'string' },
          required_change: { type: 'string' }
        }
      }
    },
    recommended_executor: { enum: ['claude', 'codex', 'human'] },
    executor_reason: { type: 'string' },
    final_work_order_markdown: { type: 'string' },
    human_decisions: { type: 'array', items: { type: 'string' } }
  }
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
    issues: { type: 'array', items: { type: 'string' } }
  }
};

const implementationReviewSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['verdict', 'summary', 'findings', 'verification_gaps'],
  properties: {
    verdict: { enum: ['approve', 'changes_required', 'block'] },
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
          minimum_fix: { type: 'string' }
        }
      }
    },
    verification_gaps: { type: 'array', items: { type: 'string' } }
  }
};

const ratificationSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['decision', 'recommended_executor', 'reason', 'blocking_issues'],
  properties: {
    decision: { enum: ['accept', 'reject'] },
    recommended_executor: { enum: ['claude', 'codex', 'human'] },
    reason: { type: 'string' },
    blocking_issues: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'issue'],
        properties: {
          severity: { enum: ['blocker', 'high'] },
          issue: { type: 'string' }
        }
      }
    }
  }
};

const investigationSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'status', 'summary', 'keep', 'consolidate', 'archive', 'delete_candidates',
    'human_decisions', 'evidence', 'report_markdown'
  ],
  properties: {
    status: { enum: ['complete', 'blocked'] },
    summary: { type: 'string' },
    keep: { type: 'array', items: { type: 'string' } },
    consolidate: { type: 'array', items: { type: 'string' } },
    archive: { type: 'array', items: { type: 'string' } },
    delete_candidates: { type: 'array', items: { type: 'string' } },
    human_decisions: { type: 'array', items: { type: 'string' } },
    evidence: { type: 'array', items: { type: 'string' } },
    report_markdown: { type: 'string' }
  }
};

const investigationReviewSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['verdict', 'summary', 'blocking_findings', 'corrections', 'phase_b_ready'],
  properties: {
    verdict: { enum: ['approve', 'revise', 'block'] },
    summary: { type: 'string' },
    blocking_findings: { type: 'array', items: { type: 'string' } },
    corrections: { type: 'array', items: { type: 'string' } },
    phase_b_ready: { type: 'boolean' }
  }
};

const cleanupManifestRatificationSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['decision', 'manifest_sha256', 'reason', 'blocker_high'],
  properties: {
    decision: { enum: ['accept', 'reject'] },
    manifest_sha256: { type: 'string' },
    reason: { type: 'string' },
    blocker_high: { type: 'array', items: { type: 'string' } }
  }
};

const cleanupPostReviewSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['verdict', 'summary', 'blocker_high'],
  properties: {
    verdict: { enum: ['approve', 'changes_required', 'block'] },
    summary: { type: 'string' },
    blocker_high: { type: 'array', items: { type: 'string' } }
  }
};

const uiuxWaveRatificationSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'decision', 'manifest_sha256', 'recommended_executor', 'reason',
    'blocker_high'
  ],
  properties: {
    decision: { enum: ['accept', 'reject'] },
    manifest_sha256: { type: 'string' },
    recommended_executor: { enum: ['claude', 'codex', 'human'] },
    reason: { type: 'string' },
    blocker_high: { type: 'array', items: { type: 'string' } }
  }
};

function fail(message, details = '') {
  process.stderr.write(`ERROR: ${message}\n`);
  if (details) process.stderr.write(`${details}\n`);
  process.exit(1);
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function parseArgs(argv) {
  const result = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const value = argv[i];
    if (!value.startsWith('--')) {
      result._.push(value);
      continue;
    }
    const key = value.slice(2);
    if (['execute', 'investigate', 'yes'].includes(key)) {
      result[key] = true;
      continue;
    }
    if (i + 1 >= argv.length) fail(`--${key} 값이 필요합니다.`);
    result[key] = argv[++i];
  }
  return result;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? repoRoot,
    input: options.input,
    encoding: 'utf8',
    windowsHide: true,
    timeout: options.timeout ?? processTimeoutMs,
    maxBuffer: 32 * 1024 * 1024,
    env: { ...process.env, ...(options.env ?? {}) }
  });
  if (result.error) {
    throw new Error(`${command} 실행 실패: ${result.error.message}`);
  }
  if (result.status !== 0) {
    throw new Error([
      `${command} 종료 코드 ${result.status}`,
      result.stdout?.trim(),
      result.stderr?.trim()
    ].filter(Boolean).join('\n'));
  }
  return { stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

function runAllowing(command, args, allowedStatuses, options = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? repoRoot,
    input: options.input,
    encoding: 'utf8',
    windowsHide: true,
    timeout: options.timeout ?? processTimeoutMs,
    maxBuffer: 32 * 1024 * 1024,
    env: { ...process.env, ...(options.env ?? {}) }
  });
  if (result.error) throw result.error;
  if (!allowedStatuses.includes(result.status)) {
    throw new Error(`${command} 종료 코드 ${result.status}\n${result.stderr ?? ''}`);
  }
  return { status: result.status, stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

function git(args, cwd = repoRoot) {
  return run('git', ['-c', `safe.directory=${repoRoot.replaceAll('\\', '/')}`, ...args], { cwd }).stdout.trim();
}

function locateClaude() {
  if (process.env.CLAUDE_BIN && fs.existsSync(process.env.CLAUDE_BIN)) return process.env.CLAUDE_BIN;
  const extensions = path.join(os.homedir(), '.vscode', 'extensions');
  if (fs.existsSync(extensions)) {
    const candidates = fs.readdirSync(extensions)
      .filter((name) => /^anthropic\.claude-code-.*-win32-x64$/i.test(name))
      .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))
      .map((name) => path.join(extensions, name, 'resources', 'native-binary', 'claude.exe'))
      .filter(fs.existsSync);
    if (candidates[0]) return candidates[0];
  }
  return 'claude';
}

function locateCodexEntry() {
  if (process.env.CODEX_JS && fs.existsSync(process.env.CODEX_JS)) return process.env.CODEX_JS;
  const appData = process.env.APPDATA;
  if (appData) {
    const candidate = path.join(appData, 'npm', 'node_modules', '@openai', 'codex', 'bin', 'codex.js');
    if (fs.existsSync(candidate)) return candidate;
  }
  fail('독립 Codex CLI를 찾지 못했습니다. npm install -g @openai/codex 후 다시 실행하세요.');
}

function extractClaudeStructured(stdout) {
  const wrapper = JSON.parse(stdout.trim());
  if (wrapper.structured_output) return wrapper.structured_output;
  if (typeof wrapper.result === 'string') return JSON.parse(wrapper.result);
  if (wrapper.result && typeof wrapper.result === 'object') return wrapper.result;
  throw new Error('Claude 구조화 출력에서 result를 찾지 못했습니다.');
}

function invokeClaude({ prompt, schema, mode, runDir, label, cwd = repoRoot }) {
  const claude = locateClaude();
  const promptFile = path.join(runDir, `${label}.prompt.md`);
  const stdoutFile = path.join(runDir, `${label}.claude.stdout.json`);
  const stderrFile = path.join(runDir, `${label}.claude.stderr.log`);
  fs.writeFileSync(promptFile, prompt, 'utf8');

  const args = [
    '-p',
    '--model', claudeModel,
    '--output-format', 'json',
    '--json-schema', JSON.stringify(schema),
    '--permission-mode', mode.startsWith('write') ? 'acceptEdits' : 'plan',
    '--no-session-persistence',
    '--effort', 'high',
    '--setting-sources', 'user,project,local'
  ];

  if (mode === 'write-limited') {
    args.push(
      '--allowed-tools', 'Edit,Write,Bash(dart format *),Bash(flutter analyze *),Bash(flutter test *)',
      '--disallowed-tools',
      'Read,Grep,Glob,Bash(git *),Bash(supabase *),Bash(powershell *),Bash(cmd *)'
    );
  } else if (mode === 'write') {
    args.push(
      '--allowed-tools', 'Read,Grep,Glob,Edit,Write,Bash',
      '--disallowed-tools',
      'Bash(git push *),Bash(git merge *),Bash(git rebase *),Bash(git reset *),Bash(git clean *),Bash(supabase *)'
    );
  } else if (mode === 'inspect') {
    args.push(
      '--allowed-tools', 'Read,Grep,Glob,Bash',
      '--disallowed-tools',
      'Edit,Write,Bash(rm *),Bash(mv *),Bash(cp *),Bash(git add *),Bash(git commit *),Bash(git push *),Bash(git switch *),Bash(git checkout *),Bash(git reset *),Bash(git clean *),Bash(git stash *),Bash(supabase *)'
    );
  } else {
    // 토론은 오케스트레이터가 만든 동일 인벤토리만 사용한다.
    // 에이전트별 임의 탐색 차이와 장시간 전체 스캔을 방지한다.
    args.push('--tools', '');
  }

  const result = run(claude, args, { cwd, input: prompt });
  fs.writeFileSync(stdoutFile, result.stdout, 'utf8');
  fs.writeFileSync(stderrFile, result.stderr, 'utf8');
  return extractClaudeStructured(result.stdout);
}

function invokeCodex({ prompt, schema, mode, runDir, label, cwd = repoRoot }) {
  const codexJs = locateCodexEntry();
  const promptFile = path.join(runDir, `${label}.prompt.md`);
  const schemaFile = path.join(runDir, `${label}.schema.json`);
  const outputFile = path.join(runDir, `${label}.codex.output.json`);
  const eventsFile = path.join(runDir, `${label}.codex.events.log`);
  fs.writeFileSync(promptFile, prompt, 'utf8');
  fs.writeFileSync(schemaFile, JSON.stringify(schema, null, 2), 'utf8');

  const args = [
    codexJs,
    '--strict-config',
    '--sandbox', mode === 'write' ? 'workspace-write' : 'read-only',
    '--ask-for-approval', 'never',
    '-C', cwd,
    'exec', '-',
    '--ephemeral',
    '--output-schema', schemaFile,
    '--output-last-message', outputFile,
    '--color', 'never'
  ];
  const result = run(process.execPath, args, { cwd, input: prompt });
  fs.writeFileSync(eventsFile, `${result.stdout}\n${result.stderr}`, 'utf8');
  return JSON.parse(fs.readFileSync(outputFile, 'utf8'));
}

function invokeAgent(agent, options) {
  return agent === 'claude' ? invokeClaude(options) : invokeCodex(options);
}

function otherAgent(agent) {
  return agent === 'claude' ? 'codex' : 'claude';
}

function safeJson(value) {
  return JSON.stringify(value, null, 2);
}

function lines(value) {
  return value ? value.split(/\r?\n/).filter(Boolean) : [];
}

function firstMarkdownHeading(file) {
  try {
    const content = fs.readFileSync(file, 'utf8').slice(0, 32 * 1024);
    return content.split(/\r?\n/).find((line) => /^#\s+/.test(line))?.replace(/^#\s+/, '') ?? '(제목 없음)';
  } catch {
    return '(읽기 실패)';
  }
}

function directorySnapshot(root, maxDepth = 3) {
  const excluded = new Set(['.git', '.agent-collab', 'build', '.dart_tool', 'node_modules']);
  const output = [];
  function visit(dir, depth) {
    if (depth > maxDepth) return;
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries.filter((item) => item.isDirectory()).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(dir, entry.name);
      const rel = path.relative(root, full).replaceAll('\\', '/');
      let immediateFiles = 0;
      try {
        immediateFiles = fs.readdirSync(full, { withFileTypes: true }).filter((item) => item.isFile()).length;
      } catch {
        // 접근 불가 디렉터리는 이름만 남긴다.
      }
      output.push(`${'  '.repeat(depth)}- ${rel}/ (직접 파일 ${immediateFiles})${excluded.has(entry.name) ? ' [탐색 제외]' : ''}`);
      if (!excluded.has(entry.name)) visit(full, depth + 1);
    }
  }
  visit(root, 0);
  return output;
}

function createRepositorySnapshot() {
  const tracked = lines(git(['ls-files']));
  const untracked = lines(git(['ls-files', '--others', '--exclude-standard']));
  const ignored = lines(git(['status', '--short', '--ignored'])).filter((line) => line.startsWith('!! '));
  const markdown = [...new Set([...tracked, ...untracked].filter((file) => /\.md$/i.test(file)))].sort();
  const markdownRows = markdown.map((file) => {
    const full = path.join(repoRoot, file);
    const size = fs.existsSync(full) ? fs.statSync(full).size : 0;
    const status = tracked.includes(file) ? 'tracked' : 'untracked';
    return `- [${status}] ${file} | ${size} bytes | ${firstMarkdownHeading(full)}`;
  });
  const docsReadme = fs.existsSync(path.join(repoRoot, 'docs', 'README.md'))
    ? fs.readFileSync(path.join(repoRoot, 'docs', 'README.md'), 'utf8')
    : '(없음)';
  const gitignore = fs.existsSync(path.join(repoRoot, '.gitignore'))
    ? fs.readFileSync(path.join(repoRoot, '.gitignore'), 'utf8')
    : '(없음)';
  return [
    '# 자동 생성 저장소 인벤토리',
    '',
    `- 기준 브랜치: ${git(['branch', '--show-current'])}`,
    `- 기준 HEAD: ${git(['rev-parse', 'HEAD'])}`,
    `- 추적 파일: ${tracked.length}`,
    `- 비무시 untracked 파일: ${untracked.length}`,
    `- Markdown: ${markdown.length}`,
    '',
    '## 디렉터리 구조(깊이 3, 생성물 내부 제외)',
    ...directorySnapshot(repoRoot),
    '',
    '## Git ignored 항목',
    ...(ignored.length ? ignored.map((item) => `- ${item}`) : ['- 없음']),
    '',
    '## 비무시 untracked 파일',
    ...(untracked.length ? untracked.map((item) => `- ${item}`) : ['- 없음']),
    '',
    '## Markdown 파일과 첫 제목',
    ...markdownRows,
    '',
    '## docs/README.md 정본 지도',
    docsReadme,
    '',
    '## .gitignore',
    gitignore
  ].join('\n').slice(0, 120_000);
}

function sha256File(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function recursiveStats(target) {
  if (!fs.existsSync(target)) return { exists: false, files: 0, directories: 0 };
  const stat = fs.lstatSync(target);
  if (!stat.isDirectory()) return { exists: true, type: stat.isFile() ? 'file' : 'other', files: stat.isFile() ? 1 : 0, directories: 0 };
  let files = 0;
  let directories = 0;
  const stack = [target];
  while (stack.length) {
    const dir = stack.pop();
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === '.git') {
        directories += 1;
        continue;
      }
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        directories += 1;
        stack.push(full);
      } else if (entry.isFile()) files += 1;
    }
  }
  return { exists: true, type: 'directory', files, directories };
}

function createCleanupEvidence() {
  const tracked = new Set(lines(git(['ls-files'])));
  const untracked = new Set(lines(git(['ls-files', '--others', '--exclude-standard'])));
  const markdown = [...new Set([...tracked, ...untracked].filter((file) => /\.md$/i.test(file)))]
    .filter((file) => !file.startsWith('.agent-collab/'))
    .sort();
  const records = markdown.map((file) => {
    const full = path.join(repoRoot, file);
    return {
      file,
      basename: path.basename(file).toLowerCase(),
      size: fs.statSync(full).size,
      hash: sha256File(full),
      content: fs.readFileSync(full, 'utf8')
    };
  });
  const exact = new Map();
  const names = new Map();
  for (const record of records) {
    const hashKey = `${record.hash}:${record.size}`;
    exact.set(hashKey, [...(exact.get(hashKey) ?? []), record.file]);
    names.set(record.basename, [...(names.get(record.basename) ?? []), record.file]);
  }
  const duplicateGroups = [...exact.entries()].filter(([, files]) => files.length > 1);
  const sameNameGroups = [...names.entries()].filter(([, files]) => files.length > 1);

  const brokenLinks = [];
  const linkPattern = /\[[^\]]*\]\(([^)]+)\)/g;
  for (const record of records) {
    let match;
    while ((match = linkPattern.exec(record.content)) !== null) {
      const raw = match[1].trim().replace(/^<|>$/g, '');
      if (!raw || /^(https?:|mailto:|#|data:)/i.test(raw)) continue;
      const withoutAnchor = raw.split('#')[0].split('?')[0];
      if (!withoutAnchor) continue;
      let decoded = withoutAnchor;
      try { decoded = decodeURIComponent(withoutAnchor); } catch { /* 원문 사용 */ }
      const target = path.resolve(path.dirname(path.join(repoRoot, record.file)), decoded.replaceAll('/', path.sep));
      if (!fs.existsSync(target)) brokenLinks.push(`${record.file} -> ${raw}`);
    }
  }

  const referenceLines = [];
  const duplicateFiles = new Set([
    ...duplicateGroups.flatMap(([, files]) => files),
    ...sameNameGroups.flatMap(([, files]) => files)
  ]);
  for (const file of [...duplicateFiles].sort()) {
    const basename = path.basename(file);
    const refs = records
      .filter((record) => record.file !== file && (record.content.includes(file) || record.content.includes(basename)))
      .map((record) => record.file);
    referenceLines.push(`- ${file}: ${refs.length ? refs.join(', ') : 'Markdown 참조 없음'}`);
  }

  const textFiles = [...tracked].filter((file) => {
    const full = path.join(repoRoot, file);
    if (!fs.existsSync(full)) return false;
    const stat = fs.statSync(full);
    if (!stat.isFile() || stat.size > 2 * 1024 * 1024) return false;
    const buffer = fs.readFileSync(full);
    return !buffer.subarray(0, 4096).includes(0);
  }).map((file) => ({ file, content: fs.readFileSync(path.join(repoRoot, file), 'utf8') }));

  const candidateNeedles = [
    'pjh/docs', 'test_reports', 'PetSpace+document', 'SUPABASE_SETUP',
    'HOSPITAL_SEARCH_FEATURE', 'libfeaturesonboardingpresentationwidgets'
  ];
  const fullReferences = candidateNeedles.map((needle) => {
    const hits = textFiles.filter((entry) => entry.content.includes(needle)).map((entry) => entry.file);
    return `- ${needle}: ${hits.length ? hits.join(', ') : '추적 텍스트 참조 없음'}`;
  });

  const differingPjhDocs = records.filter((record) => record.file.startsWith('pjh/docs/'));
  const diffSections = [];
  for (const source of differingPjhDocs) {
    const matches = records.filter((candidate) => candidate.file !== source.file && candidate.basename === source.basename);
    for (const target of matches) {
      if (source.hash === target.hash) continue;
      const diff = runAllowing('git', [
        'diff', '--no-index', '--no-color', '--unified=2', '--',
        path.join(repoRoot, target.file), path.join(repoRoot, source.file)
      ], [0, 1], { cwd: repoRoot }).stdout;
      diffSections.push(`### ${target.file} ↔ ${source.file}\n\n\`\`\`diff\n${diff.slice(0, 20_000)}\n\`\`\``);
    }
  }

  const trackedStatusRows = [...duplicateFiles].sort().map((file) =>
    `- ${file}: ${tracked.has(file) ? 'tracked' : untracked.has(file) ? 'untracked' : 'ignored/기타'}`
  );

  const sensitivePatterns = [
    ['email', /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i],
    ['phone', /(?:01[016789])[- .]?\d{3,4}[- .]?\d{4}/],
    ['secret-keyword', /api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret/i]
  ];
  const testReportFindings = [];
  for (const entry of textFiles.filter((item) => item.file.startsWith('pjh/test_reports/'))) {
    const categories = sensitivePatterns.filter(([, pattern]) => pattern.test(entry.content)).map(([name]) => name);
    if (categories.length) testReportFindings.push(`- ${entry.file}: ${categories.join(', ')} 패턴 감지(내용 비출력)`);
  }

  const legalFiles = fs.existsSync(path.join(repoRoot, 'docs', 'legal'))
    ? fs.readdirSync(path.join(repoRoot, 'docs', 'legal'), { withFileTypes: true }).map((entry) => `${entry.name}${entry.isDirectory() ? '/' : ''}`)
    : [];
  const qaFiles = fs.existsSync(path.join(repoRoot, 'docs', 'qa'))
    ? fs.readdirSync(path.join(repoRoot, 'docs', 'qa'), { withFileTypes: true }).map((entry) => `${entry.name}${entry.isDirectory() ? '/' : ''}`)
    : [];

  function checkIgnore(item) {
    const result = runAllowing('git', ['check-ignore', '-v', '--', item], [0, 1], { cwd: repoRoot });
    return result.status === 0 ? result.stdout.trim() : 'not ignored';
  }

  const specialPaths = [
    'libfeaturesonboardingpresentationwidgets',
    'pjh/docs',
    'pjh/test_reports',
    'pjh/nul',
    'pjh/.git',
    'pjh/build',
    'pjh/.dart_tool',
    'supabase/.temp'
  ];
  const specialRows = specialPaths.map((item) => `- ${item}: ${safeJson(recursiveStats(path.join(repoRoot, item)))}`);
  const gitState = git(['status', '--short', '--ignored']);

  return [
    '# 저장소 정리 결정론적 증거', '',
    `- 현재 브랜치: ${git(['branch', '--show-current'])}`,
    `- 현재 HEAD: ${git(['rev-parse', 'HEAD'])}`,
    `- 기준 브랜치 HEAD: ${git(['rev-parse', defaultBaseBranch])}`,
    `- Markdown 조사 수: ${records.length}`,
    `- 정확히 동일한 중복 그룹: ${duplicateGroups.length}`,
    `- 동일 파일명 그룹: ${sameNameGroups.length}`,
    '', '## SHA-256가 같은 Markdown 그룹',
    ...(duplicateGroups.length ? duplicateGroups.map(([key, files]) => `- ${key}: ${files.join(' | ')}`) : ['- 없음']),
    '', '## 파일명이 같은 Markdown 그룹',
    ...(sameNameGroups.length ? sameNameGroups.map(([name, files]) => `- ${name}: ${files.join(' | ')}`) : ['- 없음']),
    '', '## 중복 후보의 다른 Markdown 참조',
    ...(referenceLines.length ? referenceLines : ['- 없음']),
    '', '## 코드·CI·스크립트 포함 전체 추적 텍스트 참조',
    ...fullReferences,
    '', '## 중복 후보 Git 추적 상태',
    ...(trackedStatusRows.length ? trackedStatusRows : ['- 없음']),
    '', '## 바이트가 다른 pjh/docs 동명 문서 실제 diff(각 20KB 제한)',
    ...(diffSections.length ? diffSections : ['- 없음']),
    '', '## 상대 링크 누락 후보',
    ...(brokenLinks.length ? brokenLinks.map((item) => `- ${item}`) : ['- 없음']),
    '', '## 특수·정리 후보 경로 재귀 통계',
    ...specialRows,
    '', '## 개별 ignore 판정',
    `- pjh/android/.kotlin: ${checkIgnore('pjh/android/.kotlin')}`,
    `- pjh/nul: ${checkIgnore('pjh/nul')}`,
    '', '## docs/legal 실제 항목',
    ...legalFiles.map((item) => `- ${item}`),
    '', '## docs/qa 실제 항목',
    ...qaFiles.map((item) => `- ${item}`),
    '', '## pjh/test_reports 민감정보 패턴 점검',
    ...(testReportFindings.length ? testReportFindings : ['- email/phone/secret-keyword 패턴 없음']),
    '', '## 현재 추적 변경',
    '```text', git(['diff', '--name-status']), '```',
    '', '## 현재 비무시 상태',
    '```text', git(['status', '--short']), '```',
    '', '## Git status --short --ignored',
    '```text', gitState, '```'
  ].join('\n').slice(0, 120_000);
}

function createRunId(topic) {
  const date = new Date().toISOString().slice(0, 10).replaceAll('-', '');
  const slug = topic
    .normalize('NFKD')
    .replace(/[^a-zA-Z0-9가-힣]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 30) || 'task';
  return `${date}-${slug}-${crypto.randomBytes(2).toString('hex')}`;
}

function saveState(runDir, state) {
  state.updatedAt = new Date().toISOString();
  fs.writeFileSync(path.join(runDir, 'state.json'), `${safeJson(state)}\n`, 'utf8');
}

function loadState(runId) {
  const runDir = path.join(runsRoot, runId);
  const stateFile = path.join(runDir, 'state.json');
  if (!fs.existsSync(stateFile)) fail(`실행 기록을 찾지 못했습니다: ${runId}`);
  return { runDir, state: JSON.parse(fs.readFileSync(stateFile, 'utf8')) };
}

function baseContext(topic, snapshot) {
  return `
당신은 PetSpace 저장소의 협업 설계 에이전트다.
루트 AGENTS.md와 docs/README.md가 지정한 현행 문서를 반드시 읽고 준수한다.
현재 단계는 읽기 전용 토론이다. 파일 수정, 커밋, 브랜치 변경, push, DB 실행을 하지 않는다.
아래 인벤토리는 오케스트레이터가 Git과 파일시스템에서 생성한 공통 스냅샷이다.
이번 토론에서는 추가 도구 호출이나 전체 저장소 재탐색을 하지 말고 이 동일한 스냅샷만 근거로 사용한다.
내용 확인이 더 필요한 파일은 삭제로 단정하지 말고 사전 확인 항목으로 작업지시서에 넣는다.

사용자 주제:
${topic}

목표:
- 확인된 코드와 문서 근거로 구현 가능한 작업 범위를 만든다.
- 보안, 법무, 개인정보, 출시 위험과 검증 조건을 명시한다.
- Claude와 Codex 중 적합한 실행자를 추천한다.
- 사람이 승인할 수 있는 완전한 Markdown 작업지시서를 작성한다.

공통 저장소 인벤토리:
${snapshot}
`;
}

function proposalPrompt(topic, snapshot, previous = null) {
  const prior = previous ? `\n이전 제안과 반론:\n${safeJson(previous)}\n` : '';
  return `${baseContext(topic, snapshot)}${prior}
초안 또는 수정안을 작성하라. 추측을 사실로 쓰지 말고 근거가 부족한 항목은 질문으로 분리하라.
work_order_markdown에는 목표, 확인된 사실, 수정 범위, 비요구사항, 완료 조건, 검증 명령,
사람 검증, 위험·중단 조건, 완료 보고 형식을 포함하라.
최종 응답은 제공된 JSON 스키마만 따른다.`;
}

function reviewPrompt(topic, snapshot, proposal, author) {
  return `${baseContext(topic, snapshot)}
${author}가 작성한 제안:
${safeJson(proposal)}

제안을 비판적으로 검토하라. 코드 근거가 부족하거나 범위·완료 조건·보안·법무·테스트가 빠졌으면 revise 또는 block으로 판정한다.
실행자 추천도 독립적으로 판단한다. 동의하면 final_work_order_markdown에 승인 가능한 최종 지시서를 넣는다.
수정이 필요하면 반드시 반영된 전체 작업지시서를 final_work_order_markdown에 넣는다.
최종 응답은 제공된 JSON 스키마만 따른다.`;
}

function hasSevereIssues(review) {
  return review.issues.some((issue) => ['blocker', 'high'].includes(issue.severity));
}

function printRunSummary(state) {
  process.stdout.write(`\nRun ID: ${state.id}\n`);
  process.stdout.write(`상태: ${state.status}\n`);
  if (state.consensus) {
    process.stdout.write(`합의 실행자: ${state.consensus.executor}\n`);
    process.stdout.write(`작업지시서: ${state.consensus.workOrderFile}\n`);
  }
  if (state.approval?.code && !state.approval.approvedAt) {
    process.stdout.write(`승인 코드: ${state.approval.code}\n`);
    process.stdout.write(`승인 후 실행: node scripts/agent-collab.mjs approve ${state.id} --code ${state.approval.code} --execute\n`);
  }
  if (state.execution?.worktree) process.stdout.write(`worktree: ${state.execution.worktree}\n`);
}

function commandPreflight() {
  const claude = locateClaude();
  const codexJs = locateCodexEntry();
  const claudeVersion = run(claude, ['--version']).stdout.trim();
  const codexVersion = run(process.execPath, [codexJs, '--version']).stdout.trim();
  const claudeAuth = run(claude, ['auth', 'status']).stdout.trim();
  const codexAuthResult = run(process.execPath, [codexJs, 'login', 'status']);
  const codexAuth = codexAuthResult.stdout.trim() || codexAuthResult.stderr.trim();
  const branch = git(['branch', '--show-current']);
  const status = git(['status', '--porcelain']);
  process.stdout.write(`${safeJson({
    repoRoot,
    branch,
    workingTreeClean: status.length === 0,
    claude: {
      binary: claude,
      model: claudeModel,
      version: claudeVersion,
      auth: (() => {
        const value = JSON.parse(claudeAuth);
        return {
          loggedIn: value.loggedIn,
          authMethod: value.authMethod,
          apiProvider: value.apiProvider,
          subscriptionType: value.subscriptionType
        };
      })()
    },
    codex: { entry: codexJs, version: codexVersion, auth: codexAuth }
  })}\n`);
}

function commandSelfTest() {
  const schema = {
    type: 'object',
    additionalProperties: false,
    required: ['ok', 'agent', 'note'],
    properties: {
      ok: { type: 'boolean' },
      agent: { enum: ['claude', 'codex'] },
      note: { type: 'string' }
    }
  };
  const runDir = path.join(runsRoot, `self-test-${Date.now()}`);
  ensureDir(runDir);
  const claude = invokeClaude({
    prompt: '파일을 수정하거나 명령을 실행하지 말고 구조화 출력 연결 시험에 성공했다고 답하라. agent는 claude다.',
    schema,
    mode: 'read',
    runDir,
    label: 'self-test-claude'
  });
  const codex = invokeCodex({
    prompt: '파일을 수정하거나 명령을 실행하지 말고 구조화 출력 연결 시험에 성공했다고 답하라. agent는 codex다.',
    schema,
    mode: 'read',
    runDir,
    label: 'self-test-codex'
  });
  process.stdout.write(`${safeJson({ ok: claude.ok === true && codex.ok === true, claude, codex, logs: runDir })}\n`);
}

function commandStart(args) {
  const topic = args.topic ?? args._.slice(1).join(' ');
  if (!topic) fail('start에는 --topic "주제"가 필요합니다.');
  const first = args.first ?? 'codex';
  if (!['claude', 'codex'].includes(first)) fail('--first는 claude 또는 codex여야 합니다.');
  const maxRounds = Number(args.rounds ?? defaultMaxRounds);
  if (!Number.isInteger(maxRounds) || maxRounds < 1 || maxRounds > 5) fail('--rounds는 1~5 정수여야 합니다.');
  const baseBranch = args.base ?? defaultBaseBranch;
  let baseCommit;
  try {
    baseCommit = git(['rev-parse', baseBranch]);
  } catch (error) {
    fail(`기준 브랜치를 찾지 못했습니다: ${baseBranch}`, error.message);
  }

  const id = createRunId(topic);
  const runDir = path.join(runsRoot, id);
  ensureDir(runDir);
  const state = {
    version: 1,
    id,
    topic,
    status: 'discussing',
    first,
    baseBranch,
    baseCommit,
    maxRounds,
    createdAt: new Date().toISOString(),
    rounds: []
  };
  const snapshot = createRepositorySnapshot();
  const snapshotFile = path.join(runDir, 'repository-inventory.md');
  fs.writeFileSync(snapshotFile, snapshot, 'utf8');
  state.inventoryFile = snapshotFile;
  saveState(runDir, state);

  let author = first;
  let previous = null;
  for (let round = 1; round <= maxRounds; round += 1) {
    const reviewer = otherAgent(author);
    process.stdout.write(`[${round}/${maxRounds}] ${author} 제안 작성 중...\n`);
    const proposal = invokeAgent(author, {
      prompt: proposalPrompt(topic, snapshot, previous),
      schema: proposalSchema,
      mode: 'read',
      runDir,
      label: `round-${round}-proposal-${author}`
    });
    fs.writeFileSync(path.join(runDir, `round-${round}-proposal.json`), `${safeJson(proposal)}\n`, 'utf8');

    process.stdout.write(`[${round}/${maxRounds}] ${reviewer} 교차 검토 중...\n`);
    const review = invokeAgent(reviewer, {
      prompt: reviewPrompt(topic, snapshot, proposal, author),
      schema: reviewSchema,
      mode: 'read',
      runDir,
      label: `round-${round}-review-${reviewer}`
    });
    fs.writeFileSync(path.join(runDir, `round-${round}-review.json`), `${safeJson(review)}\n`, 'utf8');
    state.rounds.push({ round, author, reviewer, proposal, review });
    saveState(runDir, state);

    const agreed = review.decision === 'agree'
      && review.recommended_executor === proposal.recommended_executor
      && review.recommended_executor !== 'human'
      && !hasSevereIssues(review);
    if (agreed) {
      const workOrderFile = path.join(runDir, 'work-order.md');
      const workOrder = review.final_work_order_markdown || proposal.work_order_markdown;
      fs.writeFileSync(workOrderFile, `${workOrder.trim()}\n`, 'utf8');
      state.status = 'awaiting_approval';
      state.consensus = {
        round,
        executor: review.recommended_executor,
        author,
        reviewer,
        workOrderFile,
        summary: review.summary,
        executorReason: review.executor_reason
      };
      state.approval = { code: crypto.randomBytes(3).toString('hex').toUpperCase() };
      saveState(runDir, state);
      printRunSummary(state);
      return;
    }

    previous = { proposal, review };
    if (review.decision === 'block') break;
    author = reviewer;
  }

  state.status = 'needs_human_decision';
  const last = state.rounds.at(-1);
  fs.writeFileSync(path.join(runDir, 'dispute.md'), [
    '# AI 합의 실패', '', `주제: ${topic}`, '',
    '## 마지막 제안', '```json', safeJson(last?.proposal ?? {}), '```', '',
    '## 마지막 검토', '```json', safeJson(last?.review ?? {}), '```', ''
  ].join('\n'), 'utf8');
  saveState(runDir, state);
  printRunSummary(state);
}

function commandStatus(runId) {
  const { state } = loadState(runId);
  process.stdout.write(`${safeJson(state)}\n`);
  printRunSummary(state);
}

function applyConsensus(runDir, state, round, author, reviewer, proposal, review) {
  const workOrderFile = path.join(runDir, 'work-order.md');
  const workOrder = review.final_work_order_markdown || proposal.work_order_markdown;
  fs.writeFileSync(workOrderFile, `${workOrder.trim()}\n`, 'utf8');
  state.status = 'awaiting_approval';
  state.consensus = {
    round,
    executor: review.recommended_executor,
    author,
    reviewer,
    workOrderFile,
    summary: review.summary,
    executorReason: review.executor_reason
  };
  state.approval = { code: crypto.randomBytes(3).toString('hex').toUpperCase() };
  saveState(runDir, state);
  printRunSummary(state);
}

function commandContinue(runId, args) {
  const { runDir, state } = loadState(runId);
  if (state.status !== 'needs_human_decision') fail(`토론을 이어갈 수 없는 상태입니다: ${state.status}`);
  const additionalRounds = Number(args.rounds ?? 1);
  if (!Number.isInteger(additionalRounds) || additionalRounds < 1 || additionalRounds > 3) {
    fail('--rounds는 1~3 정수여야 합니다.');
  }
  const snapshot = fs.readFileSync(state.inventoryFile, 'utf8');
  let previous = {
    proposal: state.rounds.at(-1)?.proposal,
    review: state.rounds.at(-1)?.review
  };
  let author = state.rounds.at(-1)?.reviewer ?? state.first;
  const startRound = state.rounds.length + 1;
  state.status = 'discussing';
  state.maxRounds += additionalRounds;
  saveState(runDir, state);

  for (let offset = 0; offset < additionalRounds; offset += 1) {
    const round = startRound + offset;
    const reviewer = otherAgent(author);
    process.stdout.write(`[추가 ${offset + 1}/${additionalRounds}] ${author} 수정안 작성 중...\n`);
    const proposal = invokeAgent(author, {
      prompt: proposalPrompt(state.topic, snapshot, previous),
      schema: proposalSchema,
      mode: 'read',
      runDir,
      label: `round-${round}-proposal-${author}`
    });
    fs.writeFileSync(path.join(runDir, `round-${round}-proposal.json`), `${safeJson(proposal)}\n`, 'utf8');
    process.stdout.write(`[추가 ${offset + 1}/${additionalRounds}] ${reviewer} 최종 검토 중...\n`);
    const review = invokeAgent(reviewer, {
      prompt: reviewPrompt(state.topic, snapshot, proposal, author),
      schema: reviewSchema,
      mode: 'read',
      runDir,
      label: `round-${round}-review-${reviewer}`
    });
    fs.writeFileSync(path.join(runDir, `round-${round}-review.json`), `${safeJson(review)}\n`, 'utf8');
    state.rounds.push({ round, author, reviewer, proposal, review });
    saveState(runDir, state);
    const agreed = review.decision === 'agree'
      && review.recommended_executor === proposal.recommended_executor
      && review.recommended_executor !== 'human'
      && !hasSevereIssues(review);
    if (agreed) {
      applyConsensus(runDir, state, round, author, reviewer, proposal, review);
      return;
    }
    previous = { proposal, review };
    if (review.decision === 'block') break;
    author = reviewer;
  }
  state.status = 'needs_human_decision';
  saveState(runDir, state);
  printRunSummary(state);
}

function ratificationPrompt(state, candidate) {
  return `
당신은 PetSpace 협업 작업지시서의 최종 비준자다.
아래 후보 문서는 현재 Phase A 읽기 전용 조사만 승인 대상으로 삼으며 삭제·이동·통합·커밋을 승인하지 않는다.
문구 개선, 더 좋은 표현, medium/low 개선점은 거부 사유가 아니다.
데이터 손실, 보안·법무·개인정보 침해, 사용자 변경 훼손, 읽기 전용 경계 위반처럼 Phase A 시작을 막는 blocker/high 문제만 판단하라.
blocking_issues가 없으면 accept해야 한다. 실행자도 독립적으로 추천하라.
추가 도구 호출이나 저장소 탐색 없이 후보 문서만 평가하고 제공된 JSON 스키마로 응답하라.

주제:
${state.topic}

비준 후보 작업지시서:
${candidate}
`;
}

function commandRatify(runId) {
  const { runDir, state } = loadState(runId);
  if (state.status !== 'needs_human_decision') fail(`비준할 수 없는 상태입니다: ${state.status}`);
  const lastReview = state.rounds.at(-1)?.review;
  const candidate = lastReview?.final_work_order_markdown;
  if (!candidate) fail('비준할 최종 작업지시서를 찾지 못했습니다.');
  const results = {};
  for (const agent of ['claude', 'codex']) {
    process.stdout.write(`${agent} 독립 비준 중...\n`);
    results[agent] = invokeAgent(agent, {
      prompt: ratificationPrompt(state, candidate),
      schema: ratificationSchema,
      mode: 'read',
      runDir,
      label: `ratification-${agent}`
    });
  }
  state.ratification = results;
  const accepted = results.claude.decision === 'accept'
    && results.codex.decision === 'accept'
    && results.claude.blocking_issues.length === 0
    && results.codex.blocking_issues.length === 0
    && results.claude.recommended_executor === results.codex.recommended_executor
    && results.claude.recommended_executor !== 'human';
  if (accepted) {
    const workOrderFile = path.join(runDir, 'work-order.md');
    fs.writeFileSync(workOrderFile, `${candidate.trim()}\n`, 'utf8');
    state.status = 'awaiting_approval';
    state.consensus = {
      round: 'ratification',
      executor: results.claude.recommended_executor,
      author: 'joint',
      reviewer: 'joint',
      workOrderFile,
      summary: 'Claude와 Codex가 고정된 최종안에 blocker/high 문제 없음으로 독립 비준함.',
      executorReason: `${results.claude.reason} / ${results.codex.reason}`
    };
    state.approval = { code: crypto.randomBytes(3).toString('hex').toUpperCase() };
  } else {
    state.status = 'needs_human_decision';
  }
  saveState(runDir, state);
  printRunSummary(state);
  process.stdout.write(`${safeJson(results)}\n`);
}

function investigationPrompt(state, workOrder, evidence) {
  return `
루트 AGENTS.md와 아래 비준된 작업지시서의 Phase A 읽기 전용 조사만 수행하라.
파일 생성·수정·이동·삭제, staging, commit, 브랜치 변경, push, DB 실행을 하지 않는다.
오케스트레이터가 아래에 제공한 결정론적 증거만 분석하고 추가 도구 호출이나 저장소 탐색을 하지 않는다.
민감정보를 발견하면 내용을 출력하지 말고 경로와 중단 사유만 남긴다.
보고서는 저장소 파일로 쓰지 않고 구조화 최종 응답의 report_markdown에만 넣는다.

비준된 작업지시서:
${workOrder}

결정론적 조사 증거:
${evidence}
`;
}

function investigationReviewPrompt(state, workOrder, result) {
  return `
루트 AGENTS.md와 비준된 작업지시서를 기준으로 아래 Phase A 조사 결과를 read-only 교차 리뷰하라.
추가 저장소 탐색이나 파일 수정은 하지 않는다. 근거가 없는 삭제 후보, 보호 경로 침범, 데이터 손실 위험,
누락된 사람 결정만 판단한다. 최종 응답은 제공된 JSON 스키마만 따른다.

작업지시서:
${workOrder}

Phase A 조사 결과:
${safeJson(result)}
`;
}

function executeInvestigation(runDir, state) {
  if (!state.approval?.approvedAt) fail('사람 승인 기록이 없습니다.');
  const workOrder = fs.readFileSync(state.consensus.workOrderFile, 'utf8');
  const executor = state.consensus.executor;
  const reviewer = otherAgent(executor);
  const evidence = createCleanupEvidence();
  const evidenceFile = path.join(runDir, 'investigation-evidence.md');
  fs.writeFileSync(evidenceFile, evidence, 'utf8');
  state.status = 'investigating';
  state.investigationEvidenceFile = evidenceFile;
  saveState(runDir, state);
  process.stdout.write(`${executor}가 Phase A 읽기 전용 조사 중...\n`);
  const result = invokeAgent(executor, {
    prompt: investigationPrompt(state, workOrder, evidence),
    schema: investigationSchema,
    mode: 'read',
    runDir,
    label: `investigation-${executor}`
  });
  fs.writeFileSync(path.join(runDir, 'investigation-result.json'), `${safeJson(result)}\n`, 'utf8');
  process.stdout.write(`${reviewer}가 조사 결과를 read-only 교차 리뷰 중...\n`);
  const review = invokeAgent(reviewer, {
    prompt: investigationReviewPrompt(state, workOrder, result),
    schema: investigationReviewSchema,
    mode: 'read',
    runDir,
    label: `investigation-review-${reviewer}`
  });
  fs.writeFileSync(path.join(runDir, 'investigation-review.json'), `${safeJson(review)}\n`, 'utf8');
  state.investigation = { executor, reviewer, result, review };
  state.status = review.verdict === 'block' ? 'needs_human_decision' : 'awaiting_phase_b_approval';
  saveState(runDir, state);
  printRunSummary(state);
}

function commandInvestigate(runId) {
  const { runDir, state } = loadState(runId);
  if (!state.approval?.approvedAt) fail('승인되지 않은 run입니다.');
  if (!['approved', 'investigating', 'execution_failed', 'needs_human_decision'].includes(state.status)) {
    fail(`조사를 실행할 수 없는 상태입니다: ${state.status}`);
  }
  executeInvestigation(runDir, state);
}

function cleanupManifestRatificationPrompt(manifest, manifestSha) {
  return `
당신은 PetSpace 저장소 정리 manifest의 독립 최종 비준자다.
아래 manifest에 적힌 작업만 검토한다. manifest가 명시적으로 KEEP/격리한 보안·개인정보·고유 문서는 이번 실행 범위 밖이다.
정확한 삭제 경로, 보존 정본, 정규화 해시, 참조 0건, Git 복구, 생성물 재생성, 보호 경계와 사후 검증을 검토하라.
blocker/high가 없으면 accept해야 한다. medium/low 개선이나 범위 밖 후속 작업은 reject 사유가 아니다.
추가 도구 호출이나 저장소 탐색 없이 manifest만 평가하고 제공된 JSON 스키마로 응답하라.
manifest_sha256에는 아래 제공된 값을 글자 그대로 반환하라.

manifest_sha256: ${manifestSha}

manifest:
${manifest}
`;
}

function commandRatifyCleanup(runId) {
  const { runDir, state } = loadState(runId);
  const manifestFile = path.join(runDir, 'safe-cleanup-manifest.md');
  if (!fs.existsSync(manifestFile)) fail(`정리 manifest를 찾지 못했습니다: ${manifestFile}`);
  const manifest = fs.readFileSync(manifestFile, 'utf8');
  const manifestSha = crypto.createHash('sha256').update(manifest, 'utf8').digest('hex');
  const results = {};
  for (const agent of ['claude', 'codex']) {
    process.stdout.write(`${agent}가 안전 정리 manifest를 독립 비준 중...\n`);
    results[agent] = invokeAgent(agent, {
      prompt: cleanupManifestRatificationPrompt(manifest, manifestSha),
      schema: cleanupManifestRatificationSchema,
      mode: 'read',
      runDir,
      label: `safe-cleanup-ratification-${agent}`
    });
  }
  const accepted = ['claude', 'codex'].every((agent) =>
    results[agent].decision === 'accept'
      && results[agent].manifest_sha256 === manifestSha
      && results[agent].blocker_high.length === 0
  );
  state.safeCleanupRatification = {
    manifestFile,
    manifestSha256: manifestSha,
    accepted,
    results,
    ratifiedAt: new Date().toISOString()
  };
  state.status = accepted ? 'safe_cleanup_approved' : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'safe-cleanup-ratification.json'),
    `${safeJson(state.safeCleanupRatification)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.safeCleanupRatification)}\n`);
}

function cleanupPostReviewPrompt(manifest, executionReport, cleanupDiff) {
  return `
당신은 PetSpace SAFE-CLEANUP 실행 결과의 독립 사후 리뷰어다.
manifest 범위와 실제 cleanup diff·실행 보고가 일치하는지, 보존 정본·참조·보호 경로·Flutter 복원 검증이 충분한지 판단하라.
범위 밖 API 키·test_reports·고유 문서는 격리되어 있으므로 이번 사후 리뷰의 reject 사유가 아니다.
blocker/high가 없으면 approve한다. medium/low 후속 개선은 summary에만 적고 changes_required로 만들지 않는다.
추가 도구 호출 없이 제공 자료만 검토하고 JSON 스키마로 응답하라.

manifest:
${manifest}

execution report:
${executionReport}

cleanup git diff:
${cleanupDiff}
`;
}

function commandReviewCleanup(runId) {
  const { runDir, state } = loadState(runId);
  if (!state.safeCleanupRatification?.accepted) fail('양쪽이 승인한 SAFE-CLEANUP manifest가 없습니다.');
  const manifest = fs.readFileSync(state.safeCleanupRatification.manifestFile, 'utf8');
  const reportFile = path.join(runDir, 'safe-cleanup-execution.md');
  if (!fs.existsSync(reportFile)) fail(`실행 보고서를 찾지 못했습니다: ${reportFile}`);
  const executionReport = fs.readFileSync(reportFile, 'utf8');
  const cleanupPaths = [
    'pjh/docs/DEVELOPER/improvement_plan.md',
    'pjh/docs/DEVELOPER/p0_fixes_2026-03-26.md',
    'pjh/docs/DEVELOPER/work_log_2026-03-30.md',
    'pjh/docs/DEVELOPER/work_log_2026-03-31.md',
    'pjh/docs/PetSpace+document.md',
    'pjh/docs/PetSpace+document_updated.md',
    'pjh/docs/develop/branch-strategy.md'
  ];
  const cleanupDiff = git(['diff', '--', ...cleanupPaths]);
  const results = {};
  for (const agent of ['claude', 'codex']) {
    process.stdout.write(`${agent}가 SAFE-CLEANUP 결과를 독립 사후 리뷰 중...\n`);
    results[agent] = invokeAgent(agent, {
      prompt: cleanupPostReviewPrompt(manifest, executionReport, cleanupDiff),
      schema: cleanupPostReviewSchema,
      mode: 'read',
      runDir,
      label: `safe-cleanup-post-review-${agent}`
    });
  }
  const approved = ['claude', 'codex'].every((agent) =>
    results[agent].verdict === 'approve' && results[agent].blocker_high.length === 0
  );
  state.safeCleanupReview = { approved, results, reviewedAt: new Date().toISOString() };
  state.status = approved ? 'safe_cleanup_complete' : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'safe-cleanup-post-review.json'),
    `${safeJson(state.safeCleanupReview)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.safeCleanupReview)}\n`);
}

function uiuxPlanningProposalPrompt(audit, masterWorkOrder, previous) {
  return `
당신은 PetSpace의 제품 기획자이자 시니어 모바일 UI/UX 설계자다.
루트 AGENTS.md의 보안·법무·데이터·Git 경계를 지킨다. 지금은 구현하지 않고 기획·작업지시서만 합의한다.
아래 Codex 사전 감사와 마스터 작업지시서를 코드 근거, 기존 AppTheme v2 결정, 복구 가능한 레퍼런스 범위에 맞게 검토하라.
홈 실제 본체와 home 하위 위젯, emotion presentation은 직접 수정 금지다.
58개 대상 페이지를 한 번에 치환하지 말고 검증 가능한 wave로 나눈다.
첫 구현 wave의 실행자 1명(claude 또는 codex)을 추천하고, 반대 AI를 교차 리뷰어로 둔다.
work_order_markdown에는 보호 경로, 디자인 계약, 정확한 wave 순서, 첫 wave 허용 범위, 완료 조건, 검증, 중단 조건을 포함한 자급식 최종안을 작성하라.
추가 도구 호출 없이 제공 문서만 검토하고 JSON 스키마로 응답하라.

Codex 사전 감사:
${audit}

마스터 작업지시서 초안:
${masterWorkOrder}

${previous ? `이전 제안·검토:\n${safeJson(previous)}` : ''}
`;
}

function uiuxPlanningReviewPrompt(audit, masterWorkOrder, proposal, author) {
  return `
당신은 PetSpace UI/UX 마스터 계획의 독립 교차 리뷰어다.
아래 사전 감사·초안과 ${author}의 제안을 대조하라. 구현하지 않는다.
correctness, 보호 화면 침범, 기능·라우팅·상태 회귀, 법무·수의학 문구, 디자인 시스템 드리프트, 접근성, 검증 가능성 순으로 본다.
blocker/high가 없고 실행자·wave·보호 범위가 타당하면 agree한다. medium/low 표현 개선만으로 request_changes 하지 않는다.
final_work_order_markdown에는 동의 가능한 완결된 최종안을 반환한다.
추가 도구 호출 없이 제공 자료만 검토하고 JSON 스키마로 응답하라.

Codex 사전 감사:
${audit}

마스터 작업지시서 초안:
${masterWorkOrder}

${author} 제안:
${safeJson(proposal)}
`;
}

function commandReviewUiuxPlan(args) {
  const auditFile = path.join(repoRoot, 'docs', 'reviews', 'uiux_code_audit_2026-07-13.md');
  const masterFile = path.join(repoRoot, 'docs', 'work-orders', '2026-07-14-uiux-overhaul-master.md');
  if (!fs.existsSync(auditFile) || !fs.existsSync(masterFile)) fail('UI/UX 감사서 또는 마스터 작업지시서가 없습니다.');
  const audit = fs.readFileSync(auditFile, 'utf8');
  const masterWorkOrder = fs.readFileSync(masterFile, 'utf8');
  const maxRounds = Number(args.rounds ?? 3);
  if (!Number.isInteger(maxRounds) || maxRounds < 1 || maxRounds > 5) fail('--rounds는 1~5 정수여야 합니다.');
  const id = createRunId('UIUX-master-plan-review');
  const runDir = path.join(runsRoot, id);
  ensureDir(runDir);
  const state = {
    version: 1,
    id,
    topic: '홈·AI 분석 제외 UI/UX 마스터 계획 교차 검토',
    status: 'discussing',
    first: 'claude',
    baseBranch: defaultBaseBranch,
    baseCommit: git(['rev-parse', defaultBaseBranch]),
    maxRounds,
    createdAt: new Date().toISOString(),
    rounds: []
  };
  saveState(runDir, state);
  let author = 'claude';
  let previous = null;
  for (let round = 1; round <= maxRounds; round += 1) {
    const reviewer = otherAgent(author);
    process.stdout.write(`[UIUX ${round}/${maxRounds}] ${author} 계획 제안 중...\n`);
    const proposal = invokeAgent(author, {
      prompt: uiuxPlanningProposalPrompt(audit, masterWorkOrder, previous),
      schema: proposalSchema,
      mode: 'read',
      runDir,
      label: `uiux-round-${round}-proposal-${author}`
    });
    process.stdout.write(`[UIUX ${round}/${maxRounds}] ${reviewer} 교차 검토 중...\n`);
    const review = invokeAgent(reviewer, {
      prompt: uiuxPlanningReviewPrompt(audit, masterWorkOrder, proposal, author),
      schema: reviewSchema,
      mode: 'read',
      runDir,
      label: `uiux-round-${round}-review-${reviewer}`
    });
    state.rounds.push({ round, author, reviewer, proposal, review });
    saveState(runDir, state);
    const agreed = review.decision === 'agree'
      && review.recommended_executor === proposal.recommended_executor
      && review.recommended_executor !== 'human'
      && !hasSevereIssues(review);
    if (agreed) {
      const workOrderFile = path.join(runDir, 'work-order.md');
      const workOrder = review.final_work_order_markdown || proposal.work_order_markdown;
      fs.writeFileSync(workOrderFile, `${workOrder.trim()}\n`, 'utf8');
      state.status = 'uiux_plan_consensus';
      state.consensus = {
        round,
        executor: review.recommended_executor,
        author,
        reviewer,
        workOrderFile,
        summary: review.summary,
        executorReason: review.executor_reason
      };
      saveState(runDir, state);
      printRunSummary(state);
      return;
    }
    previous = { proposal, review };
    if (review.decision === 'block') break;
    author = reviewer;
  }
  state.status = 'needs_human_decision';
  saveState(runDir, state);
  printRunSummary(state);
}

function uiuxWaveRatificationPrompt(manifest, manifestSha) {
  return `
당신은 PetSpace UI/UX Wave 1A manifest의 독립 최종 비준자다.
아래 문서만 검토하며 구현하거나 저장소를 추가 탐색하지 않는다.
정확한 파일 범위, 보호 hash, 기능·문구 불변, 디자인 계약, 실행자와 검증·중단 조건을 평가하라.
사용자는 Claude와 Codex가 동일 manifest에 합의하고 blocker/high가 0일 때 이 단계의 진행을 이미 승인했다.
manifest 범위 안에서 해결 가능한 medium/low 개선은 reject 사유가 아니다.
blocker/high가 없고 Claude Fable 5 구현/Codex 교차 리뷰가 타당하면 accept한다.
manifest_sha256에는 아래 값을 그대로 반환하고 JSON 스키마로만 응답하라.

manifest_sha256: ${manifestSha}

manifest:
${manifest}
`;
}

function commandRatifyUiuxWave0() {
  const manifestFile = path.join(
    repoRoot,
    'docs',
    'work-orders',
    '2026-07-14-uiux-wave1-pilot.md'
  );
  if (!fs.existsSync(manifestFile)) fail(`UI/UX Wave 1A manifest를 찾지 못했습니다: ${manifestFile}`);
  const manifest = fs.readFileSync(manifestFile, 'utf8');
  const manifestSha = crypto.createHash('sha256').update(manifest, 'utf8').digest('hex');
  const id = createRunId('UIUX-wave1A-ratification');
  const runDir = path.join(runsRoot, id);
  ensureDir(runDir);
  const state = {
    version: 1,
    id,
    topic: 'UI/UX Wave 1A manifest 독립 비준',
    status: 'ratifying',
    baseBranch: defaultBaseBranch,
    baseCommit: git(['rev-parse', defaultBaseBranch]),
    createdAt: new Date().toISOString(),
    manifestFile,
    manifestSha256: manifestSha
  };
  saveState(runDir, state);
  fs.writeFileSync(path.join(runDir, 'wave1A-manifest.md'), manifest, 'utf8');
  const results = {};
  for (const agent of ['claude', 'codex']) {
    process.stdout.write(`${agent}가 UI/UX Wave 1A manifest를 독립 비준 중...\n`);
    results[agent] = invokeAgent(agent, {
      prompt: uiuxWaveRatificationPrompt(manifest, manifestSha),
      schema: uiuxWaveRatificationSchema,
      mode: 'read',
      runDir,
      label: `uiux-wave1A-ratification-${agent}`
    });
  }
  const accepted = ['claude', 'codex'].every((agent) =>
    results[agent].decision === 'accept'
      && results[agent].manifest_sha256 === manifestSha
      && results[agent].recommended_executor === 'claude'
      && results[agent].blocker_high.length === 0
  );
  state.ratification = {
    accepted,
    results,
    ratifiedAt: new Date().toISOString()
  };
  state.status = accepted ? 'uiux_wave0_approved' : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'uiux-wave1A-ratification.json'),
    `${safeJson(state.ratification)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.ratification)}\n`);
}

const uiuxWave1CManifestRelative = 'docs/work-orders/2026-07-14-uiux-wave1c-pet-flow-b.md';
const uiuxWave1CModified = [
  'pjh/lib/core/navigation/app_router.dart',
  'pjh/lib/features/pets/presentation/pages/pet_management_page.dart',
  'pjh/lib/features/pets/presentation/pages/pet_detail_page.dart'
];
const uiuxWave1CCreated = [
  'pjh/lib/features/pets/presentation/pages/pet_editor_page.dart',
  'pjh/test/features/pets/presentation/pages/pet_editor_page_test.dart'
];
const uiuxWave1CDeleted = [
  'pjh/lib/features/pets/presentation/widgets/add_pet_bottom_sheet.dart',
  'pjh/test/features/pets/presentation/widgets/add_pet_bottom_sheet_test.dart'
];
const uiuxWave1CReadOnlyHashes = {
  'pjh/lib/features/pets/presentation/widgets/pet_editor_form_widgets.dart': '219982f735924dda208042390bf3adaa4b70c8942653c26cf6e548cafc307b92',
  'pjh/lib/features/pets/presentation/bloc/pet_bloc.dart': 'b12d265fa47212a994f543ed03a45514066d038bc54c4333b4ec3a7c2fd9b324',
  'pjh/lib/features/pets/domain/entities/pet.dart': '4aa99ea8af5f67043ed31fb4cbfecd8c4b4b8523f39de2dfe01d9ce6e95f3312',
  'pjh/lib/shared/themes/app_theme.dart': '54b24735396329a729ba1f5ce7f214908caadd647fcf9f691ae1409e453a02f8',
  'pjh/lib/main_navigation.dart': 'bc048d39d03d312a4bfcb117f682dd7282804a699b8a368c383d5dfad1f334cf',
  'pjh/lib/features/social/presentation/pages/home_page.dart': '021681acf3f3c6898e2afebe7ba263dfb703bc9bc1728f450605dad369117269'
};
const uiuxWave1CStartHashes = {
  'pjh/lib/core/navigation/app_router.dart': 'adc034bfeca1c857953c9694afe876e952e2925dce0a121ba345ec1cae220d6d',
  'pjh/lib/features/pets/presentation/pages/pet_management_page.dart': '8711bc1ed385a2d423da66c10e1c7ef4c2788adb4a0f231d07aa0c0f3629cec0',
  'pjh/lib/features/pets/presentation/pages/pet_detail_page.dart': 'ac62d87eb140cd85a62a75060f65c7497001dc309fa4522f009d792ca8cffa4e',
  'pjh/lib/features/pets/presentation/widgets/add_pet_bottom_sheet.dart': '2f50bbaef2185ae6e89069ba438ff6dcff1a0d86c148e901ea5175ca4fee4a1b',
  'pjh/test/features/pets/presentation/widgets/add_pet_bottom_sheet_test.dart': '9117b0dd3a070169fc3eab2c33866eaae5b0c3550880983515f2ef407974300d'
};

function assertFileHashes(expected, label) {
  for (const [relative, hash] of Object.entries(expected)) {
    const absolute = path.join(repoRoot, relative);
    if (!fs.existsSync(absolute)) fail(`${label} 파일이 없습니다: ${relative}`);
    const actual = sha256File(absolute);
    if (actual !== hash) fail(`${label} hash 불일치: ${relative}\nexpected=${hash}\nactual=${actual}`);
  }
}

function repositoryFileSnapshot() {
  const skipped = new Set(['.git', '.agent-collab', '.dart_tool', 'build', 'node_modules']);
  const output = {};
  const stack = [repoRoot];
  while (stack.length) {
    const dir = stack.pop();
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (skipped.has(entry.name)) continue;
      const absolute = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        stack.push(absolute);
      } else if (entry.isFile()) {
        const relative = path.relative(repoRoot, absolute).replaceAll('\\', '/');
        output[relative] = sha256File(absolute);
      }
    }
  }
  return output;
}

function changedSnapshotPaths(before, after) {
  return [...new Set([...Object.keys(before), ...Object.keys(after)])]
    .filter((relative) => before[relative] !== after[relative])
    .sort();
}

function saveWave1CSources(runDir) {
  const snapshotDir = path.join(runDir, 'source-before');
  ensureDir(snapshotDir);
  const paths = [
    ...uiuxWave1CModified,
    ...uiuxWave1CDeleted,
    ...Object.keys(uiuxWave1CReadOnlyHashes),
    'pjh/lib/features/pets/presentation/bloc/pet_event.dart',
    'pjh/lib/features/pets/presentation/bloc/pet_state.dart',
    'pjh/lib/core/services/image_upload_service.dart',
    'pjh/lib/shared/widgets/image_source_picker.dart'
  ];
  const parts = [];
  for (const relative of paths) {
    const absolute = path.join(repoRoot, relative);
    if (!fs.existsSync(absolute)) continue;
    const content = fs.readFileSync(absolute, 'utf8');
    const target = path.join(snapshotDir, relative.replaceAll('/', '__'));
    fs.writeFileSync(target, content, 'utf8');
    parts.push(`\n===== CURRENT FILE: ${relative} =====\n${content}`);
  }
  return parts.join('\n');
}

function uiuxWave1CRatificationPrompt(manifest, mockup, combinedSha) {
  return `
당신은 PetSpace UI/UX Wave 1C 반려동물 전체 화면 등록·수정 B안의 독립 비준자다.
사용자는 B안 목업, CTA 브랜드 색, 구현 진행과 Claude Fable 5·Codex 협업을 승인했다.
아래 작업지시서와 목업만 read-only로 검토한다. 추가 도구 호출, 저장소 탐색, 파일 수정은 하지 않는다.
manifest_sha256에는 문서와 목업을 순서대로 결합한 아래 해시를 그대로 반환한다.

결합 SHA-256: ${combinedSha}

비준 기준:
- 정확한 7개 앱 경로 밖 변경, DB/API/Repository/BLoC 변경, 보호 화면 변경이 없는가
- 동일 PetBloc 전달, authBloc userId 전달, 저장 성공 뒤 pop이 기술적으로 일관적인가
- 등록 2단계·수정·여권 draft·미편집 필드 보존·구 시트 삭제 게이트가 빠짐없는가
- 색상·접근성·반응형·테스트·중단 조건이 사용자 승인 B안과 일치하는가
- 구현자는 사용자가 지정한 Claude Fable 5이므로 blocker/high가 없으면 recommended_executor=claude다

표현 개선이나 medium/low 제안은 거부 사유가 아니다. 실제 구현을 시작하면 안 되는 blocker/high만 blocker_high에 넣는다.
문서와 목업의 결합 해시를 확인하고 JSON 스키마로만 응답한다.

작업지시서:
${manifest}

승인 목업:
${mockup}
`;
}

function commandRatifyUiuxWave1C(args) {
  const manifestSource = path.join(repoRoot, uiuxWave1CManifestRelative);
  const mockupSource = args.mockup;
  if (!mockupSource || !path.isAbsolute(mockupSource) || !fs.existsSync(mockupSource)) {
    fail('ratify-uiux-wave1c에는 존재하는 절대 --mockup 경로가 필요합니다.');
  }
  assertFileHashes(uiuxWave1CStartHashes, 'Wave 1C 시작');
  assertFileHashes(uiuxWave1CReadOnlyHashes, 'Wave 1C 보호');
  for (const relative of uiuxWave1CCreated) {
    if (fs.existsSync(path.join(repoRoot, relative))) fail(`Wave 1C 신규 파일이 이미 존재합니다: ${relative}`);
  }

  let runDir;
  let state;
  if (args.run) {
    ({ runDir, state } = loadState(args.run));
    if (!['uiux_wave1C_ratification_waiting', 'uiux_wave1C_ratifying'].includes(state.status)) {
      fail(`재개할 수 없는 Wave 1C 상태입니다: ${state.status}`);
    }
  } else {
    const id = createRunId('UIUX-wave1C-pet-flow-B');
    runDir = path.join(runsRoot, id);
    ensureDir(runDir);
    const manifestFile = path.join(runDir, 'wave1C-manifest.md');
    const mockupFile = path.join(runDir, 'wave1C-mockup.html');
    fs.copyFileSync(manifestSource, manifestFile);
    fs.copyFileSync(mockupSource, mockupFile);
    const combined = `${fs.readFileSync(manifestFile, 'utf8')}\n---MOCKUP---\n${fs.readFileSync(mockupFile, 'utf8')}`;
    state = {
      version: 1,
      id,
      topic: 'UI/UX Wave 1C pet full-screen flow B',
      status: 'uiux_wave1C_ratifying',
      manifestFile,
      mockupFile,
      manifestSha256: crypto.createHash('sha256').update(combined, 'utf8').digest('hex'),
      approvedByUser: true,
      approvedAt: '2026-07-14',
      executor: 'claude',
      claudeModel,
      createdAt: new Date().toISOString(),
      ratification: { results: {} }
    };
    saveState(runDir, state);
  }

  const manifest = fs.readFileSync(state.manifestFile, 'utf8');
  const mockup = fs.readFileSync(state.mockupFile, 'utf8');
  const combined = `${manifest}\n---MOCKUP---\n${mockup}`;
  const currentSha = crypto.createHash('sha256').update(combined, 'utf8').digest('hex');
  if (currentSha !== state.manifestSha256) fail('Wave 1C 비준 문서 또는 목업이 run 생성 뒤 변경됐습니다.');
  const results = state.ratification?.results ?? {};
  state.status = 'uiux_wave1C_ratifying';
  saveState(runDir, state);
  for (const agent of ['claude', 'codex']) {
    if (results[agent]) continue;
    process.stdout.write(`${agent}가 UI/UX Wave 1C를 독립 비준 중...\n`);
    try {
      results[agent] = invokeAgent(agent, {
        prompt: uiuxWave1CRatificationPrompt(manifest, mockup, currentSha),
        schema: uiuxWaveRatificationSchema,
        mode: 'read',
        runDir,
        label: `uiux-wave1C-ratification-${agent}`,
        cwd: runDir
      });
      state.ratification = { results };
      saveState(runDir, state);
    } catch (error) {
      state.status = 'uiux_wave1C_ratification_waiting';
      state.ratification = { results, waitingOn: agent, lastError: error.message };
      saveState(runDir, state);
      throw error;
    }
  }
  const approved = ['claude', 'codex'].every((agent) =>
    results[agent].decision === 'accept'
    && results[agent].manifest_sha256 === currentSha
    && results[agent].recommended_executor === 'claude'
    && results[agent].blocker_high.length === 0
  );
  state.ratification = { approved, results, ratifiedAt: new Date().toISOString() };
  state.status = approved ? 'uiux_wave1C_ratified' : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(path.join(runDir, 'uiux-wave1C-ratification.json'), `${safeJson(state.ratification)}\n`, 'utf8');
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.ratification)}\n`);
}

function uiuxWave1CExecutionPrompt(manifest, mockup, sources) {
  return `
당신은 사용자와 Claude Fable 5·Codex가 비준한 PetSpace UI/UX Wave 1C B안의 구현자다.
모델은 claude-fable-5다. 루트 규칙과 아래 작업지시서를 정확히 따른다.

이번 Claude 세션에서 허용된 변경은 다음 5개뿐이다.
- 수정: ${uiuxWave1CModified.join(', ')}
- 생성: ${uiuxWave1CCreated.join(', ')}

기존 bottom sheet 소스와 테스트 2개는 오케스트레이터가 검증 게이트 뒤 삭제하므로 이 세션에서 수정·삭제하지 않는다.
그 밖의 파일은 읽거나 수정하지 않는다. 필요한 현재 소스는 이 프롬프트 아래에 모두 제공한다.
비밀키·환경파일·보호 화면·운영 데이터는 읽거나 출력하지 않는다.

핵심 구현 조건:
- 승인 목업의 등록 1/2단계, 수정 단일 화면, 수정 전용 여권 draft 관리 화면을 구현한다.
- AppRouter Shell 밖 fullscreen named routes + typed route data + 동일 PetBloc BlocProvider.value를 사용한다.
- authBloc의 userId를 route builder에서 전달하고 새 Presentation에서 Supabase를 import하지 않는다.
- 성공 상태 전 pop 금지, 오류 시 입력/단계 유지, 중복 dispatch와 이중 pop 금지다.
- 수정 시 currentMbtiType/currentMbtiUpdatedAt/passportNo와 모든 미편집 필드를 보존한다.
- CTA는 AppTheme.actionBase, pressed는 actionPressed, heading은 light brandDeep/dark onSurface다. 검은 CTA를 만들지 않는다.
- raw 예외 원문을 사용자에게 노출하지 않는다.
- 기존 picker/upload 파라미터와 Pet 매핑 의미를 보존한다.
- 신규 테스트는 mock PetBloc으로 네트워크·Supabase·picker를 호출하지 않는다.
- 다섯 파일을 dart format하고 flutter analyze --no-pub 및 대상 widget test를 실행한다.
- commit·merge·push·deploy·DB·패키지 작업을 하지 않는다.

범위 안에서 안전하게 완료할 수 없으면 파일을 억지로 바꾸지 말고 status=blocked로 응답한다.
완료 응답의 changed_files는 실제 5개만 적고 JSON 스키마로만 응답한다.

비준 작업지시서:
${manifest}

승인 목업:
${mockup}

오케스트레이터가 제공한 현재 소스:
${sources}
`;
}

function referencesLegacyPetSheetOutsideLegacyFiles() {
  const roots = [path.join(repoRoot, 'pjh', 'lib'), path.join(repoRoot, 'pjh', 'test')];
  const excluded = new Set(uiuxWave1CDeleted.map((relative) => path.resolve(repoRoot, relative).toLowerCase()));
  const hits = [];
  const stack = [...roots];
  while (stack.length) {
    const current = stack.pop();
    if (!fs.existsSync(current)) continue;
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) stack.push(absolute);
      else if (entry.isFile() && entry.name.endsWith('.dart') && !excluded.has(path.resolve(absolute).toLowerCase())) {
        const content = fs.readFileSync(absolute, 'utf8');
        if (content.includes('AddPetBottomSheet') || content.includes('add_pet_bottom_sheet')) {
          hits.push(path.relative(repoRoot, absolute).replaceAll('\\', '/'));
        }
      }
    }
  }
  return hits.sort();
}

function commandExecuteUiuxWave1C(runId) {
  const { runDir, state } = loadState(runId);
  if (state.status !== 'uiux_wave1C_ratified') fail(`구현할 수 없는 Wave 1C 상태입니다: ${state.status}`);
  if (state.claudeModel !== 'claude-fable-5' || claudeModel !== 'claude-fable-5') {
    fail(`Wave 1C 구현은 CLAUDE_MODEL=claude-fable-5가 필요합니다. state=${state.claudeModel}, current=${claudeModel}`);
  }
  assertFileHashes(uiuxWave1CStartHashes, 'Wave 1C 실행 시작');
  assertFileHashes(uiuxWave1CReadOnlyHashes, 'Wave 1C 보호');
  for (const relative of uiuxWave1CCreated) {
    if (fs.existsSync(path.join(repoRoot, relative))) fail(`Wave 1C 신규 파일이 이미 존재합니다: ${relative}`);
  }
  const manifest = fs.readFileSync(state.manifestFile, 'utf8');
  const mockup = fs.readFileSync(state.mockupFile, 'utf8');
  const sources = saveWave1CSources(runDir);
  const before = repositoryFileSnapshot();
  state.status = 'uiux_wave1C_implementing';
  saveState(runDir, state);
  let result;
  try {
    result = invokeAgent('claude', {
      prompt: uiuxWave1CExecutionPrompt(manifest, mockup, sources),
      schema: executionSchema,
      mode: 'write-limited',
      runDir,
      label: 'uiux-wave1C-execution-claude-fable-5',
      cwd: repoRoot
    });
  } catch (error) {
    state.status = 'uiux_wave1C_execution_waiting';
    state.execution = { waitingOn: 'claude', lastError: error.message };
    saveState(runDir, state);
    throw error;
  }
  const afterClaude = repositoryFileSnapshot();
  const claudeDelta = changedSnapshotPaths(before, afterClaude);
  const allowedClaude = new Set([...uiuxWave1CModified, ...uiuxWave1CCreated]);
  const unexpectedClaude = claudeDelta.filter((relative) => !allowedClaude.has(relative));
  const missing = uiuxWave1CCreated.filter((relative) => !fs.existsSync(path.join(repoRoot, relative)));
  if (result.status !== 'complete' || unexpectedClaude.length || missing.length) {
    state.status = 'needs_human_decision';
    state.execution = { result, claudeDelta, unexpectedClaude, missing };
    saveState(runDir, state);
    printRunSummary(state);
    return;
  }
  assertFileHashes(uiuxWave1CReadOnlyHashes, 'Wave 1C Claude 실행 후 보호');
  const pjhRoot = path.join(repoRoot, 'pjh');
  const preDeleteAnalyze = run('flutter', ['analyze', '--no-pub'], { cwd: pjhRoot }).stdout.trim();
  const preDeleteTest = run('flutter', ['test', 'test/features/pets/presentation/pages/pet_editor_page_test.dart'], { cwd: pjhRoot }).stdout.trim();
  const legacyReferences = referencesLegacyPetSheetOutsideLegacyFiles();
  if (legacyReferences.length) {
    state.status = 'needs_human_decision';
    state.execution = { result, claudeDelta, legacyReferences, preDeleteAnalyze, preDeleteTest };
    saveState(runDir, state);
    fail(`구 시트 참조가 남아 삭제 게이트를 통과하지 못했습니다: ${legacyReferences.join(', ')}`);
  }
  for (const relative of uiuxWave1CDeleted) fs.unlinkSync(path.join(repoRoot, relative));
  const postDeleteAnalyze = run('flutter', ['analyze', '--no-pub'], { cwd: pjhRoot }).stdout.trim();
  const postDeleteTest = run('flutter', ['test', 'test/features/pets/presentation/pages/pet_editor_page_test.dart'], { cwd: pjhRoot }).stdout.trim();
  const diffCheck = git(['diff', '--check']);
  const after = repositoryFileSnapshot();
  const allDelta = changedSnapshotPaths(before, after);
  const expectedDelta = new Set([...uiuxWave1CModified, ...uiuxWave1CCreated, ...uiuxWave1CDeleted]);
  const unexpectedPaths = allDelta.filter((relative) => !expectedDelta.has(relative));
  const absentDeleted = uiuxWave1CDeleted.filter((relative) => fs.existsSync(path.join(repoRoot, relative)));
  assertFileHashes(uiuxWave1CReadOnlyHashes, 'Wave 1C 완료 후 보호');
  state.execution = {
    result,
    claudeDelta,
    allDelta,
    unexpectedPaths,
    absentDeleted,
    preDeleteAnalyze: preDeleteAnalyze.split(/\r?\n/).at(-1),
    preDeleteTest: preDeleteTest.split(/\r?\n/).at(-1),
    postDeleteAnalyze: postDeleteAnalyze.split(/\r?\n/).at(-1),
    postDeleteTest: postDeleteTest.split(/\r?\n/).at(-1),
    diffCheck,
    completedAt: new Date().toISOString()
  };
  state.status = unexpectedPaths.length === 0 && absentDeleted.length === 0
    ? 'uiux_wave1C_implemented'
    : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(path.join(runDir, 'uiux-wave1C-execution.json'), `${safeJson(state.execution)}\n`, 'utf8');
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.execution)}\n`);
}

function wave1CReviewBundle(runDir) {
  const parts = [];
  const beforeDir = path.join(runDir, 'source-before');
  for (const relative of [...uiuxWave1CModified, ...uiuxWave1CDeleted]) {
    const beforeFile = path.join(beforeDir, relative.replaceAll('/', '__'));
    if (fs.existsSync(beforeFile)) parts.push(`\n===== BEFORE: ${relative} =====\n${fs.readFileSync(beforeFile, 'utf8')}`);
  }
  for (const relative of [...uiuxWave1CModified, ...uiuxWave1CCreated]) {
    const absolute = path.join(repoRoot, relative);
    if (fs.existsSync(absolute)) parts.push(`\n===== AFTER: ${relative} =====\n${fs.readFileSync(absolute, 'utf8')}`);
  }
  const readOnlyEvidence = [
    'pjh/lib/features/pets/presentation/bloc/pet_bloc.dart',
    'pjh/lib/features/pets/presentation/bloc/pet_event.dart',
    'pjh/lib/features/pets/presentation/bloc/pet_state.dart',
    'pjh/lib/features/pets/domain/entities/pet.dart'
  ];
  for (const relative of readOnlyEvidence) {
    const beforeFile = path.join(beforeDir, relative.replaceAll('/', '__'));
    if (fs.existsSync(beforeFile)) {
      parts.push(`\n===== READ-ONLY EVIDENCE: ${relative} =====\n${fs.readFileSync(beforeFile, 'utf8')}`);
    }
  }
  parts.push(`\n===== DELETED =====\n${uiuxWave1CDeleted.join('\n')}`);
  return parts.join('\n');
}

function uiuxWave1CReviewPrompt(manifest, mockup, execution, bundle) {
  return `
당신은 PetSpace UI/UX Wave 1C B안 구현의 독립 read-only 리뷰어다.
비준 뒤 Claude Fable 5가 사용량 한도에서 코드 작성 전에 중단되었고, 사용자가 동일 manifest를 Codex가 구현하고 Claude Opus 4.8이 리뷰하도록 명시적으로 변경 승인했다. 실행자 변경 자체는 결함이 아니다.
아래 비준 작업지시서, 승인 목업, 실행 보고와 정확한 before/after 소스만 검토한다.
추가 도구 호출, 저장소 탐색, 파일 수정은 하지 않는다. JSON 스키마로만 응답한다.

우선 blocker/high와 제품 신뢰도를 해치는 medium을 확인한다.
- 제공된 read-only PetBloc 전문에서 add/update 성공 시 PetOperationSuccess 다음 PetLoaded를 연속 emit하는 실제 최종 상태를 확인하고, 관리 화면의 transient 렌더 분기만으로 상태가 머문다고 추정하지 않는다.
- 전체 화면 route와 동일 PetBloc 전달, auth userId, 비정상 extra 안전성
- 등록 2단계·수정·여권 draft, 성공 전 pop 금지, 오류/중복 제출
- Pet nullable/MBTI/passportNo 등 데이터 보존, picker/upload 파라미터
- 기존 4개 진입점 교체와 구 시트 참조 제거
- CTA 실제 actionBase, 다크 대비, 44px, keyboard/작은 화면/150% text
- 테스트가 실제 회귀를 검출하는지

blocker/high가 없고 필수 동작·디자인·테스트가 작업지시서와 맞으면 approve한다.
취향 차이와 실기기 검증 대기는 verification_gaps로 두고 거부 사유로 만들지 않는다.

작업지시서:
${manifest}

목업:
${mockup}

실행 보고:
${safeJson(execution)}

정확한 소스:
${bundle}
`;
}

function commandReviewUiuxWave1C(runId) {
  const { runDir, state } = loadState(runId);
  if (!['uiux_wave1C_implemented', 'uiux_wave1C_review_waiting', 'uiux_wave1C_reviewing'].includes(state.status)) {
    fail(`리뷰할 수 없는 Wave 1C 상태입니다: ${state.status}`);
  }
  const manifest = fs.readFileSync(state.manifestFile, 'utf8');
  const mockup = fs.readFileSync(state.mockupFile, 'utf8');
  const bundle = wave1CReviewBundle(runDir);
  const results = state.postReview?.results ?? {};
  state.status = 'uiux_wave1C_reviewing';
  saveState(runDir, state);
  for (const agent of ['codex', 'claude']) {
    if (results[agent]) continue;
    process.stdout.write(`${agent}가 UI/UX Wave 1C 구현을 독립 리뷰 중...\n`);
    try {
      results[agent] = invokeAgent(agent, {
        prompt: uiuxWave1CReviewPrompt(manifest, mockup, state.execution, bundle),
        schema: implementationReviewSchema,
        mode: 'read',
        runDir,
        label: `uiux-wave1C-post-review-${agent}`,
        cwd: runDir
      });
      state.postReview = { approved: false, results };
      saveState(runDir, state);
    } catch (error) {
      state.status = 'uiux_wave1C_review_waiting';
      state.postReview = { approved: false, results, waitingOn: agent, lastError: error.message };
      saveState(runDir, state);
      throw error;
    }
  }
  const severe = (review) => review.findings.some((finding) =>
    finding.severity === 'blocker' || finding.severity === 'high'
  );
  const approved = ['claude', 'codex'].every((agent) =>
    results[agent].verdict === 'approve' && !severe(results[agent])
  );
  state.postReview = { approved, results, reviewedAt: new Date().toISOString() };
  state.status = approved ? 'uiux_wave1C_review_approved' : 'uiux_wave1C_changes_required';
  saveState(runDir, state);
  fs.writeFileSync(path.join(runDir, 'uiux-wave1C-post-review.json'), `${safeJson(state.postReview)}\n`, 'utf8');
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.postReview)}\n`);
}

function commandRereviewUiuxWave1C(runId) {
  const { runDir, state } = loadState(runId);
  if (!['uiux_wave1C_changes_required', 'uiux_wave1C_review_waiting'].includes(state.status)
      || !state.postReview) {
    fail(`재리뷰할 수 없는 Wave 1C 상태입니다: ${state.status}`);
  }
  state.reviewHistory = [...(state.reviewHistory ?? []), state.postReview];
  delete state.postReview;
  state.status = 'uiux_wave1C_implemented';
  saveState(runDir, state);
  commandReviewUiuxWave1C(runId);
}

function uiuxWave1BRatificationPrompt(manifest, mockup, combinedSha) {
  return `
당신은 PetSpace UI/UX Wave 1B 반려동물 추가·수정 시트의 독립 최종 비준자다.
아래 작업지시서와 가시적 목업 HTML을 함께 검토한다. 구현하거나 추가 도구를 호출하지 않는다.
정확한 파일 범위, 소비자·보호 hash, 기능·문구·데이터 불변, 키보드·다크모드·접근성, 테스트,
목업과 지시서의 정합성, Claude Fable 5 구현/Codex 교차 리뷰 구성을 평가하라.
사용자는 목업과 정확한 3개 파일 구현 범위를 승인했고, 이 작업지시서·목업·해당 파일 범위를
Claude Fable 5가 외부 열람·검토·구현하는 것도 명시적으로 승인했다. 비밀키·환경파일·보호 화면은 제외한다.
blocker/high가 없으면 accept한다. 범위 안에서 해결 가능한 medium/low 개선은 reject 사유가 아니다.
recommended_executor는 구현 후보가 타당하면 claude로 반환한다.
manifest_sha256에는 아래 combined_sha256 값을 그대로 반환하고 JSON 스키마로만 응답하라.

combined_sha256: ${combinedSha}

작업지시서:
${manifest}

목업 HTML:
${mockup}
`;
}

function commandRatifyUiuxWave1B(args) {
  const defaultManifestFile = path.join(
    repoRoot, 'docs', 'work-orders', '2026-07-14-uiux-wave1b-pet-editor.md'
  );
  let runDir;
  let state;
  let manifestFile;
  let mockupFile;
  if (args.run) {
    ({ runDir, state } = loadState(args.run));
    if (!['ratifying', 'uiux_wave1B_ratification_waiting'].includes(state.status)) {
      fail(`재개할 수 없는 UI/UX Wave 1B 비준 상태입니다: ${state.status}`);
    }
    manifestFile = state.manifestFile;
    mockupFile = state.mockupFile;
  } else {
    manifestFile = defaultManifestFile;
    mockupFile = args.mockup;
  }
  if (!fs.existsSync(manifestFile)) fail(`UI/UX Wave 1B manifest를 찾지 못했습니다: ${manifestFile}`);
  if (!mockupFile || !fs.existsSync(mockupFile)) fail('--mockup으로 목업 HTML 경로를 지정하세요.');
  const manifest = fs.readFileSync(manifestFile, 'utf8');
  const mockup = fs.readFileSync(mockupFile, 'utf8');
  const combined = `${manifest}\n---MOCKUP---\n${mockup}`;
  const combinedSha = crypto.createHash('sha256').update(combined, 'utf8').digest('hex');
  if (args.run) {
    if (combinedSha !== state.manifestSha256) {
      fail('대기 중 Wave 1B 작업지시서 또는 목업이 변경됐습니다. 새 비준 run이 필요합니다.');
    }
    state.userApproval ??= {
      approvedAt: '2026-07-14',
      scope: '목업, 작업지시서, 정확한 3개 파일의 Claude Fable 5 외부 검토·열람·구현'
    };
    state.status = 'ratifying';
  } else {
    const id = createRunId('UIUX-wave1B-pet-editor-ratification');
    runDir = path.join(runsRoot, id);
    ensureDir(runDir);
    state = {
      version: 1,
      id,
      topic: 'UI/UX Wave 1B 반려동물 편집 시트 manifest·목업 비준',
      status: 'ratifying',
      baseBranch: defaultBaseBranch,
      baseCommit: git(['rev-parse', defaultBaseBranch]),
      createdAt: new Date().toISOString(),
      manifestFile,
      mockupFile,
      manifestSha256: combinedSha,
      userApproval: {
        approvedAt: '2026-07-14',
        scope: '목업, 작업지시서, 정확한 3개 파일의 Claude Fable 5 외부 검토·열람·구현'
      }
    };
    fs.writeFileSync(path.join(runDir, 'wave1B-manifest.md'), manifest, 'utf8');
    fs.writeFileSync(path.join(runDir, 'wave1B-mockup.html'), mockup, 'utf8');
  }
  saveState(runDir, state);
  const results = state.ratification?.results ?? {};
  for (const agent of ['claude', 'codex']) {
    if (results[agent]) {
      process.stdout.write(`${agent} Wave 1B 비준 결과가 이미 있어 중복 호출을 건너뜁니다.\n`);
      continue;
    }
    process.stdout.write(`${agent}가 UI/UX Wave 1B manifest와 목업을 독립 비준 중...\n`);
    try {
      results[agent] = invokeAgent(agent, {
        prompt: uiuxWave1BRatificationPrompt(manifest, mockup, combinedSha),
        schema: uiuxWaveRatificationSchema,
        mode: 'read',
        runDir,
        label: `uiux-wave1B-ratification-${agent}`
      });
      state.ratification = { accepted: false, results };
      saveState(runDir, state);
    } catch (error) {
      state.status = 'uiux_wave1B_ratification_waiting';
      state.ratification = {
        accepted: false,
        results,
        waitingOn: agent,
        lastError: error.message,
        failedAt: new Date().toISOString()
      };
      saveState(runDir, state);
      throw error;
    }
  }
  const accepted = ['claude', 'codex'].every((agent) =>
    results[agent].decision === 'accept'
      && results[agent].manifest_sha256 === combinedSha
      && results[agent].recommended_executor === 'claude'
      && results[agent].blocker_high.length === 0
  );
  state.ratification = { accepted, results, ratifiedAt: new Date().toISOString() };
  state.status = accepted ? 'uiux_wave1B_approved_for_implementation' : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'uiux-wave1B-ratification.json'),
    `${safeJson(state.ratification)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.ratification)}\n`);
}

function uiuxWave1BExecutionPrompt(manifest, mockup, currentSource) {
  return `
루트 규칙과 아래 양쪽 비준 완료 작업지시서·사용자 승인 목업을 준수해 UI/UX Wave 1B를 구현하라.
사용자는 이 작업지시서·목업·정확한 3개 파일 범위를 Claude Fable 5가 외부 열람·검토·구현하는 것을 명시적으로 승인했다.
Claude 모델은 claude-fable-5다. 비밀키·환경파일·보호 화면을 읽거나 출력하지 않는다.

정확한 허용 범위:
1. 수정: pjh/lib/features/pets/presentation/widgets/add_pet_bottom_sheet.dart
2. 생성: pjh/lib/features/pets/presentation/widgets/pet_editor_form_widgets.dart
3. 생성: pjh/test/features/pets/presentation/widgets/add_pet_bottom_sheet_test.dart

위 3개 밖의 파일을 읽거나 수정하지 않는다. 현재 소스는 아래에 제공했으므로 별도 저장소 탐색을 하지 않는다.
기능 의미, Pet 필드 매핑, 검증, 업로드, Supabase 호출, callback, 상태, 문구와 호출 순서를 모두 보존한다.
한 개 bottom sheet 구조를 유지하고, 기본 정보와 접을 수 있는 선택 여권 정보, 하단 고정 취소·저장 액션을 구현한다.
추가 모드는 여권 정보를 기본 접힘, 기존 여권 데이터가 있는 수정 모드는 기본 펼침으로 한다.
다크모드, 키보드, 44px 터치, 320x568, 150% text scale을 고려한다.
raw $e 오류 문구는 이번 범위에서 바꾸지 않는다. 유효한 Supabase 제출을 호출하지 않는 widget test를 작성한다.
신규 패키지·자산·route·DB/API 변경, commit·merge·push·deploy를 하지 않는다.
허용된 세 파일의 dart format, flutter analyze --no-pub, 대상 widget test만 실행할 수 있다.
범위 안에서 해결할 수 없으면 확장하지 말고 blocked로 응답한다. 최종 응답은 JSON 스키마만 따른다.

작업지시서:
${manifest}

승인 목업 HTML:
${mockup}

승인된 기존 add_pet_bottom_sheet.dart 소스:
\`\`\`dart
${currentSource}
\`\`\`
`;
}

function commandExecuteUiuxWave1B(runId) {
  const { runDir, state } = loadState(runId);
  if (state.status !== 'uiux_wave1B_approved_for_implementation' || !state.ratification?.accepted) {
    fail(`양쪽 비준과 사용자 승인이 완료된 UI/UX Wave 1B run이 아닙니다: ${state.status}`);
  }
  const manifest = fs.readFileSync(state.manifestFile, 'utf8');
  const mockup = fs.readFileSync(state.mockupFile, 'utf8');
  const combined = `${manifest}\n---MOCKUP---\n${mockup}`;
  const currentCombinedSha = crypto.createHash('sha256').update(combined, 'utf8').digest('hex');
  if (currentCombinedSha !== state.manifestSha256) {
    fail('비준 뒤 Wave 1B 작업지시서 또는 목업이 변경됐습니다. 다시 비준하세요.');
  }

  const sourceRelative = 'pjh/lib/features/pets/presentation/widgets/add_pet_bottom_sheet.dart';
  const helperRelative = 'pjh/lib/features/pets/presentation/widgets/pet_editor_form_widgets.dart';
  const testRelative = 'pjh/test/features/pets/presentation/widgets/add_pet_bottom_sheet_test.dart';
  const allowed = new Set([sourceRelative, helperRelative, testRelative]);
  const expectedProtected = {
    [sourceRelative]: '27045cbc8a07fed12016ba4fb1cdc3744813ea2e5e277eb518b78fc254842692',
    'pjh/lib/features/pets/presentation/pages/pet_management_page.dart': '8711bc1ed385a2d423da66c10e1c7ef4c2788adb4a0f231d07aa0c0f3629cec0',
    'pjh/lib/features/pets/presentation/pages/pet_detail_page.dart': 'ac62d87eb140cd85a62a75060f65c7497001dc309fa4522f009d792ca8cffa4e',
    'pjh/lib/shared/widgets/petspace_page_scaffold.dart': '4be04bb4410495a56a345fdf6a3e1b73d1cda41257d3fe323230b65bea9aa69d',
    'pjh/lib/shared/widgets/petspace_settings_components.dart': '22d531a13da6c51fca90d5faaa93c40ffee3f684d5cd1f6efd515580bc431f66',
    'pjh/lib/shared/widgets/petspace_state_view.dart': 'edb26f99ec8ed2f8fe136c3d912a363c0583e5480cf1817ea53371b8e1806ca7'
  };
  for (const [relative, expectedSha] of Object.entries(expectedProtected)) {
    const absolute = path.join(repoRoot, relative);
    if (!fs.existsSync(absolute)) fail(`구현 직전 필수 파일이 없습니다: ${relative}`);
    const actualSha = crypto.createHash('sha256').update(fs.readFileSync(absolute)).digest('hex');
    if (actualSha !== expectedSha) fail(`구현 직전 hash 불일치: ${relative}`);
  }
  for (const relative of [helperRelative, testRelative]) {
    if (fs.existsSync(path.join(repoRoot, relative))) fail(`Wave 1B 신규 파일이 이미 존재합니다: ${relative}`);
  }

  const currentSource = fs.readFileSync(path.join(repoRoot, sourceRelative), 'utf8');
  const before = visibleRepoHashes();
  ensureDir(path.dirname(path.join(repoRoot, testRelative)));
  state.status = 'uiux_wave1B_executing';
  state.execution = {
    executor: 'claude-fable-5',
    startedAt: new Date().toISOString(),
    allowedPaths: [...allowed]
  };
  saveState(runDir, state);
  const result = invokeAgent('claude', {
    prompt: uiuxWave1BExecutionPrompt(manifest, mockup, currentSource),
    schema: executionSchema,
    mode: 'write-limited',
    runDir,
    label: 'uiux-wave1B-execution-claude-fable-5'
  });
  const after = visibleRepoHashes();
  const changedPaths = changedHashPaths(before, after);
  const unexpectedPaths = changedPaths.filter((file) => !allowed.has(file));
  const missingPaths = [...allowed].filter((file) => !fs.existsSync(path.join(repoRoot, file)));
  const sourceAfterSha = fs.existsSync(path.join(repoRoot, sourceRelative))
    ? crypto.createHash('sha256').update(fs.readFileSync(path.join(repoRoot, sourceRelative))).digest('hex')
    : null;
  const sourceUnchanged = sourceAfterSha === expectedProtected[sourceRelative];
  state.execution = {
    ...state.execution,
    completedAt: new Date().toISOString(),
    result,
    changedPaths,
    unexpectedPaths,
    missingPaths,
    sourceAfterSha
  };
  state.status = result.status === 'complete'
      && unexpectedPaths.length === 0
      && missingPaths.length === 0
      && !sourceUnchanged
    ? 'uiux_wave1B_implemented'
    : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'uiux-wave1B-execution.json'),
    `${safeJson(state.execution)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.execution)}\n`);
}

function uiuxWave1BPostReviewPrompt(manifest, mockup, execution, diffBundle) {
  return `
당신은 PetSpace UI/UX Wave 1B 구현의 독립 read-only 리뷰어다.
사용자는 작업지시서·목업·정확한 3개 파일 범위의 Claude Fable 5 외부 검토·열람·구현을 승인했다.
아래 비준 작업지시서, 승인 목업, 실행 보고와 정확한 3개 파일 diff만 검토한다. 추가 도구 호출이나 저장소 탐색, 파일 수정은 하지 않는다.
비밀키·환경파일·보호 화면은 범위 밖이다.

기능 의미, Pet 필드 매핑, 검증, 업로드·Supabase 호출, callback, 상태, 문구와 호출 순서 보존을 먼저 확인한다.
이어서 add/edit 초기 상태, 여권 접힘 규칙, sticky action, 다크모드, 키보드, 44px, 320x568, 150% text scale,
dispose 안정성, widget test의 실제 회귀 방지력을 검토한다. raw $e 문구는 이번 범위에서 바꾸지 않는다.
blocker/high가 없고 작업지시서에 맞으면 approve한다. 제품 신뢰도나 회귀 방지에 필요한 medium은 changes_required로 표시할 수 있다.
JSON 스키마로만 응답한다.

작업지시서:
${manifest}

승인 목업 HTML:
${mockup}

실행 보고:
${safeJson(execution)}

정확한 3개 파일 diff:
${diffBundle}
`;
}

function commandReviewUiuxWave1B(runId) {
  const { runDir, state } = loadState(runId);
  if (!['uiux_wave1B_implemented', 'uiux_wave1B_review_waiting'].includes(state.status)) {
    fail(`리뷰할 수 없는 UI/UX Wave 1B 상태입니다: ${state.status}`);
  }
  const manifest = fs.readFileSync(state.manifestFile, 'utf8');
  const mockup = fs.readFileSync(state.mockupFile, 'utf8');
  const combined = `${manifest}\n---MOCKUP---\n${mockup}`;
  const currentCombinedSha = crypto.createHash('sha256').update(combined, 'utf8').digest('hex');
  if (currentCombinedSha !== state.manifestSha256) fail('비준 뒤 Wave 1B 문서가 변경됐습니다.');

  const modified = 'pjh/lib/features/pets/presentation/widgets/add_pet_bottom_sheet.dart';
  const created = [
    'pjh/lib/features/pets/presentation/widgets/pet_editor_form_widgets.dart',
    'pjh/test/features/pets/presentation/widgets/add_pet_bottom_sheet_test.dart'
  ];
  let diffBundle = git(['diff', '--', modified]);
  for (const relative of created) {
    const absolute = path.join(repoRoot, relative);
    if (!fs.existsSync(absolute)) fail(`리뷰 대상 파일이 없습니다: ${relative}`);
    diffBundle += `\n\n===== NEW FILE: ${relative} =====\n`;
    diffBundle += fs.readFileSync(absolute, 'utf8');
  }

  const results = state.postReview?.results ?? {};
  state.status = 'uiux_wave1B_reviewing';
  saveState(runDir, state);
  for (const agent of ['claude', 'codex']) {
    if (results[agent]) {
      process.stdout.write(`${agent} Wave 1B 구현 리뷰 결과가 이미 있어 중복 호출을 건너뜁니다.\n`);
      continue;
    }
    process.stdout.write(`${agent}가 UI/UX Wave 1B 구현을 독립 리뷰 중...\n`);
    try {
      results[agent] = invokeAgent(agent, {
        prompt: uiuxWave1BPostReviewPrompt(manifest, mockup, state.execution, diffBundle),
        schema: implementationReviewSchema,
        mode: 'read',
        runDir,
        label: `uiux-wave1B-post-review-${agent}`,
        cwd: runDir
      });
      state.postReview = { approved: false, results };
      saveState(runDir, state);
    } catch (error) {
      state.status = 'uiux_wave1B_review_waiting';
      state.postReview = {
        approved: false,
        results,
        waitingOn: agent,
        lastError: error.message,
        failedAt: new Date().toISOString()
      };
      saveState(runDir, state);
      throw error;
    }
  }
  const severe = (review) => review.findings.some((finding) =>
    finding.severity === 'blocker' || finding.severity === 'high'
  );
  const approved = ['claude', 'codex'].every((agent) =>
    results[agent].verdict === 'approve' && !severe(results[agent])
  );
  state.postReview = { approved, results, reviewedAt: new Date().toISOString() };
  state.status = approved ? 'uiux_wave1B_review_approved' : 'uiux_wave1B_changes_required';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'uiux-wave1B-post-review.json'),
    `${safeJson(state.postReview)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.postReview)}\n`);
}

function uiuxWave1BFixPrompt(manifest, reviews, currentSource, currentTest) {
  return `
루트 규칙과 비준된 Wave 1B 작업지시서를 준수해 독립 리뷰의 필수 medium 1건만 최소 보완하라.
사용자는 이 작업지시서·목업·정확한 3개 파일 범위의 Claude Fable 5 외부 열람·검토·구현을 승인했다.
Claude 모델은 claude-fable-5다. 비밀키·환경파일·보호 화면을 읽거나 출력하지 않는다.

정확한 수정 허용 파일은 아래 2개뿐이다.
1. pjh/lib/features/pets/presentation/widgets/add_pet_bottom_sheet.dart
2. pjh/test/features/pets/presentation/widgets/add_pet_bottom_sheet_test.dart

pet_editor_form_widgets.dart와 그 밖의 파일은 읽거나 수정하지 않는다. 필요한 현재 소스는 아래에 제공한다.
필수 수정:
- _buildTypeSelector의 onSelected에서 value가 현재 _selectedType과 같으면 즉시 return한다.
- 종류가 실제 변경될 때만 기존처럼 품종 선택·직접 입력을 초기화한다.
- 수정 모드의 프리필 품종이 같은 종류 재탭 뒤에도 유지되는 회귀 테스트를 추가한다.
- 여권 데이터가 없는 수정 모드(countryCode KOR, 여권 필드 null/empty)는 기본 접힘이라는 테스트도 추가한다.

확정된 로컬 Flutter 3.41.6 근거: radio_list_tile.dart _handleListTileTap은 !toggleable && checked일 때 return한다.
따라서 동일 값 재탭 가드는 기능 보존 수정이다.

유지 사항:
- '기본 정보' heading은 사용자 승인 목업·시각 구조의 명시 항목이므로 유지한다.
- 라이트 Colors.white는 AppTheme.surfaceColor=Colors.white와 일치하므로 유지한다.
- _hasExistingPassportData 로직, 저장·업로드·Supabase·Pet 매핑·callback·문구·raw $e는 변경하지 않는다.
- 유효한 폼 제출이나 네트워크 호출을 테스트하지 않는다.
- 두 파일만 dart format하고 flutter analyze --no-pub 및 대상 widget test를 실행한다.
- commit·merge·push·deploy·DB 작업을 하지 않는다.
범위 안에서 해결할 수 없으면 blocked로 응답한다. 최종 응답은 JSON 스키마만 따른다.

작업지시서:
${manifest}

이전 독립 리뷰:
${safeJson(reviews)}

현재 add_pet_bottom_sheet.dart:
\`\`\`dart
${currentSource}
\`\`\`

현재 add_pet_bottom_sheet_test.dart:
\`\`\`dart
${currentTest}
\`\`\`
`;
}

function commandFixUiuxWave1B(runId) {
  const { runDir, state } = loadState(runId);
  if (state.status !== 'uiux_wave1B_changes_required' || !state.postReview) {
    fail(`보완할 수 없는 UI/UX Wave 1B 상태입니다: ${state.status}`);
  }
  const sourceRelative = 'pjh/lib/features/pets/presentation/widgets/add_pet_bottom_sheet.dart';
  const helperRelative = 'pjh/lib/features/pets/presentation/widgets/pet_editor_form_widgets.dart';
  const testRelative = 'pjh/test/features/pets/presentation/widgets/add_pet_bottom_sheet_test.dart';
  const expected = {
    [sourceRelative]: '905bbd7151afca9401e32e0d6508199fed415b1e1fa6103472a4d864909d8380',
    [helperRelative]: '219982f735924dda208042390bf3adaa4b70c8942653c26cf6e548cafc307b92',
    [testRelative]: '7bcfd9d3c1a7258aa3381262c5f8146c278e890a598b07c5b7f86243de3f9b54'
  };
  for (const [relative, expectedSha] of Object.entries(expected)) {
    const absolute = path.join(repoRoot, relative);
    const actualSha = crypto.createHash('sha256').update(fs.readFileSync(absolute)).digest('hex');
    if (actualSha !== expectedSha) fail(`Wave 1B 보완 직전 hash 불일치: ${relative}`);
  }
  const manifest = fs.readFileSync(state.manifestFile, 'utf8');
  const currentSource = fs.readFileSync(path.join(repoRoot, sourceRelative), 'utf8');
  const currentTest = fs.readFileSync(path.join(repoRoot, testRelative), 'utf8');
  const priorReview = state.postReview;
  const before = visibleRepoHashes();
  state.status = 'uiux_wave1B_fixing';
  state.execution.fix = {
    executor: 'claude-fable-5',
    startedAt: new Date().toISOString(),
    allowedPaths: [sourceRelative, testRelative]
  };
  saveState(runDir, state);
  const result = invokeAgent('claude', {
    prompt: uiuxWave1BFixPrompt(manifest, priorReview.results, currentSource, currentTest),
    schema: executionSchema,
    mode: 'write-limited',
    runDir,
    label: 'uiux-wave1B-fix-claude-fable-5'
  });
  const after = visibleRepoHashes();
  const changedPaths = changedHashPaths(before, after);
  const allowed = new Set([sourceRelative, testRelative]);
  const unexpectedPaths = changedPaths.filter((file) => !allowed.has(file));
  const helperAfterSha = crypto.createHash('sha256')
    .update(fs.readFileSync(path.join(repoRoot, helperRelative))).digest('hex');
  state.execution.fix = {
    ...state.execution.fix,
    completedAt: new Date().toISOString(),
    result,
    changedPaths,
    unexpectedPaths,
    helperUnchanged: helperAfterSha === expected[helperRelative]
  };
  state.reviewHistory ??= [];
  state.reviewHistory.push(priorReview);
  delete state.postReview;
  state.status = result.status === 'complete'
      && unexpectedPaths.length === 0
      && helperAfterSha === expected[helperRelative]
    ? 'uiux_wave1B_implemented'
    : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'uiux-wave1B-fix-execution.json'),
    `${safeJson(state.execution.fix)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.execution.fix)}\n`);
}

function visibleRepoHashes() {
  const files = lines(git(['ls-files', '--cached', '--others', '--exclude-standard']));
  const hashes = {};
  for (const relative of files) {
    const absolute = path.join(repoRoot, relative);
    hashes[relative.replaceAll('\\', '/')] = fs.existsSync(absolute) && fs.statSync(absolute).isFile()
      ? crypto.createHash('sha256').update(fs.readFileSync(absolute)).digest('hex')
      : null;
  }
  return hashes;
}

function changedHashPaths(before, after) {
  return [...new Set([...Object.keys(before), ...Object.keys(after)])]
    .filter((file) => before[file] !== after[file])
    .sort();
}

function uiuxWaveExecutionPrompt(manifest) {
  return `
루트 AGENTS.md와 아래 양쪽 비준 완료 manifest를 준수해 UI/UX Wave 1A를 구현하라.
정확히 manifest의 기존 파일 6개와 신규 공용 위젯 3개만 변경할 수 있다.
Claude 모델은 이번 Wave에 한해 claude-fable-5이며, 기능·route·callback·상태·저장 key·호출 순서와 모든 기존 사용자 표시 문자열을 보존한다.
설정 페이지의 로직 메서드 본문은 수정하지 말고 build/UI 구조만 정비한다.
AppTheme, 기존 shared widget, add_pet_bottom_sheet, pet_detail_page, app_router, 보호 경로와 범위 밖 파일을 수정하지 않는다.
신규 패키지·자산을 추가하지 않는다. commit, merge, push, deploy, 운영 DB 작업을 하지 않는다.
필요한 import 정리와 manifest 파일만 대상으로 한 dart format은 허용한다.
범위 안에서 해결할 수 없는 문제가 있으면 파일 범위를 넓히지 말고 blocked로 응답한다.
구현 후 제공된 JSON 스키마로만 응답한다.

비준 manifest:
${manifest}
`;
}

function commandExecuteUiuxWave1A(runId) {
  const { runDir, state } = loadState(runId);
  if (state.status !== 'uiux_wave0_approved' || !state.ratification?.accepted) {
    fail(`양쪽이 비준한 UI/UX Wave 1A run이 아닙니다: ${state.status}`);
  }
  const manifest = fs.readFileSync(state.manifestFile, 'utf8');
  const currentManifestSha = crypto.createHash('sha256').update(manifest, 'utf8').digest('hex');
  if (currentManifestSha !== state.manifestSha256) fail('비준 뒤 Wave 1A manifest가 변경됐습니다. 다시 비준하세요.');
  const allowed = new Set([
    'pjh/lib/features/my/presentation/pages/my_settings_page.dart',
    'pjh/lib/features/profile/presentation/pages/notification_settings_page.dart',
    'pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart',
    'pjh/lib/features/profile/presentation/pages/help_page.dart',
    'pjh/lib/features/pets/presentation/pages/pet_management_page.dart',
    'pjh/lib/features/pets/presentation/widgets/pet_card.dart',
    'pjh/lib/shared/widgets/petspace_page_scaffold.dart',
    'pjh/lib/shared/widgets/petspace_settings_components.dart',
    'pjh/lib/shared/widgets/petspace_state_view.dart'
  ]);
  const expectedExisting = {
    'pjh/lib/features/my/presentation/pages/my_settings_page.dart': '7961f6f7464ca89ac7c26fe22e174ac5dbe3f71dae3dba97b1a152fb98779aa1',
    'pjh/lib/features/profile/presentation/pages/notification_settings_page.dart': 'bf3d4c15b03dd95125c32b9daebb93022f42d70a96c714efe6880a7def69b8d4',
    'pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart': '599a5965eeb9ce4ed0f69c89986f7753e31c98432ccedb14161ada5ecc0f2345',
    'pjh/lib/features/profile/presentation/pages/help_page.dart': '8dd11d4a16cc9981518e936d0ba9f2e2aade8b52eb4060ace6a9ff4459a831e3',
    'pjh/lib/features/pets/presentation/pages/pet_management_page.dart': '3c2bd44e364b9fae3a0884f7352097e935764815887b1a732ae897757559990f',
    'pjh/lib/features/pets/presentation/widgets/pet_card.dart': '73af49c2d8d7f53f20f6d1eff611f4767e7bc6cc05e30e4250631a99296dd89d'
  };
  for (const [relative, expected] of Object.entries(expectedExisting)) {
    const actual = crypto.createHash('sha256').update(fs.readFileSync(path.join(repoRoot, relative))).digest('hex');
    if (actual !== expected) fail(`구현 직전 hash 불일치: ${relative}`);
  }
  for (const relative of [...allowed].filter((file) => file.startsWith('pjh/lib/shared/widgets/petspace_'))) {
    if (fs.existsSync(path.join(repoRoot, relative))) fail(`신규 파일이 이미 존재합니다: ${relative}`);
  }
  const before = visibleRepoHashes();
  state.status = 'uiux_wave1A_executing';
  state.execution = { executor: 'claude', startedAt: new Date().toISOString() };
  saveState(runDir, state);
  const result = invokeAgent('claude', {
    prompt: uiuxWaveExecutionPrompt(manifest),
    schema: executionSchema,
    mode: 'write',
    runDir,
    label: 'uiux-wave1A-execution-claude'
  });
  const after = visibleRepoHashes();
  const changedPaths = changedHashPaths(before, after);
  const unexpectedPaths = changedPaths.filter((file) => !allowed.has(file));
  state.execution = {
    ...state.execution,
    completedAt: new Date().toISOString(),
    result,
    changedPaths,
    unexpectedPaths
  };
  state.status = result.status === 'complete' && unexpectedPaths.length === 0
    ? 'uiux_wave1A_implemented'
    : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'uiux-wave1A-execution.json'),
    `${safeJson(state.execution)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.execution)}\n`);
}

function uiuxWaveFixPrompt(manifest, reviews) {
  return `
루트 AGENTS.md와 아래 비준 manifest의 교차 리뷰 보완 addendum만 구현하라.
Claude 모델은 이번 Wave에 한해 claude-fable-5다.
기존 Wave 1A의 시각 방향과 모든 기능·route·callback·상태·저장 key·호출 순서·사용자 표시 문자열을 보존한다.
허용 범위는 기존 manifest 9개 파일과 신규 테스트 pjh/test/shared/widgets/petspace_wave1_widgets_test.dart뿐이다.
AppTheme, 기존 shared widget, 보호 경로, add_pet_bottom_sheet, pet_detail_page, app_router를 수정하지 않는다.
리뷰 finding에 따라 다크모드 Theme surface/text, 44px 터치 두 곳, 공용 위젯 테스트를 보완한다.
신규 테스트와 analyzer를 실행하고 전체 테스트의 기존 14개 실패와 신규 실패를 분리한다.
commit, merge, push, deploy, 운영 DB 작업을 하지 않는다. 범위 확장이 필요하면 blocked로 응답한다.
최종 응답은 JSON 스키마만 따른다.

비준 manifest:
${manifest}

독립 리뷰 결과:
${safeJson(reviews)}
`;
}

function commandFixUiuxWave1A(runId, reviewRunId) {
  const { runDir, state } = loadState(runId);
  const { state: reviewState } = loadState(reviewRunId);
  if (state.status !== 'uiux_wave0_approved' || !state.ratification?.accepted) {
    fail(`양쪽이 비준한 보완 run이 아닙니다: ${state.status}`);
  }
  if (reviewState.status !== 'uiux_wave1A_changes_required' || !reviewState.postReview) {
    fail(`changes_required 리뷰 run이 아닙니다: ${reviewState.status}`);
  }
  const manifest = fs.readFileSync(state.manifestFile, 'utf8');
  const currentManifestSha = crypto.createHash('sha256').update(manifest, 'utf8').digest('hex');
  if (currentManifestSha !== state.manifestSha256) fail('비준 뒤 보완 manifest가 변경됐습니다. 다시 비준하세요.');
  const allowed = new Set([
    'pjh/lib/features/my/presentation/pages/my_settings_page.dart',
    'pjh/lib/features/profile/presentation/pages/notification_settings_page.dart',
    'pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart',
    'pjh/lib/features/profile/presentation/pages/help_page.dart',
    'pjh/lib/features/pets/presentation/pages/pet_management_page.dart',
    'pjh/lib/features/pets/presentation/widgets/pet_card.dart',
    'pjh/lib/shared/widgets/petspace_page_scaffold.dart',
    'pjh/lib/shared/widgets/petspace_settings_components.dart',
    'pjh/lib/shared/widgets/petspace_state_view.dart',
    'pjh/test/shared/widgets/petspace_wave1_widgets_test.dart'
  ]);
  const expected = {
    'pjh/lib/features/my/presentation/pages/my_settings_page.dart': 'e489c97609f19eb25816a224c6c042d50f5231e64d958c679d8a7f12e5fe12fd',
    'pjh/lib/features/profile/presentation/pages/notification_settings_page.dart': '551cc907e1240d7fe3359f2e1e7704ad4e4b0fab0f2addc5d98bdd562b363479',
    'pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart': '3a233dd13fa581d93e73f6f921a17151c4ba8cce5084632ae68311616a0bc2a8',
    'pjh/lib/features/profile/presentation/pages/help_page.dart': 'b46867a0b6e72f146682985b3a44b683a64cd1b33bb1bb72917b166c21a864ab',
    'pjh/lib/features/pets/presentation/pages/pet_management_page.dart': 'ca7c70b6da1d6609dc1159f182de96182fde484966d8a194a19f672423bc86d6',
    'pjh/lib/features/pets/presentation/widgets/pet_card.dart': '6c9437c5e3dcf33b01821ad375006c7b03fab59673dd86389d272bfe650ecdf7',
    'pjh/lib/shared/widgets/petspace_page_scaffold.dart': 'd201bf22d6484ec03b301a72bc810a2518f0f178d047f125c37d9fd9e68c3429',
    'pjh/lib/shared/widgets/petspace_settings_components.dart': 'f56493e64723c6992d02757a9cbb8bab52d20052a1e79d825356ba76bca9ac58',
    'pjh/lib/shared/widgets/petspace_state_view.dart': '9140770849c09073bdd169f8311fe7170ec6514aa581d105b146c6891d617c68'
  };
  for (const [relative, expectedSha] of Object.entries(expected)) {
    const actual = crypto.createHash('sha256').update(fs.readFileSync(path.join(repoRoot, relative))).digest('hex');
    if (actual !== expectedSha) fail(`보완 직전 hash 불일치: ${relative}`);
  }
  const testFile = path.join(repoRoot, 'pjh/test/shared/widgets/petspace_wave1_widgets_test.dart');
  if (fs.existsSync(testFile)) fail('보완 테스트 파일이 이미 존재합니다. manifest를 다시 확인하세요.');
  const before = visibleRepoHashes();
  state.status = 'uiux_wave1A_fix_executing';
  state.execution = { executor: 'claude-fable-5', startedAt: new Date().toISOString(), reviewRunId };
  saveState(runDir, state);
  const result = invokeAgent('claude', {
    prompt: uiuxWaveFixPrompt(manifest, reviewState.postReview.results),
    schema: executionSchema,
    mode: 'write',
    runDir,
    label: 'uiux-wave1A-fix-claude-fable-5'
  });
  const after = visibleRepoHashes();
  const changedPaths = changedHashPaths(before, after);
  const unexpectedPaths = changedPaths.filter((file) => !allowed.has(file));
  state.execution = {
    ...state.execution,
    completedAt: new Date().toISOString(),
    result,
    changedPaths,
    unexpectedPaths
  };
  state.status = result.status === 'complete' && unexpectedPaths.length === 0
    ? 'uiux_wave1A_implemented'
    : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'uiux-wave1A-fix-execution.json'),
    `${safeJson(state.execution)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.execution)}\n`);
}

function commandRefineUiuxWave1A(runId) {
  const { runDir, state } = loadState(runId);
  if (state.status !== 'uiux_wave1A_changes_required' || !state.postReview) {
    fail(`보완할 수 없는 UI/UX Wave 1A 상태입니다: ${state.status}`);
  }
  const relative = 'pjh/lib/features/profile/presentation/pages/notification_settings_page.dart';
  const expectedSha = 'c24598a70845c944bae8db7b124d75222ad6f9e826c23d779dac9a7b36a3422c';
  const actualSha = crypto.createHash('sha256').update(fs.readFileSync(path.join(repoRoot, relative))).digest('hex');
  if (actualSha !== expectedSha) fail(`최종 보완 직전 hash 불일치: ${relative}`);
  const codexReview = state.postReview.results.codex;
  const before = visibleRepoHashes();
  state.status = 'uiux_wave1A_refining';
  state.refinement = { executor: 'claude-fable-5', startedAt: new Date().toISOString() };
  saveState(runDir, state);
  const prompt = `
루트 AGENTS.md와 비준된 Wave 1A addendum를 지키며 아래 Codex 최종 리뷰 finding 하나만 수정하라.
정확히 ${relative} 한 파일만 수정한다. Claude 모델은 claude-fable-5다.
_SystemPermissionWarning의 라이트모드 기존 경고 시각은 유지하고, 다크모드에서 배경·본문 text가 Theme.of(context).colorScheme.surface/onSurface 계열을 우선하도록 한다.
AppTheme.warningColor는 경고 icon·border·CTA 강조에 유지한다. 기존 문자열, onTap, TextButton 44px, 로직과 호출 순서를 변경하지 않는다.
dart format 해당 파일, flutter analyze --no-pub, 신규 Wave 1A widget test를 실행한다.
다른 파일, 테스트, 문서, AppTheme, 보호 경로를 수정하지 않는다. commit, push, deploy를 하지 않는다.
JSON 스키마로만 응답한다.

Codex finding:
${safeJson(codexReview)}
`;
  const result = invokeAgent('claude', {
    prompt,
    schema: executionSchema,
    mode: 'write',
    runDir,
    label: 'uiux-wave1A-refinement-claude-fable-5'
  });
  const after = visibleRepoHashes();
  const changedPaths = changedHashPaths(before, after);
  const unexpectedPaths = changedPaths.filter((file) => file !== relative);
  state.refinement = {
    ...state.refinement,
    completedAt: new Date().toISOString(),
    result,
    changedPaths,
    unexpectedPaths
  };
  state.execution = { ...state.execution, refinement: state.refinement };
  state.status = result.status === 'complete' && unexpectedPaths.length === 0
    ? 'uiux_wave1A_implemented'
    : 'needs_human_decision';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'uiux-wave1A-refinement.json'),
    `${safeJson(state.refinement)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.refinement)}\n`);
}

function uiuxWavePostReviewPrompt(manifest, execution, diffBundle) {
  return `
당신은 PetSpace UI/UX Wave 1A 구현의 독립 read-only 리뷰어다.
아래 비준 manifest, 실행 보고와 실제 diff를 대조하라. 추가 도구 호출이나 파일 수정은 하지 않는다.
correctness, route/callback/BLoC·저장 key·호출 순서, 사용자 표시 문구, 보호 경로, 다크모드·text scale,
접근성, overflow, 공용 컴포넌트 API, 테스트 공백 순서로 검토한다.
특히 신규 공용 컴포넌트가 Theme의 라이트·다크 surface/text를 우선해야 한다는 계약을 실제로 지키는지 확인한다.
기존 전체 테스트 실패 14건은 변경 전후 동일한 알려진 baseline이므로 이번 diff와 인과가 없으면 blocker/high로 올리지 않는다.
blocker/high가 없고 manifest에 맞으면 approve한다. medium/low 수정이 실제 제품 신뢰도에 필요하면 changes_required로 표시할 수 있다.
JSON 스키마로만 응답하라.

비준 manifest:
${manifest}

실행 보고:
${safeJson(execution)}

실제 diff와 신규 파일:
${diffBundle}
`;
}

function commandReviewUiuxWave1A(runId) {
  const { runDir, state } = loadState(runId);
  if (state.status !== 'uiux_wave1A_implemented') {
    fail(`리뷰할 수 없는 UI/UX Wave 1A 상태입니다: ${state.status}`);
  }
  const manifest = fs.readFileSync(state.manifestFile, 'utf8');
  const modified = [
    'pjh/lib/features/my/presentation/pages/my_settings_page.dart',
    'pjh/lib/features/profile/presentation/pages/notification_settings_page.dart',
    'pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart',
    'pjh/lib/features/profile/presentation/pages/help_page.dart',
    'pjh/lib/features/pets/presentation/pages/pet_management_page.dart',
    'pjh/lib/features/pets/presentation/widgets/pet_card.dart'
  ];
  const created = [
    'pjh/lib/shared/widgets/petspace_page_scaffold.dart',
    'pjh/lib/shared/widgets/petspace_settings_components.dart',
    'pjh/lib/shared/widgets/petspace_state_view.dart',
    'pjh/test/shared/widgets/petspace_wave1_widgets_test.dart'
  ];
  let diffBundle = git(['diff', '--', ...modified]);
  for (const relative of created) {
    diffBundle += `\n\n===== NEW FILE: ${relative} =====\n`;
    diffBundle += fs.readFileSync(path.join(repoRoot, relative), 'utf8');
  }
  const results = {};
  for (const agent of ['claude', 'codex']) {
    process.stdout.write(`${agent}가 UI/UX Wave 1A 구현을 독립 리뷰 중...\n`);
    results[agent] = invokeAgent(agent, {
      prompt: uiuxWavePostReviewPrompt(manifest, state.execution, diffBundle),
      schema: implementationReviewSchema,
      mode: 'read',
      runDir,
      label: `uiux-wave1A-post-review-${agent}`
    });
  }
  const severe = (review) => review.findings.some((finding) =>
    finding.severity === 'blocker' || finding.severity === 'high'
  );
  const approved = ['claude', 'codex'].every((agent) =>
    results[agent].verdict === 'approve' && !severe(results[agent])
  );
  state.postReview = { approved, results, reviewedAt: new Date().toISOString() };
  state.status = approved ? 'uiux_wave1A_review_approved' : 'uiux_wave1A_changes_required';
  saveState(runDir, state);
  fs.writeFileSync(
    path.join(runDir, 'uiux-wave1A-post-review.json'),
    `${safeJson(state.postReview)}\n`,
    'utf8'
  );
  printRunSummary(state);
  process.stdout.write(`${safeJson(state.postReview)}\n`);
}

function makeBranchName(state) {
  const short = state.id.slice(-4).toLowerCase();
  return `feature/auto-${state.consensus.executor}-${short}`;
}

function executionPrompt(state, workOrder) {
  return `
루트 AGENTS.md를 준수하고 아래 승인된 작업지시서를 구현하라.
현재 worktree 밖 파일을 수정하지 않는다. push, merge, rebase, tag, 배포, 운영 DB 실행을 하지 않는다.
작업지시서 범위를 벗어난 문제는 수정하지 말고 issues에 기록한다.
검증 명령은 위험하지 않은 범위에서 실행하고, 실행하지 못한 검증은 이유를 남긴다.
커밋은 만들지 않는다. 최종 응답은 제공된 JSON 스키마만 따른다.

승인된 작업지시서:
${workOrder}
`;
}

function implementationReviewPrompt(state, workOrder) {
  return `
루트 AGENTS.md와 아래 작업지시서를 기준으로 현재 worktree의 미커밋 변경을 read-only 리뷰하라.
파일 수정, 커밋, push, DB 실행을 하지 않는다. git diff와 관련 코드를 확인하고 correctness, 보안·개인정보,
법무 문구, 회귀, 테스트 공백 순으로 검토한다. 최종 응답은 제공된 JSON 스키마만 따른다.

작업지시서:
${workOrder}
`;
}

function executeApproved(runDir, state) {
  if (!state.approval?.approvedAt) fail('사람 승인 기록이 없습니다. 먼저 approve를 실행하세요.');
  if (!['approved', 'execution_failed'].includes(state.status)) fail(`현재 상태에서는 실행할 수 없습니다: ${state.status}`);
  const dirty = git(['status', '--porcelain']);
  if (dirty) fail('기준 저장소가 깨끗하지 않습니다. 설정 변경을 사람이 검토·커밋한 뒤 실행하세요.', dirty);
  const currentBaseCommit = git(['rev-parse', state.baseBranch]);
  if (currentBaseCommit !== state.baseCommit) {
    fail('토론 후 기준 브랜치가 변경됐습니다. 오래된 작업지시서 실행을 막았습니다. 새 run을 시작하세요.');
  }

  const branch = makeBranchName(state);
  const worktreesRoot = path.join(path.dirname(repoRoot), 'pjh_agent_worktrees');
  const worktree = path.join(worktreesRoot, `${state.id}-${state.consensus.executor}`);
  if (fs.existsSync(worktree)) fail(`worktree 경로가 이미 존재합니다: ${worktree}`);
  ensureDir(worktreesRoot);
  git(['worktree', 'add', '-b', branch, worktree, state.baseBranch]);

  const workOrder = fs.readFileSync(state.consensus.workOrderFile, 'utf8');
  const trackedWorkOrderDir = path.join(worktree, 'docs', 'work-orders');
  ensureDir(trackedWorkOrderDir);
  const trackedWorkOrder = path.join(trackedWorkOrderDir, `${state.id}.md`);
  fs.writeFileSync(trackedWorkOrder, workOrder, 'utf8');

  state.status = 'executing';
  state.execution = { branch, worktree, executor: state.consensus.executor, trackedWorkOrder };
  saveState(runDir, state);

  try {
    process.stdout.write(`${state.consensus.executor}가 전용 worktree에서 구현 중...\n`);
    const result = invokeAgent(state.consensus.executor, {
      prompt: executionPrompt(state, workOrder),
      schema: executionSchema,
      mode: 'write',
      runDir,
      label: `execution-${state.consensus.executor}`,
      cwd: worktree
    });
    fs.writeFileSync(path.join(runDir, 'execution-result.json'), `${safeJson(result)}\n`, 'utf8');
    state.execution.result = result;
    if (result.status !== 'complete') {
      state.status = 'execution_failed';
      saveState(runDir, state);
      printRunSummary(state);
      return;
    }

    const reviewer = otherAgent(state.consensus.executor);
    process.stdout.write(`${reviewer}가 구현 결과를 read-only 교차 리뷰 중...\n`);
    const review = invokeAgent(reviewer, {
      prompt: implementationReviewPrompt(state, workOrder),
      schema: implementationReviewSchema,
      mode: 'read',
      runDir,
      label: `implementation-review-${reviewer}`,
      cwd: worktree
    });
    fs.writeFileSync(path.join(runDir, 'implementation-review.json'), `${safeJson(review)}\n`, 'utf8');
    state.execution.reviewer = reviewer;
    state.execution.review = review;
    state.execution.gitStatus = git(['status', '--short'], worktree);
    state.execution.diffCheck = git(['diff', '--check'], worktree);
    state.status = 'awaiting_final_approval';
    saveState(runDir, state);
    printRunSummary(state);
    process.stdout.write('구현과 교차 리뷰가 끝났습니다. 사람이 diff와 실기기 결과를 확인한 뒤 merge·push를 결정하세요.\n');
  } catch (error) {
    state.status = 'execution_failed';
    state.execution.error = error.message;
    saveState(runDir, state);
    throw error;
  }
}

function commandApprove(runId, args) {
  const { runDir, state } = loadState(runId);
  if (state.status !== 'awaiting_approval') fail(`승인할 수 없는 상태입니다: ${state.status}`);
  if (!args.code || args.code.toUpperCase() !== state.approval.code) fail('승인 코드가 일치하지 않습니다.');
  state.approval.approvedAt = new Date().toISOString();
  state.approval.approvedBy = os.userInfo().username;
  state.status = 'approved';
  saveState(runDir, state);
  if (args.investigate) executeInvestigation(runDir, state);
  else if (args.execute) executeApproved(runDir, state);
  else printRunSummary(state);
}

function commandExecute(runId) {
  const { runDir, state } = loadState(runId);
  executeApproved(runDir, state);
}

function printHelp() {
  process.stdout.write(`
PetSpace Claude × Codex 오케스트레이터

사용법:
  node scripts/agent-collab.mjs preflight
  node scripts/agent-collab.mjs self-test
  node scripts/agent-collab.mjs start --topic "주제" [--first codex|claude] [--rounds 1..5]
  node scripts/agent-collab.mjs status <run-id>
  node scripts/agent-collab.mjs continue <run-id> [--rounds 1..3]
  node scripts/agent-collab.mjs ratify <run-id>
  node scripts/agent-collab.mjs ratify-cleanup <run-id>
  node scripts/agent-collab.mjs review-cleanup <run-id>
  node scripts/agent-collab.mjs review-uiux-plan [--rounds 1..5]
  node scripts/agent-collab.mjs ratify-uiux-wave0
  node scripts/agent-collab.mjs ratify-uiux-wave1c --mockup <absolute-html-path> [--run <run-id>]
  node scripts/agent-collab.mjs execute-uiux-wave1c <run-id>
  node scripts/agent-collab.mjs review-uiux-wave1c <run-id>
  node scripts/agent-collab.mjs rereview-uiux-wave1c <run-id>
  node scripts/agent-collab.mjs ratify-uiux-wave1b --mockup <absolute-html-path> [--run <run-id>]
  node scripts/agent-collab.mjs execute-uiux-wave1b <run-id>
  node scripts/agent-collab.mjs review-uiux-wave1b <run-id>
  node scripts/agent-collab.mjs fix-uiux-wave1b <run-id>
  node scripts/agent-collab.mjs execute-uiux-wave1a <run-id>
  node scripts/agent-collab.mjs review-uiux-wave1a <run-id>
  node scripts/agent-collab.mjs fix-uiux-wave1a <ratification-run-id> <review-run-id>
  node scripts/agent-collab.mjs refine-uiux-wave1a <run-id>
  node scripts/agent-collab.mjs approve <run-id> --code <승인코드> [--execute]
  node scripts/agent-collab.mjs approve <run-id> --code <승인코드> --investigate
  node scripts/agent-collab.mjs investigate <run-id>
  node scripts/agent-collab.mjs execute <run-id>

start는 읽기 전용 토론만 수행합니다. 구현은 합의 후 승인 코드가 입력돼야 시작됩니다.
`);
}

ensureDir(runsRoot);
const args = parseArgs(process.argv.slice(2));
const command = args._[0] ?? 'help';

try {
  if (command === 'preflight') commandPreflight();
  else if (command === 'self-test') commandSelfTest();
  else if (command === 'start') commandStart(args);
  else if (command === 'status') commandStatus(args._[1]);
  else if (command === 'continue') commandContinue(args._[1], args);
  else if (command === 'ratify') commandRatify(args._[1]);
  else if (command === 'ratify-cleanup') commandRatifyCleanup(args._[1]);
  else if (command === 'review-cleanup') commandReviewCleanup(args._[1]);
  else if (command === 'review-uiux-plan') commandReviewUiuxPlan(args);
  else if (command === 'ratify-uiux-wave0') commandRatifyUiuxWave0();
  else if (command === 'ratify-uiux-wave1c') commandRatifyUiuxWave1C(args);
  else if (command === 'execute-uiux-wave1c') commandExecuteUiuxWave1C(args._[1]);
  else if (command === 'review-uiux-wave1c') commandReviewUiuxWave1C(args._[1]);
  else if (command === 'rereview-uiux-wave1c') commandRereviewUiuxWave1C(args._[1]);
  else if (command === 'ratify-uiux-wave1b') commandRatifyUiuxWave1B(args);
  else if (command === 'execute-uiux-wave1b') commandExecuteUiuxWave1B(args._[1]);
  else if (command === 'review-uiux-wave1b') commandReviewUiuxWave1B(args._[1]);
  else if (command === 'fix-uiux-wave1b') commandFixUiuxWave1B(args._[1]);
  else if (command === 'execute-uiux-wave1a') commandExecuteUiuxWave1A(args._[1]);
  else if (command === 'review-uiux-wave1a') commandReviewUiuxWave1A(args._[1]);
  else if (command === 'fix-uiux-wave1a') commandFixUiuxWave1A(args._[1], args._[2]);
  else if (command === 'refine-uiux-wave1a') commandRefineUiuxWave1A(args._[1]);
  else if (command === 'approve') commandApprove(args._[1], args);
  else if (command === 'execute') commandExecute(args._[1]);
  else if (command === 'investigate') commandInvestigate(args._[1]);
  else printHelp();
} catch (error) {
  fail(error.message);
}
