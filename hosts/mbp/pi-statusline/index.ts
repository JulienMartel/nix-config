/**
 * haus-statusline — the agent-worktree HUD as a pi custom footer.
 *
 * The same bar Claude Code draws through haus's statusline.sh, ported to pi's
 * extension API (ctx.ui.setFooter — "Pattern 6: Custom Footer" in pi's TUI
 * docs). Where Claude Code needed two byte-length-preserving binary patches
 * (declutter-claude-footer.py to collapse the stock footer, and
 * statusline-permission-mode.py to complete the payload), pi lets an extension
 * REPLACE the footer outright and hands it live state — so this file is the
 * whole feature, no patch, and it hot-reloads with `/reload`.
 *
 * Row 1  : THIS session's git-status token as the leading glyph (⏏/N^/+A -D,
 *          or a muted ● when clean) + its own PR number (left of the name,
 *          colored by PR state, OSC 8-linked to the PR) + worktree name — then
 *          flush right: the child-PR cluster (clickable numbers for every
 *          worktree this session spawned — a LADDER: closed/merged links drop
 *          first, then it collapses to a bare count, never all-or-nothing, so
 *          a tight row can't lose the PR links while row 2+ is clipped away)
 *          · rice-nag (⇡N — commits the pinned haus is behind) · ctx% (green
 *          <100k tokens, yellow <200k, red beyond — banded on absolute tokens,
 *          not the percentage) · turn stamp (⇱start · elapsed — the one time
 *          signal calm leaves visible; ticks while the turn runs, frozen at
 *          its real duration after) · cost · thinking level (blank when off —
 *          pi's analog of the slot the permission-mode icon fills on Claude
 *          Code; pi has no permission modes) · provider/model chip. The model
 *          is not just a CC tier any more — pi routes anything through
 *          openrouter & co — so the chip reads as slang: `or/qwen3`, `ds-chat`;
 *          the big-name tiers keep their bare letters (O5/S45/H45/F5, F5/M5
 *          tinted) and gain a provider tag (`or/S45`) only when NOT on their
 *          home provider.
 * Trunc:  smart truncation, never a mid-chip hard cut. Every right-side chip
 *          carries a slang ladder (high→hi, $1.23→$1.2→$1,
 *          or/qwen3-coder-plus→or/qwen3→or/qw3) and a drop priority; the row
 *          is fitted most-important-first (ctx% > model > cost > child cluster
 *          + turn > thinking > ⇡nag), so the FIRST thing to disappear is
 *          always the LEAST important chip and survivors shrink instead of
 *          vanishing. Row 2+ drops the repo label before it clips a worktree
 *          name, and a name clips only after every chip has had its chance.
 *          NB pi's layout may also shrink the FOOTER ITSELF vertically (its
 *          container carries shrink: 1 / minSize: 1) — the ladder is what
 *          keeps the child links legible down to that one-line floor.
 * Tint   : on Fable/Mythos only, every row gets the same dark amber background
 *          statusline.sh paints, edge-to-edge, so the special model reads from
 *          across a wall of panes.
 * Row 2+ : the worktrees THIS session spawned (panel parent == cwd), each with
 *          status-as-bullet, repo, PR pill and name; reapable ⏏ rows last, cap
 *          MAX_ROWS with a "+N more" line. In the $HOME pane only, orphan
 *          worktrees (no recorded parent) surface with a ◇ mark.
 * Extra  : other extensions' ctx.ui.setStatus() texts get one dim row at the
 *          bottom — replacing pi's footer must not eat their only surface.
 *
 * Shared plumbing, not duplicated: the cross-repo + gh enumeration stays in
 * haus's DETACHED statusline-refresh.sh and its caches under
 * ~/.cache/claude-statusline (panel.tsv, lock-nag.tsv) — this footer reads the
 * same files the Claude Code statusline reads and kicks the same refresher when
 * they go stale, honoring the same GitHub-bridge TTL stretch
 * (~/.local/state/haus/github/last vs the panel's mtime, HAUS_GH_BACKSTOP).
 * One HUD, two renderers; a CC pane and a pi pane beside it show the same
 * numbers at the same moment. The 256-colour palette is statusline.sh's,
 * verbatim, for the same reason.
 *
 * Deliberately NOT ported, because each is Claude Code-specific:
 *  - the permission-mode chip (pi has no shift+tab modes; the slot carries
 *    pi's thinking level instead, blank at "off" per the blank-is-baseline
 *    rule),
 *  - the rate-limit harvest into usage.tsv (pi talks to meridian's loopback
 *    proxy and never sees the OAuth usage payload; CC panes keep feeding the
 *    bar pill),
 *  - the pane-transcripts.tsv join (its consumers — pounce Links, ⌘F find —
 *    read Claude Code transcripts).
 *
 * Installed by hosts/mbp/default.nix as an out-of-store symlink at
 * ~/.pi/agent/extensions/haus-statusline, pi's global auto-discovery dir —
 * which is what makes it permanent, and editing this file live in the next
 * pane (or `/reload` in a running one). `/statusline` toggles it off/on in a
 * session.
 */

import { execFile, spawn } from "node:child_process";
import { existsSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

// ---- palette: statusline.sh's, verbatim (256-colour + one truecolor tint) ---
const c = (n: number) => `\x1b[38;5;${n}m`;
const DOT = c(108);
const DIM = c(244);
const BOLD = "\x1b[1m";
const AHEAD = c(75);
const ADD = c(71);
const DEL = c(167);
const PURGE = c(173);
const WARN = c(179);
const PR_OPEN = c(71);
const PR_MERGED = c(139);
const PR_CLOSED = c(167);
const MAGENTA = "\x1b[35m"; // ANSI slot 5, themed by the terminal (nebelung: pink)
const R0 = "\x1b[0m";
const TINT_FABLE = "\x1b[48;2;56;39;19m";

const HOME = homedir();
const CACHE_DIR = process.env.CLAUDE_STATUSLINE_CACHE ?? join(HOME, ".cache", "claude-statusline");
const PANEL = join(CACHE_DIR, "panel.tsv");
const PANEL_COVERED = join(CACHE_DIR, ".panel-covered");
const NAG = join(CACHE_DIR, "lock-nag.tsv");
const TTL_MS = 15_000; // statusline.sh's TTL=15
const MAX_ROWS = 8;
const NAG_ALERT_DAYS = 14;
const GIT_REFRESH_MS = 5_000; // min gap between local-git re-reads
const IDLE_TICK_MS = 10_000; // repaint cadence while nothing renders on its own

// The same PATH prefix statusline.sh arms itself with: pi may have been
// spawned off a PATH without the system profile, and the refresher lives there.
const SPAWN_PATH = [
	"/run/current-system/sw/bin",
	"/nix/var/nix/profiles/default/bin",
	"/opt/homebrew/bin",
	"/usr/bin",
	"/bin",
	process.env.PATH ?? "",
].join(":");

function osc8(url: string, text: string): string {
	return `\x1b]8;;${url}\x1b\\${text}\x1b]8;;\x1b\\`;
}

function mtimeMs(p: string): number {
	try {
		return statSync(p).mtimeMs;
	} catch {
		return 0;
	}
}

function readTsv(p: string): string[][] {
	try {
		return readFileSync(p, "utf8")
			.split("\n")
			.filter((l) => l.length > 0)
			.map((l) => l.split("\t"));
	} catch {
		return [];
	}
}

function git(cwd: string, ...args: string[]): Promise<{ ok: boolean; out: string }> {
	return new Promise((resolve) => {
		execFile(
			"git",
			["--no-optional-locks", ...args],
			{ cwd, encoding: "utf8", env: { ...process.env, PATH: SPAWN_PATH } },
			(err, stdout) => resolve({ ok: !err, out: stdout ?? "" }),
		);
	});
}

// ---- the GitHub bridge, where there is one (port of signal.sh's consumer) ---
// Sourcing bash is not an option here, so the two facts the render path needs
// are read directly: coverage stretches the panel TTL to HAUS_GH_BACKSTOP, and
// a delivery newer than the panel cancels the stretch (back to TTL, never
// below it — same rule as statusline.sh).
const SIGNAL_SH = join(HOME, ".config", "haus", "github", "signal.sh");
const GH_STATE = process.env.HAUS_GH_STATE ?? join(HOME, ".local", "state", "haus", "github");

function ghBackstopMs(): number {
	const env = process.env.HAUS_GH_BACKSTOP;
	if (env !== undefined) {
		const n = Number.parseInt(env, 10);
		return Number.isFinite(n) && n > 0 ? n * 1000 : 0;
	}
	if (!existsSync(SIGNAL_SH)) return 0;
	try {
		const conf = readFileSync(join(HOME, ".config", "haus", "github", "config.sh"), "utf8");
		const m = /^HAUS_GH_BACKSTOP=["']?(\d+)/m.exec(conf);
		if (m) return Number.parseInt(m[1]!, 10) * 1000;
	} catch {
		/* no config.sh — signal.sh's own default applies */
	}
	return 300_000;
}

function ghFreshSince(atMs: number): boolean {
	if (!existsSync(SIGNAL_SH) || atMs <= 0) return false;
	return mtimeMs(join(GH_STATE, "last")) > atMs;
}

// ---- render_status / render_pr, ported -------------------------------------
function renderStatus(
	ahead: number,
	files: number,
	ins: number,
	del: number,
	pr: string,
	purge: boolean,
	R: string,
): string {
	const state = pr ? (pr.split(" ").pop() ?? "") : "";
	let relanded = "";
	const m = /^merged\+(.+)$/.exec(state);
	if (m) relanded = m[1]!;
	const done = purge || state === "merged";
	if (purge) relanded = "";
	if (relanded) return `${PURGE}${relanded}^${R}`;
	if (done) return `${PURGE}⏏${R}`;
	if (ahead > 0) return `${AHEAD}${ahead}^${R}`;
	if (files > 0) {
		let st = "";
		if (ins > 0) st = `${ADD}+${ins}${R}`;
		if (del > 0) st = (st ? `${st} ` : "") + `${DEL}-${del}${R}`;
		return st;
	}
	return "";
}

function renderPr(pr: string, url: string, R: string): string {
	if (!pr) return "";
	const state = pr.split(" ").pop() ?? "";
	const num = pr.split(" ")[0] ?? "";
	let col = DIM;
	if (state === "open") col = PR_OPEN;
	else if (state.startsWith("merged")) col = PR_MERGED;
	else if (state === "closed") col = PR_CLOSED;
	const text = `${col}${num}${R}`;
	return url ? osc8(url, text) : text;
}

// ---- local git facts (async, cached — render() itself never forks) ----------
interface GitState {
	branch: string;
	isWt: boolean;
	wtName: string;
	slug: string;
	ahead: number;
	files: number;
	ins: number;
	del: number;
	purge: boolean;
}

async function readGitState(cwd: string): Promise<GitState> {
	const st: GitState = {
		branch: "",
		isWt: false,
		wtName: "",
		slug: "",
		ahead: 0,
		files: 0,
		ins: 0,
		del: 0,
		purge: false,
	};
	st.branch = (await git(cwd, "branch", "--show-current")).out.trim();
	if (st.branch.startsWith("worktree-")) {
		st.isWt = true;
		st.wtName = st.branch.slice("worktree-".length);
	}
	let def = (await git(cwd, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")).out
		.trim()
		.replace(/^origin\//, "");
	if (!def) {
		for (const b of ["main", "master"]) {
			if ((await git(cwd, "show-ref", "-q", "--verify", `refs/heads/${b}`)).ok) {
				def = b;
				break;
			}
		}
	}
	if (!def) def = "main";

	const status = (await git(cwd, "status", "--porcelain")).out;
	st.files = status.split("\n").filter((l) => l.length > 0).length;
	const ahead = (await git(cwd, "rev-list", "--count", `${def}..HEAD`)).out.trim();
	st.ahead = /^\d+$/.test(ahead) ? Number.parseInt(ahead, 10) : 0;
	if (st.files > 0) {
		const shortstat = (await git(cwd, "diff", "HEAD", "--shortstat")).out;
		st.ins = Number.parseInt(/(\d+) insertion/.exec(shortstat)?.[1] ?? "0", 10);
		st.del = Number.parseInt(/(\d+) deletion/.exec(shortstat)?.[1] ?? "0", 10);
	}

	if (st.isWt && st.files === 0 && (await git(cwd, "merge-base", "--is-ancestor", "HEAD", def)).ok) {
		st.purge = true;
		// …unless the branch never DIVERGED — same never-diverged reflog rule as
		// statusline.sh (inverted test: nothing but "branch: Created from" may
		// appear; an EMPTY reflog proves nothing and keeps the ⏏).
		if (st.ahead === 0 && st.branch) {
			const reflog = (await git(cwd, "reflog", "show", "--format=%gs", st.branch)).out;
			const lines = reflog.split("\n").filter((l) => l.length > 0);
			if (lines.length > 0 && lines.every((l) => l.startsWith("branch: Created from "))) {
				st.purge = false;
			}
		}
	}

	// slug: remote-derived owner/name, same parse as statusline.sh/the refresher
	let url = (await git(cwd, "remote", "get-url", "origin")).out.trim();
	if (url) {
		url = url.replace(/\.git$/, "");
		url = url.replace(/^[a-z+]+:\/\//i, "");
		const at = url.indexOf("@");
		if (at !== -1) url = url.slice(at + 1);
		st.slug = url.replace(/^[^/:]*[:/]/, "");
	}
	return st;
}

// ---- panel + refresher ------------------------------------------------------
interface PanelRow {
	slug: string;
	name: string;
	ahead: number;
	files: number;
	ins: number;
	del: number;
	pr: string; // "#N state" or "" (the "-" sentinel is decoded here)
	parent: string;
}

function readPanel(): PanelRow[] {
	return readTsv(PANEL).map((f) => ({
		slug: f[0] ?? "",
		name: f[1] ?? "",
		ahead: Number.parseInt(f[2] ?? "0", 10) || 0,
		files: Number.parseInt(f[3] ?? "0", 10) || 0,
		ins: Number.parseInt(f[4] ?? "0", 10) || 0,
		del: Number.parseInt(f[5] ?? "0", 10) || 0,
		pr: f[6] === "-" ? "" : (f[6] ?? ""),
		parent: f[7] ?? "",
	}));
}

// panel.tsv is stable in registry order. Preserve that order within each
// group, but move exact "merged" rows (the ones render_status turns into ⏏)
// behind every active row BEFORE the MAX_ROWS cap — same as ordered_panel().
function orderedPanel(rows: PanelRow[]): PanelRow[] {
	const active: PanelRow[] = [];
	const reapable: PanelRow[] = [];
	for (const r of rows) (/ merged$/.test(r.pr) ? reapable : active).push(r);
	return [...active, ...reapable];
}

function which(cmd: string): string | null {
	for (const dir of SPAWN_PATH.split(":")) {
		if (!dir) continue;
		const p = join(dir, cmd);
		try {
			if (statSync(p).isFile()) return p;
		} catch {
			/* keep looking */
		}
	}
	return null;
}

let lastKickAt = 0;
function kickRefresherIfStale(): void {
	const panelAt = mtimeMs(PANEL);
	if (panelAt > 0) {
		let ttl = TTL_MS;
		const backstop = ghBackstopMs();
		if (existsSync(PANEL_COVERED) && backstop > ttl) ttl = backstop;
		if (ghFreshSince(panelAt)) ttl = TTL_MS;
		if (Date.now() - panelAt < ttl) return;
	}
	if (Date.now() - lastKickAt < TTL_MS) return; // one kick per TTL, not per render
	const refresher =
		process.env.CLAUDE_STATUSLINE_REFRESHER ??
		which("claude-statusline-refresh") ??
		join(HOME, ".claude", "statusline-refresh.sh");
	if (!existsSync(refresher)) return;
	lastKickAt = Date.now();
	try {
		spawn(refresher, [], {
			detached: true,
			stdio: "ignore",
			env: { ...process.env, PATH: SPAWN_PATH },
		}).unref();
	} catch {
		/* a missing/broken refresher must never take the footer down */
	}
}

// ---- chips ------------------------------------------------------------------
// Slang abbreviation for the provider half of the model chip. pi routes
// through anything (openrouter, vercel-ai-gateway, moonshotai-cn, …), so
// unknown providers fall back to a de-hyphenated two-letter stub.
const PROVIDER_ABBR: Record<string, string> = {
	anthropic: "an",
	openai: "oa",
	"openai-codex": "ox",
	google: "gg",
	"google-vertex": "gv",
	openrouter: "or",
	xai: "x",
	groq: "gq",
	mistral: "ms",
	deepseek: "ds",
	together: "tg",
	ollama: "ol",
	"github-copilot": "cp",
	"amazon-bedrock": "br",
	cerebras: "cb",
	"azure-openai-responses": "az",
	zai: "z",
	minimax: "mm",
	moonshotai: "mo",
	huggingface: "hf",
	fireworks: "fw",
	baseten: "bt",
	"kimi-coding": "kc",
	"vercel-ai-gateway": "vg",
	"cloudflare-workers-ai": "cf",
	"cloudflare-ai-gateway": "cg",
	opencode: "oc",
	radius: "rd",
	nvidia: "nv",
	"ant-ling": "al",
};

function providerAbbr(provider: string): string {
	const known = PROVIDER_ABBR[provider];
	if (known) return known;
	return provider.split("-")[0]?.slice(0, 2) || provider.slice(0, 2);
}

// Thinking levels read as slang when the row is tight.
const THINK_SLIM: Record<string, string> = {
	minimal: "min",
	low: "lo",
	medium: "med",
	high: "hi",
	xhigh: "xhi",
	max: "mx",
};

interface ChipLevels {
	levels: string[]; // longest → shortest
	tint: boolean;
}

// The provider/model chip. Known tiers keep their bare letters (O5/S45/H45,
// F5/M5 tinted); anything else — openrouter's whole catalogue included —
// renders as provider-abbr/model-slang: or/qwen3, oa/gpt5.6, ds-chat.
function modelChip(model: { id?: string; provider?: string } | undefined, R: string): ChipLevels {
	const id = model?.id;
	if (!id) return { levels: [], tint: false };
	let letter = "";
	let color = DIM;
	let tint = false;
	let homeProvider = "";
	if (id.includes("fable")) [letter, color, tint] = ["F", MAGENTA, true];
	else if (id.includes("mythos")) [letter, color, tint] = ["M", MAGENTA, true];
	else if (id.includes("opus")) [letter, homeProvider] = ["O", "anthropic"];
	else if (id.includes("sonnet")) [letter, homeProvider] = ["S", "anthropic"];
	else if (id.includes("haiku")) [letter, homeProvider] = ["H", "anthropic"];
	if (letter) {
		// {1,2} + the trailing non-digit/end anchor keeps a DATE suffix from
		// being read as a version (claude-3-5-sonnet-20241022 → bare "S"), same
		// as the bash =~ in statusline.sh.
		const m = /(?:fable|mythos|opus|sonnet|haiku)-(\d{1,2})(?:-(\d{1,2}))?(?:[^0-9]|$)/.exec(id);
		const ver = m ? (m[1] ?? "") + (m[2] ?? "") : "";
		const core = `${color}${letter}${ver}${R}`;
		// Provider tag only when the tier is NOT on its home provider;
		// fable/mythos are always home — the tint already says who they are.
		const away = homeProvider !== "" && model?.provider !== homeProvider;
		return {
			tint,
			levels: away && model?.provider ? [`${DIM}${providerAbbr(model.provider)}${R}${core}`] : [core],
		};
	}

	// Generic model: last path segment with date suffixes and ":free"-style
	// tags stripped, then a slang ladder — full seg → name+version → stub.
	const provider = model?.provider ?? "";
	const abbr = provider ? `${DIM}${providerAbbr(provider)}${R}` : "";
	let seg = (id.split("/").pop() ?? id).replace(/[-_]?(\d{8}|\d{4}-\d{2}-\d{2})$/, "");
	seg = seg.replace(/[:.](free|latest|preview|hf|dev|test)$/i, "");
	const tokens = seg.split(/[-_.]/).filter(Boolean);
	// openrouter glues the version onto the name ("qwen3-coder-plus" → the
	// token is "qwen3", not "qwen"+"3") — peel a trailing version off it.
	const glue = /^([a-z]+)(\d+(\.\d+)*)$/i.exec(tokens[0] ?? "");
	if (glue?.[1] && glue[2]) {
		tokens[0] = glue[1];
		tokens.splice(1, 0, glue[2]);
	}
	// "v3.1"-style prefixes are versions too; keep the digits, join with dots.
	const ver = tokens
		.filter((t) => /^v?\d+(\.\d+)*$/i.test(t))
		.map((t) => t.replace(/^v/i, ""))
		.join(".");
	const name = tokens.find((t) => /^[a-z]/i.test(t)) ?? "";
	const wrap = (s: string) => (abbr ? `${abbr}/${s}${R}` : `${s}${R}`);
	const levels: string[] = [];
	if (name && seg.length <= 9) levels.push(wrap(seg));
	if (name) levels.push(wrap(`${name.slice(0, 5)}${ver}`));
	if (name) levels.push(wrap(`${name.slice(0, 2)}${ver}`));
	return { levels: levels.length > 0 ? [...new Set(levels)] : seg ? [wrap(seg)] : [], tint: false };
}

// ---- smart truncation -------------------------------------------------------
// One rule everywhere: the least important thing disappears first, and what
// stays is shortened through a slang ladder rather than hard-cut. Each chip
// offers levels longest → shortest plus a drop priority (LOWER drops FIRST);
// fitTail walks most-important-first so important chips claim width first.
interface TailPart {
	order: number; // display order within the row
	drop: number; // lower = dropped earlier
	levels: string[]; // longest → shortest
}

function fitTail(parts: TailPart[], budget: number): string {
	const used: Array<{ order: number; text: string }> = [];
	let left = budget;
	for (const p of [...parts].sort((a, b) => b.drop - a.drop)) {
		const pick = p.levels.find((lv) => visibleWidth(lv) <= left);
		if (pick === undefined) continue;
		used.push({ order: p.order, text: pick });
		left -= visibleWidth(pick) + 1; // one space of separator reserved
	}
	used.sort((a, b) => a.order - b.order);
	// The cluster leads, held off the chips by two spaces so a run of bare
	// numbers can't be misread as part of "⇡3 42% $1.23 or/qw3".
	const segs = used.map((u) => u.text);
	const head = segs[0];
	return segs.length > 1 && used[0]?.order === 0 && head !== undefined
		? `${head}  ${segs.slice(1).join(" ")}`
		: segs.join(" ");
}

// A name is clipped only at the very end, ellipsis'd, never mid-chip.
function clipName(name: string, budget: number): string {
	if (budget <= 1) return [...name].slice(0, Math.max(0, budget)).join("");
	return `${[...name].slice(0, budget - 1).join("")}…`;
}

function renderNag(R: string): string {
	const rows = readTsv(NAG);
	if (rows.length === 0) return "";
	const behind = Number.parseInt(rows[0]?.[0] ?? "", 10) || 0;
	const lockdate = Number.parseInt(rows[0]?.[1] ?? "", 10) || 0;
	const url = rows[0]?.[2] ?? "";
	if (behind <= 0) return "";
	let col = WARN;
	if (lockdate > 0 && (Date.now() / 1000 - lockdate) / 86400 >= NAG_ALERT_DAYS) col = DEL;
	const text = `${col}⇡${behind}${R}`;
	return url ? osc8(url, text) : text;
}

// ---- the footer component ---------------------------------------------------
interface TuiLike {
	requestRender(): void;
}

interface FooterDataLike {
	getExtensionStatuses(): ReadonlyMap<string, string>;
	onBranchChange(cb: () => void): () => void;
}

class HausFooter {
	private ctx: ExtensionContext;
	private tui: TuiLike;
	private footerData: FooterDataLike;
	private gitState: GitState | null = null;
	private gitStateKey = "";
	private lastGitRefresh = 0;
	private refreshing = false;
	private lastPanelMtime = -1;
	private timer: ReturnType<typeof setInterval>;
	private unsubBranch: () => void;
	private disposed = false;

	constructor(tui: TuiLike, ctx: ExtensionContext, footerData: FooterDataLike) {
		this.tui = tui;
		this.ctx = ctx;
		this.footerData = footerData;
		this.unsubBranch = footerData.onBranchChange(() => void this.refresh(true));
		// The idle repaint: statusline.sh leaned on Claude Code's
		// refreshInterval to notice a child's PR merging while the pane sat
		// still; pi renders only on activity, so the interval is ours. It is
		// also what keeps the turn chip's elapsed time honest while calm hides
		// a silent tool run: a live turn gets a repaint even when nothing else
		// changed (the render itself stays cheap; refresh() re-reads git at most
		// every GIT_REFRESH_MS and the footer paints from cache).
		this.timer = setInterval(() => {
			if (this.liveTurn() && !this.disposed) this.tui.requestRender();
			void this.refresh(false);
		}, IDLE_TICK_MS);
		this.timer.unref?.();
		void this.refresh(true);
	}

	dispose = (): void => {
		this.disposed = true;
		clearInterval(this.timer);
		this.unsubBranch();
	};

	invalidate(): void {}

	// A turn is live when the newest message in the session is the user's —
	// anything the model or a tool has produced since means the turn ended.
	// Non-message entries (compaction, branch summaries) are skipped, same as
	// the turn chip's walk.
	private liveTurn(): boolean {
		const entries = this.ctx.sessionManager.getEntries();
		for (let i = entries.length - 1; i >= 0; i--) {
			const e = entries[i]!;
			if (e.type !== "message") continue;
			return e.message.role === "user";
		}
		return false;
	}

	private async refresh(force: boolean): Promise<void> {
		if (this.disposed || this.refreshing) return;
		if (!force && Date.now() - this.lastGitRefresh < GIT_REFRESH_MS) return;
		this.refreshing = true;
		try {
			const next = await readGitState(this.ctx.cwd);
			this.lastGitRefresh = Date.now();
			kickRefresherIfStale();
			const key = JSON.stringify(next);
			const panelAt = mtimeMs(PANEL);
			const changed = key !== this.gitStateKey || panelAt !== this.lastPanelMtime;
			this.gitState = next;
			this.gitStateKey = key;
			this.lastPanelMtime = panelAt;
			if (changed && !this.disposed) this.tui.requestRender();
		} catch {
			/* a git hiccup keeps the last state on screen */
		} finally {
			this.refreshing = false;
		}
	}

	render(width: number): string[] {
		try {
			return this.renderInner(width);
		} catch {
			// Never let a render bug blank the pane's one HUD.
			return [`${DIM}${basename(this.ctx.cwd)}${R0}`];
		}
	}

	private renderInner(width: number): string[] {
		void this.refresh(false); // schedule; this render uses the cache
		const st = this.gitState;
		const cwd = this.ctx.cwd;
		const isHome = cwd === HOME;
		const panel = orderedPanel(readPanel());

		// Fable/Mythos tint: re-arm the background after every in-row reset so
		// $R means "back to row context"; R0 stays the real reset at line end.
		// The chip is built against the \x1b[39m placeholder because R needs the
		// tint decision first; the placeholder is swapped for R per level after.
		const chip = modelChip(this.ctx.model, "\x1b[39m");
		const BG = chip.tint ? TINT_FABLE : "";
		const R = BG ? `${R0}${BG}` : R0;
		const MODEL_LEVELS = chip.levels.map((lv) => lv.replaceAll("\x1b[39m", R));

		const emit = (row: string): string => {
			if (!BG) return truncateToWidth(row, width);
			const pad = Math.max(0, width - visibleWidth(row));
			return truncateToWidth(`${BG}${row}${" ".repeat(pad)}${R0}`, width);
		};

		// --- row 1: status bullet + own PR pill + name --------------------------
		let ownPr = "";
		if (st?.isWt && st.slug) {
			ownPr = panel.find((r) => r.slug === st.slug && r.name === st.wtName)?.pr ?? "";
		}
		const lead = st
			? renderStatus(st.ahead, st.files, st.ins, st.del, ownPr, st.purge, R) || `${DOT}●${R}`
			: `${DOT}●${R}`;
		const prnum = ownPr.split(" ")[0] ?? "";
		const ownUrl = ownPr && st?.slug ? `https://github.com/${st.slug}/pull/${prnum.replace(/^#/, "")}` : "";
		const prseg = renderPr(ownPr, ownUrl, R);
		// The name clips LAST — only when row 1 alone cannot fit the width.
		const name = st?.isWt ? st.wtName : (st?.branch || basename(cwd));
		const nameCol = st?.branch ? BOLD : DIM; // non-worktree cwd keeps the dim dir name
		const prefix = `${lead} ${prseg ? `${prseg} ` : ""}${nameCol}`;
		const nameBudget = width - visibleWidth(prefix) - 1;
		const dispName = visibleWidth(name) <= nameBudget ? name : clipName(name, Math.max(1, nameBudget));
		let row1 = `${prefix}${dispName}${R}`;

		// --- tail group: child-PR cluster · ⇡nag · ctx% · turn · cost · thinking · model
		// sibling: a panel row in THIS lane's own repo is a ⌘↵ peer with a pane of
		// its own, not a child of mine — the rule statusline.sh renders by (haus
		// #602), which this port predates. Only inside a lane: a main-checkout pane
		// keeps every row it parents. Collected as records rather than a painted
		// string so the cluster chip below can ladder (shrink) instead of vanishing.
		const isWt = st?.isWt ?? false;
		const isSibling = (slug: string): boolean =>
			isWt && st?.slug !== undefined && st.slug !== "" && slug === st.slug;
		const clusterLinks: Array<{ num: string; col: string; state: string; url: string }> = [];
		for (const r of panel) {
			if (!r.name || r.parent !== cwd || !r.pr) continue;
			if (isSibling(r.slug)) continue;
			const num = (r.pr.split(" ")[0] ?? "").replace(/^#/, "");
			const state = r.pr.split(" ").pop() ?? "";
			let col = DIM;
			if (state === "open") col = PR_OPEN;
			else if (state.startsWith("merged")) col = PR_MERGED;
			else if (state === "closed") col = PR_CLOSED;
			clusterLinks.push({ num, col, state, url: `https://github.com/${r.slug}/pull/${num}` });
		}

		// Smart truncation: chips are fitted most-important-first, each takes
		// the longest slang level that still fits, and only then may it drop —
		// so the least important chip is always the first thing to disappear.
		const tail: TailPart[] = [];
		const nag = renderNag(R);
		if (nag) tail.push({ order: 1, drop: 0, levels: [nag] }); // the nag is a nudge: first to go
		// ctx%: banded on ABSOLUTE tokens (green <100k, yellow <200k, red past),
		// never on the percentage — same mixed-fleet reasoning as statusline.sh.
		// Unknown tokens (right after compaction) fall back to the dim gray.
		const usage = this.ctx.getContextUsage();
		if (usage && usage.percent !== null) {
			let CTX = DIM;
			if (usage.tokens !== null) {
				if (usage.tokens >= 200_000) CTX = DEL;
				else if (usage.tokens >= 100_000) CTX = WARN;
				else CTX = ADD;
			}
			tail.push({ order: 2, drop: 5, levels: [`${CTX}${Math.round(usage.percent)}%${R}`] }); // last chip standing
		}
		// --- the turn stamp: when this task started, and how long it has run ---
		// pi-calm hides every tool shell, so the chat itself carries no time — the
		// user asked for a timestamp on each task they can see, and the footer is
		// the one haus-owned surface calm can't hide. The chip carries the current
		// turn's start (HH:MM) and elapsed time: ticking while the turn runs, and
		// frozen at the turn's real duration once the assistant answers. The ladder
		// gives up the elapsed half before the start time.
		{
			const entries = this.ctx.sessionManager.getEntries();
			let userAt: number | null = null;
			let lastAt: number | null = null;
			for (let i = entries.length - 1; i >= 0; i--) {
				const e = entries[i]!;
				if (e.type !== "message") continue;
				const t = Date.parse(e.timestamp);
				if (!Number.isFinite(t)) continue;
				if (e.message.role === "user") {
					userAt = t;
					break;
				}
				if (lastAt === null) lastAt = t;
			}
			if (userAt !== null) {
				const end = lastAt ?? Date.now();
				const hhmm = new Date(userAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false });
				const run = Math.max(0, end - userAt);
				const pad = (n: number, w = 2) => String(n).padStart(w, "0");
				const elapsed =
					run >= 3_600_000
						? `${Math.floor(run / 3_600_000)}:${pad(Math.floor((run % 3_600_000) / 60_000))}:${pad(Math.floor((run % 60_000) / 1000))}`
						: `${Math.floor(run / 60_000)}:${pad(Math.floor((run % 60_000) / 1000))}`;
				tail.push({
					order: 3,
					drop: 3,
					levels: [`${DIM}⇱${hhmm} · ${elapsed}${R}`, `${DIM}⇱${hhmm}${R}`],
				});
			}
		}
		let cost = 0;
		// Every branch guards `usage` — an assistant entry without it (an aborted
		// or still-streaming message) must cost this loop its zeros, not the whole
		// footer: render()'s catch would collapse the HUD to one dim line, which is
		// how a pane can lose children and PR links entirely for the rest of the
		// session. Measured: one usage-less entry threw here and the footer never
		// recovered (the turn chip's data stayed fine, the bar didn't).
		for (const e of this.ctx.sessionManager.getEntries()) {
			if (e.type === "message" && e.message.role === "assistant" && e.message.usage?.cost) {
				cost += e.message.usage.cost.total;
			} else if (e.type === "message" && e.message.role === "toolResult" && e.message.usage?.cost) {
				cost += e.message.usage.cost.total;
			} else if ((e.type === "branch_summary" || e.type === "compaction") && e.usage?.cost) {
				cost += e.usage.cost.total;
			}
		}
		if (cost > 0) {
			const money = (s: string) => `${DIM}${s}${R}`;
			tail.push({
				order: 4,
				drop: 2,
				levels: [money(`$${cost.toFixed(2)}`), money(`$${cost.toFixed(1)}`), money(`$${Math.round(cost)}`)],
			});
		}
		const thinking = this.ctx.thinkingLevel;
		if (this.ctx.model?.reasoning && thinking && thinking !== "off") {
			const slang = THINK_SLIM[thinking] ?? thinking;
			tail.push({ order: 5, drop: 1, levels: [`${DIM}${thinking}${R}`, `${DIM}${slang}${R}`] });
		}
		if (MODEL_LEVELS.length > 0) tail.push({ order: 6, drop: 4, levels: MODEL_LEVELS });
		if (clusterLinks.length > 0) {
			// The cluster chip is a LADDER, never all-or-nothing. Row 2+ is the first
			// thing pi's layout clips when the viewport runs short (the footer
			// container sits in the main vstack with shrink: 1 / minSize: 1, so a busy
			// screen shrinks it toward one line — child rows vanish wholesale). Row
			// 1's cluster is the redundancy that survives that, so when the row
			// itself runs out of width the cluster must SHRINK rather than drop:
			// closed/merged links go first, then it collapses to a bare count of
			// open children. A single-level chip here is exactly how a parent pane
			// ended up showing children with no PR link anywhere on the footer.
			const linked = (keep: (s: string) => boolean): string =>
				clusterLinks.filter((l) => keep(l.state)).map((l) => osc8(l.url, `${l.col}${l.num}${R}`)).join(" ");
			const full = linked(() => true);
			const openOnly = linked((s) => s === "open");
			const levels: string[] = [];
			if (full) levels.push(full);
			if (openOnly && openOnly !== full) levels.push(openOnly);
			if (openOnly) levels.push(`${DIM}${clusterLinks.filter((l) => l.state === "open").length}${R}`);
			else levels.push(`${DIM}${clusterLinks.length}${R}`);
			tail.push({ order: 0, drop: 3, levels });
		}
		const tailBudget = width - visibleWidth(row1) - 2;
		const tailseg = tailBudget >= 2 ? fitTail(tail, tailBudget) : "";
		if (tailseg) {
			const pad = width - visibleWidth(row1) - visibleWidth(tailseg);
			row1 = `${row1}${" ".repeat(Math.max(2, pad))}${tailseg}`;
		}

		const lines: string[] = [emit(row1)];

		// --- rows 2+: the worktrees THIS session spawned ------------------------
		let shown = 0;
		let extra = 0;
		for (const r of panel) {
			if (!r.name) continue;
			let orphan = false;
			if (r.parent === cwd) {
				if (isSibling(r.slug)) continue; // a ⌘↵ peer, not a worktree I own
			} else if (isHome && !r.parent) {
				orphan = true; // unattributed — surfaced only at $HOME
			} else {
				continue;
			}
			if (shown >= MAX_ROWS) {
				extra++;
				continue;
			}
			const bullet = renderStatus(r.ahead, r.files, r.ins, r.del, r.pr, false, R) || `${DOT}●${R}`;
			const num = r.pr.split(" ")[0] ?? "";
			const url = r.pr ? `https://github.com/${r.slug}/pull/${num.replace(/^#/, "")}` : "";
			const prpill = renderPr(r.pr, url, R);
			const repo = r.slug.split("/").pop() ?? r.slug;
			const mark = orphan ? `${PURGE}◇${R}` : "";
			// Smart truncation ladder: full row → drop the repo label (the name
			// identifies the worktree; the repo is inferable) → clip the name.
			// The PR pill never goes mid-cut; emit() is the last-resort floor.
			const base = `  ${bullet} ${mark}${prpill ? `${prpill} ` : ""}`;
			const rowWith = (withRepo: boolean, name: string) =>
				`${base}${withRepo ? `${DIM}${repo}${R} ` : ""}${name}`;
			let line = rowWith(true, r.name);
			if (visibleWidth(line) > width) {
				line = rowWith(false, r.name);
				if (visibleWidth(line) > width) {
					line = rowWith(false, clipName(r.name, Math.max(1, width - visibleWidth(base) - 1)));
				}
			}
			lines.push(emit(line));
			shown++;
		}
		if (extra > 0) lines.push(emit(`  ${DIM}+${extra} more${R}`));

		// --- other extensions' setStatus() texts --------------------------------
		const statuses = [...this.footerData.getExtensionStatuses().values()];
		if (statuses.length > 0) {
			lines.push(emit(`${DIM}${statuses.join(" · ")}${R}`));
		}

		return lines;
	}
}

export default function (pi: ExtensionAPI) {
	let enabled = true;

	const install = (ctx: ExtensionContext): void => {
		if (!enabled || ctx.mode !== "tui") return;
		ctx.ui.setFooter((tui, _theme, footerData) => new HausFooter(tui, ctx, footerData));
	};

	pi.on("session_start", (_event, ctx) => install(ctx));

	pi.registerCommand("statusline", {
		description: "Toggle the haus statusline footer (back to pi's default)",
		handler: async (_args, ctx) => {
			enabled = !enabled;
			if (enabled) {
				install(ctx);
				ctx.ui.notify("haus statusline on", "info");
			} else {
				ctx.ui.setFooter(undefined);
				ctx.ui.notify("pi default footer restored", "info");
			}
		},
	});
}
