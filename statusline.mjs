#!/usr/bin/env node
/**
 * Claude Code status line.
 *
 * Reads session JSON on stdin, prints a formatted status bar on stdout.
 * Tweak the CONFIG block below to change what is shown.
 *
 * Docs for every available field: https://code.claude.com/docs/en/statusline
 */

import { execFileSync } from "node:child_process";
import { basename, sep } from "node:path";
import { homedir } from "node:os";

const CONFIG = {
  multiline: false, // true = git info on line 1, context/usage on line 2
  barWidth: 10, // width of the context bar, in characters
  showEffort: true, // reasoning effort (low/medium/high/xhigh/max)
  showGit: true, // branch, dirty marker, ahead/behind counts
  showContext: true, // context window bar + percentage
  showTokens: true, // "(94k/200k)" next to the context percentage
  showLines: true, // lines added/removed this session
  showRateLimits: true, // 5-hour and 7-day subscription usage
  rateLimitThreshold: 0, // hide a limit below this percentage (0 = always show)
  rateLimitResetAt: 70, // append the reset time once a limit hits this percentage
  showSessionName: true, // custom name set via --name or /rename
  showCost: false, // session cost in USD (only meaningful on API billing)
};

// --- ANSI colors -----------------------------------------------------------
const a = (n) => `\x1b[${n}m`;
const RESET = a(0);
const BOLD = a(1);
const GRAY = a(90);
const RED = a(31);
const GREEN = a(32);
const YELLOW = a(33);
const BLUE = a(34);
const MAGENTA = a(35);
const CYAN = a(36);

const paint = (color, text) => `${color}${text}${RESET}`;
const SEP = paint(GRAY, " │ ");

// --- helpers ---------------------------------------------------------------

/** Color for a 0-100 usage value: green when there is room, red when nearly full. */
function usageColor(pct) {
  if (pct >= 85) return RED;
  if (pct >= 60) return YELLOW;
  return GREEN;
}

function bar(pct, width) {
  const filled = Math.min(width, Math.max(0, Math.round((pct / 100) * width)));
  return "█".repeat(filled) + "░".repeat(width - filled);
}

function shortTokens(n) {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(n % 1_000_000 === 0 ? 0 : 1)}M`;
  if (n >= 1_000) return `${Math.round(n / 1_000)}k`;
  return String(n);
}

/** Display name for the working directory, with the home dir collapsed to ~. */
function prettyDir(dir) {
  if (!dir) return "";
  // Claude Code may send forward slashes on Windows; homedir() uses backslashes.
  const norm = (p) => p.replace(/[\\/]+$/, "").replace(/\\/g, "/").toLowerCase();
  if (norm(dir) === norm(homedir())) return "~";
  return basename(dir) || dir.split(sep).filter(Boolean).pop() || dir;
}

/**
 * One `git status` call gives branch, upstream ahead/behind, and dirty state.
 * Returns null outside a repository, or if git is slow/unavailable.
 */
function gitInfo(cwd) {
  let out;
  try {
    out = execFileSync("git", ["status", "--porcelain=v2", "--branch"], {
      cwd,
      encoding: "utf8",
      timeout: 1000,
      stdio: ["ignore", "pipe", "ignore"],
      windowsHide: true,
    });
  } catch {
    return null; // not a repo, or git unavailable
  }

  let branch = null;
  let ahead = 0;
  let behind = 0;
  let dirty = false;

  for (const line of out.split("\n")) {
    if (line.startsWith("# branch.head ")) {
      branch = line.slice("# branch.head ".length).trim();
    } else if (line.startsWith("# branch.ab ")) {
      const m = line.match(/\+(\d+)\s+-(\d+)/);
      if (m) {
        ahead = Number(m[1]);
        behind = Number(m[2]);
      }
    } else if (/^[12u?]\s/.test(line)) {
      dirty = true; // changed, renamed, unmerged, or untracked file
    }
  }

  if (!branch) return null;
  if (branch === "(detached)") branch = "detached";
  return { branch, ahead, behind, dirty };
}

function gitSegment(cwd) {
  const git = gitInfo(cwd);
  if (!git) return null;

  const color = git.dirty ? YELLOW : GREEN;
  let text = git.branch;
  if (git.dirty) text += "*";

  let counts = "";
  if (git.ahead) counts += ` ↑${git.ahead}`;
  if (git.behind) counts += ` ↓${git.behind}`;

  return paint(color, text) + (counts ? paint(GRAY, counts) : "");
}

function contextSegment(d) {
  const cw = d.context_window;
  if (!cw || cw.used_percentage == null) return null;

  const pct = Math.round(cw.used_percentage);
  const color = usageColor(pct);

  let text = `${paint(color, bar(pct, CONFIG.barWidth))} ${paint(color, `${pct}%`)}`;

  if (CONFIG.showTokens && cw.context_window_size) {
    const size = cw.context_window_size;
    const used = Math.round((pct / 100) * size);
    text += paint(GRAY, ` (${shortTokens(used)}/${shortTokens(size)})`);
  }
  return text;
}

/**
 * Reset time for a rate limit window. Windows less than a day out show a bare
 * clock time; further out (the 7-day limit) they get a weekday, since "3:00"
 * alone would be ambiguous.
 */
function formatReset(epochSeconds) {
  const when = new Date(epochSeconds * 1000);
  const time = when.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  const hoursAway = (when.getTime() - Date.now()) / 3_600_000;
  if (hoursAway > 20) {
    return `${when.toLocaleDateString([], { weekday: "short" })} ${time}`;
  }
  return time;
}

/** One limit, e.g. "5h 22%" or, when high, "7d 88% → Tue 3:00 PM". */
function limitPart(label, limit) {
  const pct = limit?.used_percentage;
  if (pct == null || pct < CONFIG.rateLimitThreshold) return null;

  const rounded = Math.round(pct);
  let part = paint(GRAY, `${label} `) + paint(usageColor(rounded), `${rounded}%`);

  if (rounded >= CONFIG.rateLimitResetAt && limit.resets_at) {
    part += paint(GRAY, ` → ${formatReset(limit.resets_at)}`);
  }
  return part;
}

function rateLimitsSegment(d) {
  const parts = [
    limitPart("5h", d.rate_limits?.five_hour),
    limitPart("7d", d.rate_limits?.seven_day),
  ].filter(Boolean);

  return parts.length ? parts.join(paint(GRAY, " · ")) : null;
}

// --- render ----------------------------------------------------------------

function render(d) {
  const cwd = d.workspace?.current_dir || d.cwd;

  // Identity: model, effort, session name, directory.
  const identity = [];
  const model = d.model?.display_name || d.model?.id;
  if (model) identity.push(paint(BOLD + MAGENTA, model));
  if (CONFIG.showEffort && d.effort?.level) identity.push(paint(GRAY, d.effort.level));
  if (CONFIG.showSessionName && d.session_name) identity.push(paint(CYAN, d.session_name));
  if (cwd) identity.push(paint(BLUE, prettyDir(cwd)));

  // Where: git branch and state.
  const where = [];
  if (CONFIG.showGit && cwd) {
    const git = gitSegment(cwd);
    if (git) where.push(git);
  }

  // Usage: context, lines changed, subscription limits, cost.
  const usage = [];
  if (CONFIG.showContext) {
    const ctx = contextSegment(d);
    if (ctx) usage.push(ctx);
  }
  if (CONFIG.showLines) {
    const added = d.cost?.total_lines_added || 0;
    const removed = d.cost?.total_lines_removed || 0;
    if (added || removed) {
      usage.push(paint(GREEN, `+${added}`) + paint(GRAY, "/") + paint(RED, `-${removed}`));
    }
  }
  if (CONFIG.showRateLimits) {
    const limits = rateLimitsSegment(d);
    if (limits) usage.push(limits);
  }
  if (CONFIG.showCost && d.cost?.total_cost_usd != null) {
    usage.push(paint(GRAY, `$${d.cost.total_cost_usd.toFixed(2)}`));
  }

  if (CONFIG.multiline) {
    const top = [...identity, ...where].join(SEP);
    const bottom = usage.join(SEP);
    return [top, bottom].filter(Boolean).join("\n");
  }
  return [...identity, ...where, ...usage].filter(Boolean).join(SEP);
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => (raw += chunk));
process.stdin.on("end", () => {
  try {
    const line = render(JSON.parse(raw));
    if (line) process.stdout.write(line + "\n");
  } catch {
    // Never let a broken status line break the session.
    process.exit(0);
  }
});
