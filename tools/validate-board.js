#!/usr/bin/env node
// Ralph board validator / writer.
//
//   node tools/validate-board.js <board.js | tasks.json> [--repo <gitRoot>] [--branch <name>] [--tree <listing.txt>]
//                               [--write [<out tasks.json>]] [--repo-key <key>]
//
// <board.js>   CommonJS module exporting the task array (the author's source), or an existing tasks.json (BOM ok).
// --repo/--branch   run `git ls-tree -r --name-only <branch>` to check that every `files` entry exists
//                   (a glob must match something; a plain path must exist unless the task's steps/notes name it
//                   as a file the task creates). --tree takes a ready listing instead.
// --write      on success write tasks.json (UTF-8 BOM + CRLF, like the orchestrator reads it) after archiving the
//              previous board to results/tasks-archive-<stamp>.json. Without --write nothing is written.
// --repo-key   expected `repo` value on every task (default: the only key seen if all tasks agree).
//
// Exit code 1 on any error or on a CONCURRENT cross-lane file-zone overlap (same file reachable by two tasks of
// different lanes with no dependsOn path between them).
//
// Rules encoded here come from .claude/skills/ralph-plan/SKILL.md (§2б, §3, §3а, §4) and the boards that broke them:
//   - verify strings run via `cmd /c`: an unquoted | is a PIPE; ( ) & < > ^ are operators  (board 5, 16.11.2026)
//   - `files` entries must exist in the target tree                                          (board 5, 16.11.2026)
//   - every task needs the full field set incl. `passes: false` and RECON..DONE steps          (30.09.2026)
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const argv = process.argv.slice(2);
const opt = (name, dflt) => { const i = argv.indexOf(name); return i >= 0 ? (argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : true) : dflt; };
const src = argv.find((a) => !a.startsWith('--') && (argv.indexOf(a) === 0 || !argv[argv.indexOf(a) - 1].startsWith('--')));
if (!src) { console.error('usage: node tools/validate-board.js <board.js|tasks.json> [--repo <gitRoot> --branch <b> | --tree <listing>] [--write [out]]'); process.exit(2); }

const RALPH_ROOT = path.resolve(__dirname, '..');
const srcPath = path.resolve(src);
let tasks;
if (/\.json$/i.test(srcPath)) tasks = JSON.parse(fs.readFileSync(srcPath, 'utf8').replace(/^﻿/, ''));
else tasks = [...require(srcPath)];
if (!Array.isArray(tasks)) { console.error('board source must export/contain an ARRAY of tasks'); process.exit(2); }

const WRITE = opt('--write', false);
const OUT = typeof WRITE === 'string' ? path.resolve(WRITE) : path.join(RALPH_ROOT, 'tasks.json');
const REPO_KEY = opt('--repo-key', null);

const REQUIRED = ['id', 'category', 'repo', 'lane', 'model', 'dependsOn', 'files', 'description',
  'specRef', 'tddWorkflow', 'notes', 'steps', 'passes'];
const OPTIONAL = ['verify', 'migrationRef'];
const errors = [], warnings = [];

// ---- field set (live exemplar: any archived task in results/)
const repoKeys = new Set(tasks.map((t) => t.repo));
for (const t of tasks) {
  for (const f of REQUIRED) if (!(f in t)) errors.push('task ' + t.id + ': missing field ' + f);
  for (const k of Object.keys(t)) if (!REQUIRED.includes(k) && !OPTIONAL.includes(k)) errors.push('task ' + t.id + ': unknown field ' + k);
  if (t.passes !== false && t.passes !== true) errors.push('task ' + t.id + ': passes must be a boolean (false for a new task; a task without it is INVISIBLE to the orchestrator)');
  if (!Array.isArray(t.steps) || !t.steps.length) errors.push('task ' + t.id + ': steps missing');
  else {
    const phases = t.steps.map((s) => s.phase);
    if (phases[phases.length - 1] !== 'DONE') errors.push('task ' + t.id + ': last step must be DONE');
    if (phases[0] !== 'RECON') errors.push('task ' + t.id + ': first step must be RECON');
    for (const s of t.steps) {
      if (!s.id || !s.phase || !s.action) errors.push('task ' + t.id + ': malformed step ' + JSON.stringify(s));
      if (s.id && !String(s.id).startsWith(String(t.id) + '.')) errors.push('task ' + t.id + ': step id ' + s.id + ' does not match task id');
    }
  }
  if (!['easy', 'heavy'].includes(t.model) && !/^claude-/.test(String(t.model))) errors.push('task ' + t.id + ': bad model ' + t.model);
  if (REPO_KEY && t.repo !== REPO_KEY) errors.push('task ' + t.id + ': repo must be ' + REPO_KEY);
  if (!Array.isArray(t.files) || !t.files.length) errors.push('task ' + t.id + ': empty files');
  if (!Array.isArray(t.dependsOn)) errors.push('task ' + t.id + ': dependsOn must be an array');
  // verify strings run via `cmd /c`
  for (const v of t.verify || []) {
    if (/\|/.test(v) && !/"[^"]*\|[^"]*"/.test(v)) errors.push('task ' + t.id + ': verify has an unquoted | (cmd /c pipes it): ' + v);
    if (/[()&<>^]/.test(v)) errors.push('task ' + t.id + ': verify has a cmd special char ( ) & < > ^ (ralph-plan §3а: one simple substring per line): ' + v);
  }
  if (!/^[a-z]+(\([a-z0-9-]+\))?: /.test(String(t.description))) warnings.push('task ' + t.id + ': description not conventional-commit shaped: ' + t.description);
}
if (!REPO_KEY && repoKeys.size > 1) warnings.push('tasks span repos: ' + [...repoKeys].join(', '));

// ---- unique ids, dependsOn targets
const seen = new Set();
for (const t of tasks) { if (seen.has(t.id)) errors.push('duplicate id ' + t.id); seen.add(t.id); }
for (const t of tasks) for (const d of t.dependsOn || []) if (!seen.has(d)) errors.push('task ' + t.id + ': dependsOn ' + d + ' does not exist');

// ---- graph: lane order + dependsOn, cycles, critical path
const preds = new Map(tasks.map((t) => [t.id, new Set(t.dependsOn || [])]));
const lanes = new Map();
for (const t of tasks) { if (!lanes.has(t.lane)) lanes.set(t.lane, []); lanes.get(t.lane).push(t.id); }
for (const [, ids] of lanes) for (let i = 1; i < ids.length; i++) preds.get(ids[i]).add(ids[i - 1]);
const depth = new Map(), visiting = new Set();
const dep = (id) => {
  if (depth.has(id)) return depth.get(id);
  if (visiting.has(id)) { errors.push('CYCLE through task ' + id); return 0; }
  visiting.add(id);
  let d = 1;
  for (const p of preds.get(id) || []) d = Math.max(d, dep(p) + 1);
  visiting.delete(id);
  depth.set(id, d);
  return d;
};
for (const t of tasks) dep(t.id);
const K = Math.max(0, ...[...depth.values()]);

// ---- cross-lane file-zone intersections
const norm = (g) => g.replace(/\*+$/, '').replace(/\/+$/, '');
const reachable = (a, b) => {
  const stack = [b], seenR = new Set();
  while (stack.length) {
    const cur = stack.pop();
    if (cur === a) return true;
    if (seenR.has(cur)) continue;
    seenR.add(cur);
    for (const p of preds.get(cur) || []) stack.push(p);
  }
  return false;
};
const collisions = [];
const pending = tasks.filter((t) => t.passes === false);
for (let i = 0; i < pending.length; i++) for (let j = i + 1; j < pending.length; j++) {
  const A = pending[i], B = pending[j];
  if (A.lane === B.lane || A.repo !== B.repo) continue;
  for (const fa of A.files) for (const fb of B.files) {
    const a = norm(fa), b = norm(fb);
    if (a && b && (a === b || a.startsWith(b) || b.startsWith(a))) {
      collisions.push({ a: A.id, b: B.id, fa, fb, sequenced: reachable(A.id, B.id) || reachable(B.id, A.id) });
    }
  }
}

// ---- files must exist in the target tree
let listing = null;
const treeFile = opt('--tree', null), repoRoot = opt('--repo', null), branch = opt('--branch', 'HEAD');
if (treeFile) listing = fs.readFileSync(treeFile, 'utf8');
else if (repoRoot) listing = execFileSync('git', ['-C', repoRoot, 'ls-tree', '-r', '--name-only', branch], { encoding: 'utf8', maxBuffer: 64 << 20 });
if (listing) {
  const all = new Set(listing.split(/\r?\n/).filter(Boolean));
  const allArr = [...all];
  const esc = (s) => s.replace(/[.+^${}()|[\]\\]/g, '\\$&');
  for (const t of pending) {
    const created = (t.steps || []).map((s) => s.action).join(' ') + ' ' + t.notes;
    for (const f of t.files) {
      if (/[*?]/.test(f)) {
        const re = new RegExp('^' + f.split('**').map((seg) => seg.split('*').map(esc).join('[^/]*')).join('.*') + '$');
        if (!allArr.some((a) => re.test(a))) {
          const zone = f.replace(/\/?\*+.*$/, '');
          const tail = zone.split('/').slice(-2).join('/');
          if (zone && (created.includes(zone) || created.includes(tail))) warnings.push('task ' + t.id + ': new zone (named in steps/notes): ' + f);
          else errors.push('task ' + t.id + ': files glob matches NOTHING in the tree and the zone is not named in steps/notes (invented folder?): ' + f);
        }
      } else if (!all.has(f)) {
        if (created.includes(f.split('/').pop())) warnings.push('task ' + t.id + ': new file (named in steps/notes): ' + f);
        else errors.push('task ' + t.id + ': file does not exist in the tree and is not declared as created: ' + f);
      }
    }
  }
} else {
  warnings.push('no --repo/--tree given: file existence NOT checked (board 5 lesson: invented paths stop tasks after RECON)');
}

// ---- report
console.log('================= BOARD VALIDATION =================');
console.log('source: ' + srcPath);
console.log('tasks: ' + tasks.length + ' (pending ' + pending.length + ') | lanes: ' + lanes.size + ' | critical path K: ' + K + ' | K/N: ' + (tasks.length ? (K / tasks.length).toFixed(2) : '-'));
const models = tasks.reduce((a, t) => ((a[t.model] = (a[t.model] || 0) + 1), a), {});
console.log('models: ' + JSON.stringify(models) + ' | explicit verify: ' + tasks.filter((t) => t.verify).length + '/' + tasks.length);
console.log('');
console.log('--- cross-lane file-zone overlaps (pending tasks) ---');
const unseq = collisions.filter((c) => !c.sequenced);
for (const c of collisions) console.log('  ' + (c.sequenced ? '[sequenced] ' : '[!! CONCURRENT !!] ') + c.a + ' <-> ' + c.b + '   ' + c.fa + '  ~  ' + c.fb);
if (!collisions.length) console.log('  (none)');
console.log('');
if (warnings.length) { console.log('--- warnings ---'); warnings.forEach((w) => console.log('  ' + w)); console.log(''); }
if (errors.length) { console.log('--- ERRORS ---'); errors.forEach((e) => console.log('  ' + e)); console.log(''); }

if (errors.length || unseq.length) {
  console.log('INVALID: ' + errors.length + ' errors, ' + unseq.length + ' concurrent zone overlaps.' + (WRITE ? ' NOT WRITTEN.' : ''));
  process.exitCode = 1;
} else {
  console.log('VALID.');
  console.log('--- execution order (depth = wave) ---');
  const waves = new Map();
  for (const t of pending) { const d = depth.get(t.id); if (!waves.has(d)) waves.set(d, []); waves.get(d).push(t.id + ' ' + t.lane); }
  for (const d of [...waves.keys()].sort((x, y) => x - y)) console.log('  wave ' + d + ': ' + waves.get(d).join(' | '));
  if (WRITE) {
    if (path.resolve(srcPath) !== OUT && fs.existsSync(OUT)) {
      const stamp = new Date().toISOString().replace(/[:.]/g, '-');
      const archive = path.join(RALPH_ROOT, 'results', 'tasks-archive-' + stamp + '.json');
      fs.mkdirSync(path.dirname(archive), { recursive: true });
      fs.copyFileSync(OUT, archive);
      console.log('archived previous board -> ' + archive);
    }
    fs.writeFileSync(OUT, '﻿' + JSON.stringify(tasks, null, 2).replace(/\n/g, '\r\n') + '\r\n', 'utf8');
    console.log('WROTE ' + OUT + ' (UTF-8 BOM + CRLF)');
  }
}
