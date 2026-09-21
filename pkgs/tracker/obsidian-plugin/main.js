/*
 * Tracker — the Obsidian half of `tracker` (pkgs/tracker/README.md).
 *
 * `tracker init` copies this file and manifest.json into
 * <vault>/.obsidian/plugins/tracker/ and enables the plugin: plain CommonJS,
 * no build step. Bases draws every view (tracker.base); this does only what
 * Bases cannot — quick add, done / drop / reopen, when (now · later · someday),
 * spawn a lane (desktop: `tracker spawn <id>`), and the obsidian://tracker
 * protocol (?spawn=<path> · ?done=<path> · ?add=<title>[&when=…][&in=<project>])
 * that the ⚡ column and pounce use.
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
const today = () => {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

// One space between words, trimmed: the title as stored.
const tidy = (s) => String(s || '').replace(/\s+/g, ' ').trim();

// The CLI's file-name rule: drop what Obsidian and the filesystem refuse,
// no leading dot, at most 120 characters.
function sanitize(title) {
  const s = tidy(tidy(title).replace(/[\\/:*?"<>|#^[\]]/g, '')).replace(/^[.\s]+/, '');
  return s.slice(0, MAX_NAME).trim();
}

const idOf = (path) => (path.startsWith(`${ROOT}/`) ? path.slice(ROOT.length + 1) : path).replace(/\.md$/, '');

// now | later | someday | YYYY-MM-DD; anything else is the default, later.
function parseWhen(v) {
  const s = String(v || '').trim().toLowerCase();
  return WHENS.includes(s) || /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : 'later';
}

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
  constructor(plugin) {
    super(plugin.app);
    this.plugin = plugin;
    this.when = 'later';
    this.project = '';
    this.buttons = [];
  }

  onOpen() {
    const { contentEl } = this;
    this.titleEl.setText('Tracker: quick add');

    this.input = contentEl.createEl('input', { type: 'text', placeholder: 'What needs doing?' });
    this.input.style.width = '100%';
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
      for (const p of this.plugin.projects()) d.addOption(p, p);
      d.setValue('').onChange((v) => { this.project = v; });
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
    this.plugin.createTodo({ title, when: this.when, project: this.project }).catch(oops);
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

  // obsidian://tracker?spawn=<path> · ?done=<path> · ?add=<title>[&when=…][&in=<project>]
  handleProtocol(params) {
    if (params.spawn != null) return this.withTodo((f) => this.spawn(f), params.spawn);
    if (params.done != null) return this.withTodo((f) => this.closeTodo(f, 'done'), params.done);
    if (params.add != null) {
      if (!tidy(params.add)) return this.quickAdd();
      return this.createTodo({ title: params.add, when: parseWhen(params.when), project: params.in }).catch(oops);
    }
    new Notice('Tracker: obsidian://tracker takes ?spawn=<path>, ?done=<path> or ?add=<title>');
  }

  quickAdd() {
    new QuickAddModal(this).open();
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

  async createTodo({ title, when = 'later', project = '' }) {
    const clean = tidy(title);
    const name = sanitize(clean);
    if (!name) throw new Error('empty title');
    project = tidy(project);
    const dir = project && project.toLowerCase() !== 'inbox' ? `${ROOT}/${normalizePath(project)}` : ROOT;
    if (!this.app.vault.getFolderByPath(dir)) throw new Error(`no folder ${dir}/`);
    let path = `${dir}/${name}.md`;
    for (let n = 2; this.app.vault.getAbstractFileByPath(path); n++) path = `${dir}/${name} (${n}).md`;
    const lines = [`when: ${when}`, `created: ${today()}`];
    // title: only when the file name is not the title (sanitized, or a ` (2)` collision).
    if (path.slice(dir.length + 1, -3) !== clean) lines.push(`title: ${JSON.stringify(clean)}`);
    const file = await this.app.vault.create(path, `---\n${lines.join('\n')}\n---\n`);
    new Notice(`Tracker: added · ${idOf(path)}`);
    return file;
  }

  async closeTodo(file, key) {
    const other = key === 'done' ? 'dropped' : 'done';
    await this.app.fileManager.processFrontMatter(file, (fm) => {
      fm[key] = today();
      delete fm[other];
    });
    new Notice(`Tracker: ${key} · ${idOf(file.path)}`);
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
