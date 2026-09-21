/*
 * Tracker — the Obsidian half of `tracker` (pkgs/tracker/README.md).
 *
 * `tracker init` copies this file and manifest.json into
 * <vault>/.obsidian/plugins/tracker/ and enables the plugin: plain CommonJS,
 * no build step. Bases draws every view (tracker.base); this does only what
 * Bases cannot — quick add, done / drop / reopen, when (now · later · someday),
 * spawn a lane (desktop: `tracker spawn <id>`), and the obsidian://tracker
 * protocol (?spawn=<path> · ?done=<path> · ?add=<title>[&when=][&in=][&due=]
 * [&repeat=][&tags=][&notes=]) that the ⚡ column, pounce and the phone's
 * share sheet use.
 *
 * `done` on a `repeat:` to-do writes the next occurrence here too, so a chore
 * closed on the phone comes back without waiting for a Mac.
 *
 * A note this writes is byte for byte what `tracker add` writes for the same
 * to-do — same key order, same YAML quoting, same file name, same body — so
 * the two halves never disagree about what a note looks like. Both are held
 * to testdata/capture.golden.md; main.test.js is this side of that.
 *
 * A to-do is a .md under tracker/ that is not a folder note (type: project, or
 * named after its folder); its id is the path under tracker/ without .md.
 */
'use strict';

const { Plugin, Modal, Notice, Setting, TFile, TFolder, normalizePath, Platform } = require('obsidian');

const ROOT = 'tracker';
const WHENS = ['now', 'later', 'someday'];
const MAX_NAME = 120;
const SPAWN_TIMEOUT = 120000;

const pad = (n) => String(n).padStart(2, '0');
const stamp = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const today = () => stamp(new Date());
const daysOut = (n) => {
  const d = new Date();
  d.setDate(d.getDate() + n);
  return stamp(d);
};

// One space between words, trimmed: the title as stored.
const tidy = (s) => String(s || '').replace(/\s+/g, ' ').trim();

// The CLI's file-name rule (internal/vault/sanitize.go): line breaks gone,
// every run of what Obsidian refuses in a link a single space, no leading dot,
// and at most 120 — cut back to a word boundary when one is near, so a long
// page title does not end mid-word. The one place it differs: createTodo
// tidies first, so a shared selection is named `line break`, not `linebreak`.
function sanitize(title) {
  let s = tidy(String(title || '').replace(/[\r\n]+/g, '').replace(/[\\/:*?"<>|^#[\]]+/g, ' ')).replace(/^\.+/, '');
  if (s.length > MAX_NAME) {
    s = s.slice(0, MAX_NAME);
    const cut = s.lastIndexOf(' ');
    if (cut > MAX_NAME - 20) s = s.slice(0, cut);
  }
  return s.trim();
}

const idOf = (path) => (path.startsWith(`${ROOT}/`) ? path.slice(ROOT.length + 1) : path).replace(/\.md$/, '');

// The CLI's YAMLStr (internal/vault/sanitize.go): bare when a bare scalar
// cannot be misread, double-quoted otherwise, a date always bare.
const yamlBare = /^[A-Za-z][A-Za-z0-9_ ./()+-]*$/;
const yamlDate = /^\d{4}-\d{2}-\d{2}$/;
const yamlWords = new Set(['true', 'false', 'yes', 'no', 'null', 'on', 'off']);
function yamlStr(s) {
  if (yamlDate.test(s)) return s;
  if (yamlBare.test(s) && !yamlWords.has(s.toLowerCase()) && s === s.trim()) return s;
  return `"${s.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

// A YYYY-MM-DD that exists.
const isDate = (s) => yamlDate.test(s) && stamp(new Date(`${s}T00:00:00`)) === s;

// today | tomorrow | +Nd | YYYY-MM-DD → a date; "" when it is none of those.
function parseDate(v) {
  const s = String(v || '').trim().toLowerCase();
  if (s === 'today') return today();
  if (s === 'tomorrow') return daysOut(1);
  const m = /^\+(\d+)d$/.exec(s);
  if (m) return daysOut(Number(m[1]));
  return isDate(s) ? s : '';
}

// now | later | someday | a date, arrived dates folded into now (the CLI's
// ParseWhen + Normalize); anything else is the default, later.
function parseWhen(v) {
  const s = String(v || '').trim().toLowerCase();
  if (WHENS.includes(s)) return s;
  if (s === 'anytime') return 'later';
  const d = parseDate(s);
  if (!d) return 'later';
  return d <= today() ? 'now' : d;
}

// The repeat grammar (internal/vault/when.go), narrow on purpose:
// daily | weekly | monthly | yearly | every N days.
const REPEAT_WORDS = { daily: 'day', weekly: 'week', monthly: 'month', yearly: 'year' };
const REPEAT_UNIT = { day: 'daily', week: 'weekly', month: 'monthly', year: 'yearly' };
const tidyLower = (v) => String(v || '').trim().toLowerCase().replace(/\s+/g, ' ');

function repeatParts(spec) {
  const s = tidyLower(spec);
  if (REPEAT_WORDS[s]) return { n: 1, unit: REPEAT_WORDS[s] };
  const m = /^every (\d+) (day|week|month|year)s?$/.exec(s);
  if (!m || Number(m[1]) < 1) return null;
  return { n: Number(m[1]), unit: m[2] };
}

// The CLI's ParseRepeat, canonical; '' for none and for anything the grammar
// does not cover — a bad parameter never costs a capture.
function parseRepeat(v) {
  const s = tidyLower(v);
  if (!s || s === 'none' || s === 'never') return '';
  const r = repeatParts(s);
  if (!r) return '';
  return r.n === 1 ? REPEAT_UNIT[r.unit] : `every ${r.n} ${r.unit}s`;
}

const dayNum = (d) => Date.parse(`${d}T00:00:00Z`);
const utcStamp = (d) => `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;

// One step of a repeat. The day of the month is kept, clamped to the month it
// lands in: the 31st monthly is the 30th in April.
function advance(date, { n, unit }) {
  if (unit === 'day' || unit === 'week') return utcStamp(new Date(dayNum(date) + n * (unit === 'week' ? 7 : 1) * 86400000));
  const [y, m, d] = date.split('-').map(Number);
  const first = new Date(Date.UTC(y, m - 1 + (unit === 'month' ? n : 12 * n), 1));
  const last = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0)).getUTCDate();
  return utcStamp(new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth(), Math.min(d, last))));
}

// The CLI's NextWhen: the note's OWN `when:` — never the day it was done —
// advanced until it is past today, so a chore done late lands on its next real
// slot and the grid never drifts. A word counts from today. `shift` is the
// days to carry a `due:` by, so a deadline keeps its lead time.
function nextWhen(when, spec) {
  const r = repeatParts(spec);
  if (!r) return null;
  const now = dayNum(today());
  let from = isDate(when) ? when : today();
  let next = advance(from, r);
  for (let i = 0; i < 4000 && dayNum(next) <= now; i++) next = advance(next, r);
  if (dayNum(next) <= now) {
    from = today();
    next = advance(from, r);
  }
  return { when: next, shift: Math.round((dayNum(next) - dayNum(from)) / 86400000) };
}

// ---- a note as ordered keys, so one can be carried forward ----------------

// The CLI's frontmatter parser in miniature (internal/vault/frontmatter.go):
// every top-level key with the lines it was read from, so a key nobody here
// knows about survives the copy. null when the note has no block.
function splitNote(raw) {
  const lines = String(raw).split('\n');
  if (lines[0] !== '---') return null;
  const end = lines.indexOf('---', 1);
  if (end < 0) return null;
  const entries = [];
  for (const line of lines.slice(1, end)) {
    const m = /^([A-Za-z_][A-Za-z0-9_-]*):(.*)$/.exec(line);
    if (m) entries.push({ key: m[1], lines: [line] });
    else if (entries.length) entries[entries.length - 1].lines.push(line);
    else entries.push({ key: '', lines: [line] });
  }
  return { entries, body: lines.slice(end + 1).join('\n') };
}

const CANON = ['type', 'when', 'repeat', 'due', 'done', 'dropped', 'tags', 'created', 'title', 'repo', 'lane', 'project'];
const rank = (k) => (CANON.indexOf(k) < 0 ? CANON.length : CANON.indexOf(k));

function getKey(entries, key) {
  const e = entries.find((x) => x.key === key);
  return e ? e.lines[0].slice(key.length + 1).trim().replace(/^"(.*)"$/, '$1') : '';
}

function setKey(entries, key, value) {
  const e = { key, lines: [`${key}: ${yamlStr(value)}`] };
  const i = entries.findIndex((x) => x.key === key);
  if (i >= 0) return void (entries[i] = e);
  const at = entries.findIndex((x) => x.key && rank(x.key) > rank(key));
  entries.splice(at < 0 ? entries.length : at, 0, e);
}

function delKey(entries, key) {
  const i = entries.findIndex((x) => x.key === key);
  if (i >= 0) entries.splice(i, 1);
}

const serialize = ({ entries, body }) => `---\n${entries.flatMap((e) => e.lines).join('\n')}\n---\n${body}`;

// A chore comes back with its checklist empty.
const untick = (body) => body.replace(/^(\s*[-*+] +\[)[xX](\])/gm, '$1 $2');

// The CLI's SanitizeTag: `#` off, every other run of punctuation a dash.
const sanitizeTag = (t) => String(t).trim().replace(/^#/, '').replace(/[^A-Za-z0-9_/-]+/g, '-');

// `a,b, c` → clean, de-duplicated tags, order kept (the CLI's Tags).
function parseTags(spec) {
  const out = [];
  const seen = new Set();
  for (const part of String(spec || '').split(',')) {
    const t = sanitizeTag(part);
    if (!t || t === '-' || seen.has(t)) continue;
    seen.add(t);
    out.push(t);
  }
  return out;
}

// The body of a new note: what was shared, one trailing newline, never CRLF.
const parseNotes = (v) => String(v || '').replace(/\r\n?/g, '\n').trim();

// A protocol path or id → the vault path. Accepts `tracker/a/b.md`,
// `tracker/a/b`, `a/b.md` and `a/b`.
function pathOf(ref) {
  const s = String(ref || '').trim();
  if (!s) return '';
  let p = normalizePath(s);
  if (!p.startsWith(`${ROOT}/`)) p = `${ROOT}/${p}`;
  return p.endsWith('.md') ? p : `${p}.md`;
}

const firstLine = (s) => String(s || '').replace(/\x1b\[[0-9;]*m/g, '').trim().split('\n')[0];
const oops = (e) => new Notice(`Tracker: ${(e && e.message) || e}`);

class QuickAddModal extends Modal {
  // seed is what a caller already knows — a share sheet that sent notes but no
  // title opens this with the notes still attached, so nothing sent is lost.
  constructor(plugin, seed = {}) {
    super(plugin.app);
    this.plugin = plugin;
    this.seed = seed;
    this.when = seed.when || 'later';
    this.project = tidy(seed.project || '');
    this.buttons = [];
  }

  onOpen() {
    const { contentEl } = this;
    this.titleEl.setText('Tracker: quick add');

    this.input = contentEl.createEl('input', { type: 'text', placeholder: 'What needs doing?' });
    this.input.style.width = '100%';
    this.input.value = tidy(this.seed.title || '');
    this.input.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        e.preventDefault();
        this.cycle(e.shiftKey ? -1 : 1);
      }
    });

    const whenRow = new Setting(contentEl).setName('When').setDesc('⇥ cycles · ⏎ adds');
    for (const w of WHENS) {
      whenRow.addButton((b) => {
        b.setButtonText(w).onClick(() => this.pick(w));
        b.buttonEl.addEventListener('keydown', (e) => {
          if (e.key === 'ArrowLeft') this.cycle(-1);
          if (e.key === 'ArrowRight') this.cycle(1);
        });
        this.buttons.push([w, b]);
      });
    }
    this.pick(this.when);

    new Setting(contentEl).setName('Project').addDropdown((d) => {
      d.addOption('', 'inbox');
      const projects = this.plugin.projects();
      for (const p of projects) d.addOption(p, p);
      if (!projects.includes(this.project)) this.project = '';
      d.setValue(this.project).onChange((v) => { this.project = v; });
    });

    new Setting(contentEl).addButton((b) => b.setButtonText('Add').setCta().onClick(() => this.submit()));

    contentEl.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.isComposing && e.target.tagName !== 'SELECT') {
        e.preventDefault();
        this.submit();
      }
    });
    this.input.focus();
  }

  pick(when) {
    this.when = when;
    for (const [w, b] of this.buttons) (w === when ? b.setCta() : b.removeCta());
  }

  cycle(step) {
    this.pick(WHENS[(WHENS.indexOf(this.when) + step + WHENS.length) % WHENS.length]);
  }

  submit() {
    const title = this.input.value;
    if (!sanitize(title)) return void new Notice('Tracker: empty title');
    this.close();
    const { title: _seedTitle, when: _seedWhen, project: _seedProject, ...rest } = this.seed;
    this.plugin.createTodo({ ...rest, title, when: this.when, project: this.project }).catch(oops);
  }

  onClose() {
    this.contentEl.empty();
  }
}

class TrackerPlugin extends Plugin {
  onload() {
    const onTodo = (fn) => () => this.withTodo(fn);
    this.addCommand({ id: 'quick-add', name: 'quick add', callback: () => this.quickAdd() });
    this.addCommand({ id: 'done', name: 'done', callback: onTodo((f) => this.closeTodo(f, 'done')) });
    this.addCommand({ id: 'drop', name: 'drop', callback: onTodo((f) => this.closeTodo(f, 'dropped')) });
    this.addCommand({ id: 'reopen', name: 'reopen', callback: onTodo((f) => this.reopen(f)) });
    for (const w of WHENS) this.addCommand({ id: w, name: w, callback: onTodo((f) => this.setWhen(f, w)) });
    this.addCommand({ id: 'cycle-when', name: 'cycle when: now → later → someday', callback: onTodo((f) => this.cycleWhen(f)) });
    this.addCommand({ id: 'spawn', name: 'spawn a lane for this to-do', callback: onTodo((f) => this.spawn(f)) });
    this.addRibbonIcon('check-circle', 'Tracker: quick add', () => this.quickAdd());
    this.registerObsidianProtocolHandler('tracker', (params) => this.handleProtocol(params));
  }

  // obsidian://tracker?spawn=<path> · ?done=<path>
  //   ?add=<title>[&when=][&in=<project>][&due=][&tags=a,b][&notes=<body>]
  // The phone's share sheet is an ?add= with the page title and &notes= the
  // URL or the selection; an ?add= with no title opens quick add holding it.
  handleProtocol(params) {
    if (params.spawn != null) return this.withTodo((f) => this.spawn(f), params.spawn);
    if (params.done != null) return this.withTodo((f) => this.closeTodo(f, 'done'), params.done);
    if (params.add != null) {
      const todo = {
        title: params.add,
        when: parseWhen(params.when),
        project: params.in,
        due: params.due,
        repeat: params.repeat,
        tags: params.tags,
        notes: params.notes,
      };
      if (!tidy(params.add)) return this.quickAdd(todo);
      return this.createTodo(todo).catch(oops);
    }
    new Notice('Tracker: obsidian://tracker takes ?spawn=<path>, ?done=<path> or ?add=<title>');
  }

  quickAdd(seed) {
    new QuickAddModal(this, seed).open();
  }

  // ---- the vault -------------------------------------------------------

  frontmatter(file) {
    const cache = this.app.metadataCache.getFileCache(file);
    return (cache && cache.frontmatter) || {};
  }

  isFolderNote(file) {
    return this.frontmatter(file).type === 'project' || (file.parent != null && file.basename === file.parent.name);
  }

  isTodo(file) {
    return file instanceof TFile && file.extension === 'md' && file.path.startsWith(`${ROOT}/`) && !this.isFolderNote(file);
  }

  // Every folder under tracker/ that has a folder note, as `hausfold`, `hausfold/ci`.
  projects() {
    const out = [];
    const walk = (folder) => {
      for (const child of folder.children) {
        if (!(child instanceof TFolder)) continue;
        if (child.children.some((f) => f instanceof TFile && f.extension === 'md' && this.isFolderNote(f))) {
          out.push(child.path.slice(ROOT.length + 1));
        }
        walk(child);
      }
    };
    const root = this.app.vault.getFolderByPath(ROOT);
    if (root) walk(root);
    return out.sort((a, b) => a.localeCompare(b));
  }

  // fn(file) on the active file, or on `ref` (a protocol path / id) when given.
  async withTodo(fn, ref) {
    const file = ref === undefined ? this.app.workspace.getActiveFile() : this.app.vault.getFileByPath(pathOf(ref));
    if (!file || !this.isTodo(file)) return void new Notice(`Tracker: not a to-do${ref ? ` — ${ref}` : ''}`);
    try {
      await fn(file);
    } catch (e) {
      console.error('tracker', e);
      oops(e);
    }
  }

  // ---- the verbs -------------------------------------------------------

  // The keys go in the CLI's canonical order (when · due · tags · created ·
  // title) so a note from here and one from `tracker add` are the same bytes.
  async createTodo({ title, when = 'later', project = '', due = '', repeat = '', tags = '', notes = '' }) {
    const clean = tidy(title);
    const name = sanitize(clean);
    if (!name) throw new Error('empty title');
    project = tidy(project);
    const dir = project && project.toLowerCase() !== 'inbox' ? `${ROOT}/${normalizePath(project)}` : ROOT;
    if (!this.app.vault.getFolderByPath(dir)) throw new Error(`no folder ${dir}/`);
    let path = `${dir}/${name}.md`;
    for (let n = 2; this.app.vault.getAbstractFileByPath(path); n++) path = `${dir}/${name} (${n}).md`;
    const lines = [`when: ${when}`];
    const every = parseRepeat(repeat);
    if (repeat && !every) new Notice(`Tracker: ignored repeat=${repeat} — daily | weekly | monthly | yearly | every N days`);
    if (every) lines.push(`repeat: ${every}`);
    const deadline = parseDate(due);
    if (due && !deadline) new Notice(`Tracker: ignored due=${due} — today | tomorrow | +Nd | YYYY-MM-DD`);
    if (deadline) lines.push(`due: ${deadline}`);
    const tagList = parseTags(tags);
    if (tagList.length) lines.push('tags:', ...tagList.map((t) => `  - ${yamlStr(t)}`));
    lines.push(`created: ${today()}`);
    // title: only when the file name is not the title (sanitized, or a ` (2)` collision).
    if (path.slice(dir.length + 1, -3) !== clean) lines.push(`title: ${yamlStr(clean)}`);
    const body = parseNotes(notes);
    const file = await this.app.vault.create(path, `---\n${lines.join('\n')}\n---\n${body ? `${body}\n` : ''}`);
    new Notice(`Tracker: added · ${idOf(path)}`);
    return file;
  }

  async closeTodo(file, key) {
    const other = key === 'done' ? 'dropped' : 'done';
    // `done` repeats, `drop` ends the series — and the occurrence is written
    // first, so a series never loses its successor to a failed write.
    const again = key === 'done' ? await this.repeatNext(file) : '';
    await this.app.fileManager.processFrontMatter(file, (fm) => {
      fm[key] = today();
      delete fm[other];
    });
    new Notice(`Tracker: ${key} · ${idOf(file.path)}${again ? ` · ↻ ${again}` : ''}`);
  }

  // The next occurrence of a repeating to-do: the same note on its next date,
  // beside this one, with a fresh `created:`, no `done:` / `dropped:` /
  // `lane:` and an empty checklist — the bytes the CLI's Done writes. Returns
  // its id, '' when the to-do does not repeat.
  async repeatNext(file) {
    const note = splitNote(await this.app.vault.read(file));
    if (!note) return '';
    const spec = getKey(note.entries, 'repeat');
    if (!spec) return '';
    const next = nextWhen(getKey(note.entries, 'when'), spec);
    if (!next) {
      new Notice(`Tracker: repeat ${spec} is not one — closed, nothing repeated`);
      return '';
    }
    const title = getKey(note.entries, 'title') || file.basename;
    const open = this.occurrence(file, title, spec);
    if (open) return `${open} is open already`;
    setKey(note.entries, 'when', next.when);
    setKey(note.entries, 'created', today());
    for (const k of ['done', 'dropped', 'lane']) delKey(note.entries, k);
    const due = getKey(note.entries, 'due');
    if (isDate(due)) setKey(note.entries, 'due', utcStamp(new Date(dayNum(due) + next.shift * 86400000)));
    const dir = file.parent && file.parent.path ? file.parent.path : ROOT;
    const name = sanitize(title) || file.basename;
    let path = `${dir}/${name}.md`;
    for (let n = 2; this.app.vault.getAbstractFileByPath(path); n++) path = `${dir}/${name} (${n}).md`;
    // The file name had to step aside for the closed note: the title is kept,
    // so it is still what you type and what every view shows.
    if (path.slice(dir.length + 1, -3) === title) delKey(note.entries, 'title');
    else setKey(note.entries, 'title', title);
    note.body = untick(note.body);
    await this.app.vault.create(path, serialize(note));
    return idOf(path);
  }

  // An open to-do beside this one with the same title and the same `repeat:`
  // — the same series, which a reopen and a second done would duplicate.
  occurrence(file, title, spec) {
    for (const f of (file.parent && file.parent.children) || []) {
      if (f === file || !(f instanceof TFile) || f.extension !== 'md') continue;
      const fm = this.frontmatter(f);
      if (!fm.done && !fm.dropped && fm.repeat === spec && (fm.title || f.basename) === title) return idOf(f.path);
    }
    return '';
  }

  async reopen(file) {
    await this.app.fileManager.processFrontMatter(file, (fm) => {
      delete fm.done;
      delete fm.dropped;
    });
    new Notice(`Tracker: reopened · ${idOf(file.path)}`);
  }

  async setWhen(file, when) {
    await this.app.fileManager.processFrontMatter(file, (fm) => { fm.when = when; });
    new Notice(`Tracker: ${when} · ${idOf(file.path)}`);
  }

  // now → later → someday → now; a date, like a missing value, counts as later.
  async cycleWhen(file) {
    let next;
    await this.app.fileManager.processFrontMatter(file, (fm) => {
      const i = WHENS.indexOf(fm.when);
      next = WHENS[((i < 0 ? 1 : i) + 1) % WHENS.length];
      fm.when = next;
    });
    new Notice(`Tracker: ${next} · ${idOf(file.path)}`);
  }

  // Desktop only: `tracker spawn <id>` with the profile bins in front of
  // Obsidian's own PATH, which is Finder's and has none of them.
  spawn(file) {
    const id = idOf(file.path);
    if (!Platform.isDesktopApp) return void new Notice('Tracker: spawn needs the Mac — run `tracker spawn` there');
    const { execFile } = require('child_process');
    const user = process.env.USER || require('os').userInfo().username;
    const prelude = `/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin`;
    const env = { ...process.env, PATH: `${prelude}:${process.env.PATH || ''}` };
    new Notice(`Tracker: spawning a lane for ${id}…`);
    return new Promise((resolve) => {
      execFile('tracker', ['spawn', id], { env, timeout: SPAWN_TIMEOUT }, (err, stdout, stderr) => {
        if (err) new Notice(`Tracker: spawn failed — ${firstLine(stderr) || (err.code === 'ENOENT' ? 'tracker is not on PATH' : err.message)}`, 10000);
        else new Notice(`Tracker: ${firstLine(stdout) || `spawned ${id}`}`, 8000);
        resolve();
      });
    });
  }
}

module.exports = TrackerPlugin;
