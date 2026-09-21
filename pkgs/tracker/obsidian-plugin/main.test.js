/*
 * main.test.js — `node --test obsidian-plugin/` , and `go test ./...` runs it
 * for you when node is on PATH (plugin_test.go).
 *
 * Obsidian is not here, so the handful of things main.js asks of it are stubbed
 * and the vault is a Map. What that buys is the one assertion that matters: a
 * note the plugin writes is byte for byte the note `tracker add` writes, both
 * of them testdata/capture.golden.md.
 */
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const Module = require('node:module');
const fs = require('node:fs');
const path = require('node:path');

// ---- the clock: both halves stamp `created:` the fixture's day -------------

const GoldenDay = '2026-09-20';
const RealDate = Date;
class FrozenDate extends RealDate {
  constructor(...args) {
    if (args.length === 0) super(`${GoldenDay}T12:00:00`);
    else super(...args);
  }
}
globalThis.Date = FrozenDate;

// ---- the stub of Obsidian main.js requires --------------------------------

const notices = [];
class Notice {
  constructor(message) {
    notices.push(String(message));
  }
}
const obsidian = {
  Plugin: class {
    constructor(app) {
      this.app = app;
    }
    addCommand() {}
    addRibbonIcon() {}
    registerObsidianProtocolHandler() {}
  },
  Modal: class {
    constructor(app) {
      this.app = app;
    }
    open() {}
    close() {}
  },
  Notice,
  Setting: class {
    setName() {
      return this;
    }
    setDesc() {
      return this;
    }
    addButton() {
      return this;
    }
    addDropdown() {
      return this;
    }
  },
  TFile: class {},
  TFolder: class {},
  Platform: { isDesktopApp: false },
  normalizePath: (p) => String(p).replace(/\/+/g, '/').replace(/^\/|\/$/g, ''),
};

const load = Module._load;
Module._load = (request, ...rest) => (request === 'obsidian' ? obsidian : load(request, ...rest));
const TrackerPlugin = require('./main.js');

// ---- a vault that is a Map ------------------------------------------------

// folders are the ones `tracker init` and a project make; files start empty.
function plugin(folders = ['tracker', 'tracker/hausfold']) {
  const files = new Map();
  const vault = {
    created: [],
    files,
    getFolderByPath: (p) => (folders.includes(p) ? { path: p } : null),
    getAbstractFileByPath: (p) => files.get(p) || null,
    async create(p, data) {
      const file = { path: p, data };
      files.set(p, file);
      vault.created.push(file);
      return file;
    },
    async read(file) {
      return file.data;
    },
  };
  // processFrontMatter is Obsidian's own YAML writer; what matters here is
  // which keys a verb set, so the stub hands the verb a plain object.
  const fileManager = {
    async processFrontMatter(file, fn) {
      file.frontmatter = { ...(file.frontmatter || {}) };
      fn(file.frontmatter);
    },
  };
  const metadataCache = { getFileCache: (f) => (f && f.frontmatter ? { frontmatter: f.frontmatter } : null) };
  notices.length = 0;
  return new TrackerPlugin({ vault, fileManager, metadataCache, workspace: {} });
}

// A note already in the vault: what the verbs that read one are given.
function seed(p, path, data, frontmatter) {
  const dir = path.slice(0, path.lastIndexOf('/'));
  const file = Object.assign(new obsidian.TFile(), {
    path,
    data,
    basename: path.slice(dir.length + 1, -3),
    extension: 'md',
    frontmatter,
  });
  const folder = { path: dir, children: [] };
  for (const f of p.app.vault.files.values()) {
    if (f.path.slice(0, f.path.lastIndexOf('/')) === dir) {
      f.parent = folder;
      folder.children.push(f);
    }
  }
  file.parent = folder;
  folder.children.push(file);
  p.app.vault.files.set(path, file);
  return file;
}

// The one note in the vault after a capture: its path and its bytes.
const only = (p) => {
  assert.equal(p.app.vault.created.length, 1, `wrote ${p.app.vault.created.length} notes`);
  return p.app.vault.created[0];
};

const golden = fs.readFileSync(path.join(__dirname, '..', 'testdata', 'capture.golden.md'), 'utf8');
const GoldenTitle = 'Why Nix flakes: a field guide | example.com';
const GoldenName = 'Why Nix flakes a field guide example.com';

// ---- the capture ----------------------------------------------------------

test('createTodo writes the note `tracker add` writes, byte for byte', async () => {
  const p = plugin();
  await p.createTodo({
    title: GoldenTitle,
    when: 'later',
    due: '2026-09-30',
    tags: 'read, #example.com',
    notes: 'https://example.com/nix-flakes',
  });
  const file = only(p);
  assert.equal(file.path, `tracker/${GoldenName}.md`);
  assert.equal(file.data, golden);
});

test('the share sheet — ?add= with &notes=, &due= and &tags= — writes the same note', async () => {
  const p = plugin();
  await p.handleProtocol({
    action: 'tracker',
    add: GoldenTitle,
    when: 'later',
    due: '2026-09-30',
    tags: 'read, #example.com',
    notes: 'https://example.com/nix-flakes',
  });
  assert.equal(only(p).data, golden);
});

test('a share with no title opens quick add still holding what was shared', async () => {
  const p = plugin();
  let seed;
  p.quickAdd = (s) => {
    seed = s;
  };
  await p.handleProtocol({ action: 'tracker', add: '  ', notes: 'https://example.com/', due: 'tomorrow', tags: 'read' });
  assert.equal(p.app.vault.created.length, 0, 'an empty title must not make a note');
  assert.equal(seed.notes, 'https://example.com/');
  assert.equal(seed.due, 'tomorrow');
  assert.equal(seed.tags, 'read');
});

// ---- the fields -----------------------------------------------------------

test('when takes the relative forms the CLI takes, and folds an arrived date into now', async () => {
  const cases = {
    now: 'now',
    someday: 'someday',
    anytime: 'later',
    tomorrow: '2026-09-21',
    '+3d': '2026-09-23',
    '2026-12-01': '2026-12-01',
    today: 'now',
    '2026-09-19': 'now',
    'next tuesday': 'later',
    '': 'later',
  };
  for (const [when, want] of Object.entries(cases)) {
    const p = plugin();
    await p.handleProtocol({ action: 'tracker', add: 'a thing', when });
    assert.match(only(p).data, new RegExp(`^---\\nwhen: ${want}\\n`), `when=${when}`);
  }
});

test('a due date that is not one is refused out loud, and the capture still lands', async () => {
  const p = plugin();
  await p.createTodo({ title: 'a thing', due: 'next tuesday' });
  assert.equal(only(p).data, `---\nwhen: later\ncreated: ${GoldenDay}\n---\n`);
  assert.ok(
    notices.some((n) => n.includes('ignored due=next tuesday')),
    `no notice about the due date: ${JSON.stringify(notices)}`,
  );
});

test('tags are sanitized, de-duplicated and written as a block list', async () => {
  const p = plugin();
  await p.createTodo({ title: 'a thing', tags: 'a, #b,, a, c d' });
  assert.equal(only(p).data, `---\nwhen: later\ntags:\n  - a\n  - b\n  - c-d\ncreated: ${GoldenDay}\n---\n`);

  // A word YAML would read as a boolean is quoted, the way YAMLStr does it.
  const q = plugin();
  await q.createTodo({ title: 'a thing', tags: 'yes,2026' });
  assert.match(only(q).data, /tags:\n {2}- "yes"\n {2}- "2026"\n/);
});

test('notes become the body: CRLF gone, one trailing newline', async () => {
  const p = plugin();
  await p.createTodo({ title: 'a thing', notes: '\r\nline one\r\nline two\n\n' });
  assert.equal(only(p).data, `---\nwhen: later\ncreated: ${GoldenDay}\n---\nline one\nline two\n`);
});

test('a project files the note in its folder; an unknown one refuses', async () => {
  const p = plugin();
  await p.handleProtocol({ action: 'tracker', add: 'a thing', in: 'hausfold' });
  assert.equal(only(p).path, 'tracker/hausfold/a thing.md');
  await assert.rejects(plugin().createTodo({ title: 'a thing', project: 'nope' }), /no folder tracker\/nope/);
});

// ---- the file name --------------------------------------------------------

// The cases are internal/vault/frontmatter_test.go's TestSanitize, minus the
// line break: the plugin tidies whitespace before it sanitizes, so a shared
// selection reads as `line break` where the CLI would name it `linebreak`.
test('the file name follows the CLI rule, character for character', async () => {
  const cases = {
    'a: b/c*d?e"f<g>h|i#j^k[l]m': 'a b c d e f g h i j k l m',
    '  many   spaces  ': 'many spaces',
    '...dotted': 'dotted',
    'line\nbreak': 'line break',
    [`${'word '.repeat(40)}end`]: 'word '.repeat(24).trim(),
  };
  for (const [title, want] of Object.entries(cases)) {
    const p = plugin();
    await p.createTodo({ title });
    assert.equal(only(p).path, `tracker/${want}.md`, JSON.stringify(title));
  }
});

test('a title the file name had to change is kept as title:, quoted only when it must be', async () => {
  const p = plugin();
  await p.createTodo({ title: 'plain title' });
  assert.equal(only(p).data, `---\nwhen: later\ncreated: ${GoldenDay}\n---\n`, 'an untouched title needs no title:');

  const q = plugin();
  await q.createTodo({ title: 'a "quoted" \\ title' });
  assert.match(only(q).data, /title: "a \\"quoted\\" \\\\ title"\n/);
});

test('a name already taken gets the CLI’s (2)', async () => {
  const p = plugin();
  await p.createTodo({ title: 'a thing' });
  await p.createTodo({ title: 'a thing' });
  assert.deepEqual(
    p.app.vault.created.map((f) => f.path),
    ['tracker/a thing.md', 'tracker/a thing (2).md'],
  );
});

test('a title that sanitizes to nothing is refused', async () => {
  await assert.rejects(plugin().createTodo({ title: ' /// ' }), /empty title/);
});

// ---- repeat ---------------------------------------------------------------

const Repeating = `---
when: 2026-09-18
repeat: weekly
due: 2026-09-19
tags:
  - home
created: 2026-09-14
---
- [x] kitchen
- [ ] hall
`;

test('a repeat goes in the note right after when:, canonical', async () => {
  const p = plugin();
  await p.createTodo({ title: 'water the plants', when: 'later', repeat: 'EVERY 2  weeks', due: '2026-09-30' });
  assert.equal(only(p).data, '---\nwhen: later\nrepeat: every 2 weeks\ndue: 2026-09-30\ncreated: 2026-09-20\n---\n');
});

test('a repeat that is not one is refused out loud, and the capture still lands', async () => {
  const p = plugin();
  await p.handleProtocol({ action: 'tracker', add: 'water the plants', repeat: 'every other tuesday' });
  assert.equal(only(p).data, '---\nwhen: later\ncreated: 2026-09-20\n---\n');
  assert.ok(notices.some((n) => n.includes('ignored repeat=every other tuesday')));
});

test('done writes the next occurrence — the bytes the CLI writes for it', async () => {
  const p = plugin();
  const file = seed(p, 'tracker/hausfold/water the plants.md', Repeating);
  await p.closeTodo(file, 'done');
  assert.equal(file.frontmatter.done, '2026-09-20');
  const next = only(p);
  assert.equal(next.path, 'tracker/hausfold/water the plants (2).md');
  assert.equal(
    next.data,
    `---
when: 2026-09-25
repeat: weekly
due: 2026-09-26
tags:
  - home
created: 2026-09-20
title: water the plants
---
- [ ] kitchen
- [ ] hall
`,
  );
});

test('drop ends the series, and a to-do with no repeat never had one', async () => {
  const p = plugin();
  await p.closeTodo(seed(p, 'tracker/hausfold/water the plants.md', Repeating), 'dropped');
  await p.closeTodo(seed(p, 'tracker/hausfold/once.md', '---\nwhen: now\ncreated: 2026-09-14\n---\n'), 'done');
  assert.equal(p.app.vault.created.length, 0, 'wrote an occurrence it should not have');
});

test('an occurrence already open is left alone, not written twice', async () => {
  const p = plugin();
  const file = seed(p, 'tracker/hausfold/water the plants.md', Repeating);
  seed(p, 'tracker/hausfold/water the plants (2).md', Repeating, { when: '2026-09-25', repeat: 'weekly', title: 'water the plants' });
  await p.closeTodo(file, 'done');
  assert.equal(p.app.vault.created.length, 0);
  assert.ok(notices.some((n) => n.includes('water the plants (2) is open already')));
});
