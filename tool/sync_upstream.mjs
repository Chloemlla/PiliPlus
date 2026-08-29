#!/usr/bin/env node
// Merge the fork-sync upstream PR into this fork's main branch.
//
// Upstream ships `package:PiliPlus/` while this fork uses `package:pili_plus/`,
// so nearly every upstream commit produces import-only conflicts. This script
// re-runs the three-way merge per conflicted file with the upstream side
// normalized to the fork's package name, which resolves those mechanically and
// leaves only genuine divergences for a human.
//
// Usage: node tool/sync_upstream.mjs
// Every knob is an environment variable; see CONFIG.

import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const env = (name, fallback) => process.env[name]?.trim() || fallback;

const CONFIG = {
  upstreamUrl: env(
    'SYNC_UPSTREAM_URL',
    'https://github.com/bggRGjQaUbCoE/PiliPlus.git',
  ),
  upstreamRef: env('SYNC_UPSTREAM_REF', 'main'),
  headSha: env('SYNC_HEAD_SHA', ''),
  baseBranch: env('SYNC_BASE_BRANCH', 'main'),
  prNumber: env('SYNC_PR', ''),
  refreshLock: env('SYNC_REFRESH_LOCK', '1') !== '0',
  sign: env('SYNC_SIGN', '0') === '1',
  push: env('SYNC_PUSH', '1') !== '0',
};

const RENAME_RULES = [
  {
    path: /\.(dart|patch)$/i,
    find: /package:PiliPlus\//g,
    to: 'package:pili_plus/',
  },
  {
    path: /(^|\/)pubspec\.yaml$/,
    find: /^name:[ \t]+PiliPlus[ \t]*$/m,
    to: 'name: pili_plus',
  },
];

// Conflicts here are not worth merging: the file is regenerated below.
const REGENERATED_PATHS = new Set(['pubspec.lock']);

const REPORT_PATH = join(env('RUNNER_TEMP', tmpdir()), 'sync-conflicts.txt');

const TOTAL_STEPS = 7;
let stepNo = 0;
const step = (msg) => console.log(`\n[${++stepNo}/${TOTAL_STEPS}] ${msg}`);
const note = (msg) => console.log(`        ${msg}`);

function run(cmd, args, { allowFail = false } = {}) {
  const result = spawnSync(cmd, args, { encoding: 'utf8', maxBuffer: 1 << 28 });
  if (result.error) throw result.error;
  if (!allowFail && result.status !== 0) {
    throw new Error(
      `${cmd} ${args.join(' ')} exited ${result.status}\n${result.stderr}`,
    );
  }
  return result;
}

const git = (args, opts) => run('git', args, opts);
const gitOut = (args) => git(args).stdout.trim();
const gitLines = (args) =>
  gitOut(args).split('\n').map((line) => line.trim()).filter(Boolean);

function normalize(path, content) {
  let output = content;
  for (const rule of RENAME_RULES) {
    if (rule.path.test(path)) output = output.replace(rule.find, rule.to);
  }
  return output;
}

const isRenamable = (path) => RENAME_RULES.some((rule) => rule.path.test(path));

// `git ls-files -u` prints one line per stage: "<mode> <sha> <stage>\t<path>".
function unmergedStages() {
  const byPath = new Map();
  for (const line of gitLines(['ls-files', '-u'])) {
    const [meta, path] = line.split('\t');
    const [, sha, stage] = meta.split(/\s+/);
    if (!byPath.has(path)) byPath.set(path, {});
    byPath.get(path)[stage] = sha;
  }
  return byPath;
}

const gitBlob = (sha) => git(['cat-file', 'blob', sha]).stdout;

function remergeNormalized(scratch, path, stages) {
  const files = { base: join(scratch, 'base'), ours: join(scratch, 'ours'), theirs: join(scratch, 'theirs') };
  // Stage 1 is missing for add/add conflicts; an empty base is the right input.
  writeFileSync(files.base, stages['1'] ? normalize(path, gitBlob(stages['1'])) : '');
  writeFileSync(files.ours, gitBlob(stages['2']));
  writeFileSync(files.theirs, normalize(path, gitBlob(stages['3'])));

  const merged = run('git', [
    'merge-file', '-p',
    '-L', 'fork', '-L', 'merge base', '-L', 'upstream',
    files.ours, files.base, files.theirs,
  ], { allowFail: true });
  if (merged.status !== 0) return false;

  writeFileSync(path, merged.stdout);
  git(['add', '--', path]);
  return true;
}

function abortWithConflicts(paths) {
  const report = paths.map((path) => `- ${path}`).join('\n');
  writeFileSync(REPORT_PATH, `${report}\n`);
  git(['merge', '--abort'], { allowFail: true });
  console.error(
    `\nUnresolved conflicts remain after normalizing the package name:\n${report}\n\n` +
      'These are real divergences between the fork and upstream; resolve them locally.',
  );
  process.exitCode = 2;
}

function resolveConflicts(scratch) {
  const stillConflicted = [];
  const stages = unmergedStages();
  const paths = [...stages.keys()].sort();
  paths.forEach((path, index) => {
    const label = `[${index + 1}/${paths.length}] ${path}`;
    if (REGENERATED_PATHS.has(path)) {
      git(['checkout', '--ours', '--', path]);
      git(['add', '--', path]);
      note(`${label} -> kept fork copy, regenerated below`);
      return;
    }
    const entry = stages.get(path);
    if (!entry['2'] || !entry['3'] || !isRenamable(path)) {
      stillConflicted.push(path);
      note(`${label} -> needs a human`);
      return;
    }
    if (remergeNormalized(scratch, path, entry)) {
      note(`${label} -> resolved by normalizing`);
    } else {
      stillConflicted.push(path);
      note(`${label} -> needs a human`);
    }
  });
  return stillConflicted;
}

// Upstream files that merged cleanly still carry the upstream package name.
function normalizeTree() {
  const changed = [];
  for (const path of gitLines(['ls-files'])) {
    if (!isRenamable(path)) continue;
    const before = readFileSync(path, 'utf8');
    const after = normalize(path, before);
    if (after === before) continue;
    writeFileSync(path, after);
    git(['add', '--', path]);
    changed.push(path);
  }
  return changed;
}

function refreshLockfile() {
  const pubGet = run('flutter', ['pub', 'get'], { allowFail: true });
  if (pubGet.error || pubGet.status !== 0) {
    note('flutter pub get unavailable or failed; leaving pubspec.lock alone');
    return false;
  }
  const dirty = gitOut(['status', '--porcelain', '--', 'pubspec.lock']);
  if (!dirty) {
    note('pubspec.lock already matches pubspec.yaml');
    return false;
  }
  git(['add', '--', 'pubspec.lock']);
  return true;
}

function main() {
  step(`Preflight on ${CONFIG.baseBranch}`);
  const branch = gitOut(['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch !== CONFIG.baseBranch) {
    throw new Error(`expected to be on ${CONFIG.baseBranch}, found ${branch}`);
  }
  if (gitOut(['status', '--porcelain'])) {
    throw new Error('working tree is dirty; refusing to merge');
  }
  note(`fork tip ${gitOut(['rev-parse', '--short', 'HEAD'])}`);

  step(`Fetch upstream ${CONFIG.upstreamRef}`);
  const target = CONFIG.headSha || `refs/heads/${CONFIG.upstreamRef}`;
  git(['fetch', '--no-tags', CONFIG.upstreamUrl, target]);
  const head = CONFIG.headSha || gitOut(['rev-parse', 'FETCH_HEAD']);
  note(`upstream tip ${head.slice(0, 9)}`);

  step('Merge upstream');
  const alreadyMerged = git(['merge-base', '--is-ancestor', head, 'HEAD'], {
    allowFail: true,
  });
  if (alreadyMerged.status === 0) {
    note('already merged; nothing to do');
    return;
  }
  const merge = git(['merge', '--no-commit', '--no-ff', head], { allowFail: true });
  note(merge.status === 0 ? 'merged cleanly' : 'conflicts to normalize');

  step('Resolve conflicts by normalizing the package name');
  const scratch = mkdtempSync(join(tmpdir(), 'sync-'));
  const stuck = resolveConflicts(scratch);
  if (stuck.length) {
    abortWithConflicts(stuck);
    return;
  }

  step('Normalize package name across the merged tree');
  const renamed = normalizeTree();
  note(`${renamed.length} file(s) rewritten`);

  step('Refresh pubspec.lock');
  const lockChanged = CONFIG.refreshLock ? refreshLockfile() : false;
  if (!CONFIG.refreshLock) note('skipped (SYNC_REFRESH_LOCK=0)');

  step('Commit and push');
  const commitArgs = ['commit', '--no-edit'];
  if (CONFIG.sign) commitArgs.push('-S');
  git(commitArgs);
  const merged = gitOut(['rev-parse', '--short', 'HEAD']);
  if (CONFIG.push) {
    git(['push', 'origin', `HEAD:${CONFIG.baseBranch}`]);
    note(`pushed ${merged} to ${CONFIG.baseBranch}`);
  } else {
    note(`created ${merged} locally (SYNC_PUSH=0)`);
  }

  console.log(
    `\nSynced ${head.slice(0, 9)} into ${CONFIG.baseBranch}: ` +
      `${renamed.length} file(s) renamed, ` +
      `pubspec.lock ${lockChanged ? 'regenerated' : 'unchanged'}.`,
  );
}

main();
