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
 *          flush right: the child-PR cluster (bare clickable numbers for every
 *          worktree this session spawned) · rice-nag (⇡N — commits the pinned
 *          haus is behind) · ctx% (green <100k tokens, yellow <200k, red
 *          beyond — banded on absolute tokens, not the percentage) · cost ·
 *          thinking level (blank when off — pi's analog of the slot the
 *          permission-mode icon fills on Claude Code; pi has no permission
 *          modes) · model tier chip (O5 / S5 / H45 / F5).
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

function modelChip(id: string | undefined, R: string): { chip: string; tint: boolean } {
	if (!id) return { chip: "", tint: false };
	let letter = "";
	let color = DIM;
	let tint = false;
	if (id.includes("fable")) [letter, color, tint] = ["F", MAGENTA, true];
	else if (id.includes("mythos")) [letter, color, tint] = ["M", MAGENTA, true];
	else if (id.includes("opus")) letter = "O";
	else if (id.includes("sonnet")) letter = "S";
	else if (id.includes("haiku")) letter = "H";
	if (!letter) return { chip: "", tint: false };
	// {1,2} + the trailing non-digit/end anchor keeps a DATE suffix from being
	// read as a version (claude-3-5-sonnet-20241022 → bare "S"), same as the
	// bash =~ in statusline.sh.
	const m = /(?:fable|mythos|opus|sonnet|haiku)-(\d{1,2})(?:-(\d{1,2}))?(?:[^0-9]|$)/.exec(id);
	const ver = m ? (m[1] ?? "") + (m[2] ?? "") : "";
	return { chip: `${color}${letter}${ver}${R}`, tint };
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
		// still; pi renders only on activity, so the interval is ours.
		this.timer = setInterval(() => void this.refresh(false), IDLE_TICK_MS);
		this.timer.unref?.();
		void this.refresh(true);
	}

	dispose = (): void => {
		this.disposed = true;
		clearInterval(this.timer);
		this.unsubBranch();
	};

	invalidate(): void {}

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
		const { chip: model, tint } = modelChip(this.ctx.model?.id, "\x1b[39m");
		const BG = tint ? TINT_FABLE : "";
		const R = BG ? `${R0}${BG}` : R0;
		const MODEL = model ? model.replaceAll("\x1b[39m", R) : "";

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
		let row1: string;
		if (st?.isWt) {
			row1 = `${lead} ${prseg ? `${prseg} ` : ""}${BOLD}${st.wtName}${R}`;
		} else if (st?.branch) {
			row1 = `${lead} ${BOLD}${st.branch}${R}`;
		} else {
			row1 = `${lead} ${DIM}${basename(cwd)}${R}`;
		}

		// --- tail group: child-PR cluster · ⇡nag · ctx% · cost · thinking · model
		let prcluster = "";
		for (const r of panel) {
			if (!r.name || r.parent !== cwd || !r.pr) continue;
			const num = (r.pr.split(" ")[0] ?? "").replace(/^#/, "");
			const state = r.pr.split(" ").pop() ?? "";
			let col = DIM;
			if (state === "open") col = PR_OPEN;
			else if (state.startsWith("merged")) col = PR_MERGED;
			else if (state === "closed") col = PR_CLOSED;
			const link = osc8(`https://github.com/${r.slug}/pull/${num}`, `${col}${num}${R}`);
			prcluster = prcluster ? `${prcluster} ${link}` : link;
		}

		const parts: string[] = [];
		const nag = renderNag(R);
		if (nag) parts.push(nag);
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
			parts.push(`${CTX}${Math.round(usage.percent)}%${R}`);
		}
		let cost = 0;
		for (const e of this.ctx.sessionManager.getEntries()) {
			if (e.type === "message" && e.message.role === "assistant") {
				cost += e.message.usage.cost.total;
			} else if (e.type === "message" && e.message.role === "toolResult" && e.message.usage) {
				cost += e.message.usage.cost.total;
			} else if ((e.type === "branch_summary" || e.type === "compaction") && e.usage) {
				cost += e.usage.cost.total;
			}
		}
		if (cost > 0) parts.push(`${DIM}$${cost.toFixed(2)}${R}`);
		const thinking = this.ctx.thinkingLevel;
		if (this.ctx.model?.reasoning && thinking && thinking !== "off") {
			parts.push(`${DIM}${thinking}${R}`);
		}
		if (MODEL) parts.push(MODEL);
		let tailseg = parts.join(" ");
		// The cluster leads, held off the chips by two spaces so a run of bare
		// numbers can't be misread as part of "⇡3 42% $1.23 O5".
		if (prcluster) tailseg = tailseg ? `${prcluster}  ${tailseg}` : prcluster;
		if (tailseg) {
			const pad = width - visibleWidth(row1) - visibleWidth(tailseg);
			row1 = pad >= 3 ? `${row1}${" ".repeat(pad)}${tailseg}` : `${row1}   ${tailseg}`;
		}

		const lines: string[] = [emit(row1)];

		// --- rows 2+: the worktrees THIS session spawned ------------------------
		let shown = 0;
		let extra = 0;
		for (const r of panel) {
			if (!r.name) continue;
			let orphan = false;
			if (r.parent === cwd) {
				// a worktree I spawned
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
			// width-aware truncation: only clip the name if the row would overflow.
			const budget = Math.max(
				8,
				width - 4 - visibleWidth(bullet) - (orphan ? 1 : 0) - repo.length - (num ? num.length + 1 : 0),
			);
			const disp = r.name.length > budget ? `${r.name.slice(0, budget - 1)}…` : r.name;
			lines.push(emit(`  ${bullet} ${mark}${DIM}${repo}${R} ${prpill ? `${prpill} ` : ""}${disp}`));
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
