package cli

import (
	"bytes"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/julienmartel/tracker/internal/vault"
)

// app is a CLI over a migrated copy of the fixture, today pinned.
func app(t *testing.T) (*App, *bytes.Buffer, *bytes.Buffer) {
	t.Helper()
	src, _ := filepath.Abs(filepath.Join("..", "..", "testdata", "vault"))
	dst := t.TempDir()
	if err := copyTree(src, dst); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	v := vault.New(dst)
	v.SetToday("2026-09-20")
	if _, _, err := v.Migrate(); err != nil {
		t.Fatal(err)
	}
	out, errw := &bytes.Buffer{}, &bytes.Buffer{}
	return &App{V: v, Out: out, Err: errw, Run: &noRunner{}}, out, errw
}

type noRunner struct{}

func (*noRunner) Run(env []string, stdin string, name string, args ...string) (string, string, int, error) {
	return "", "", 0, nil
}

func copyTree(src, dst string) error {
	return filepath.WalkDir(src, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, p)
		if d.IsDir() {
			return os.MkdirAll(filepath.Join(dst, rel), 0o755)
		}
		in, err := os.Open(p)
		if err != nil {
			return err
		}
		defer in.Close()
		out, err := os.Create(filepath.Join(dst, rel))
		if err != nil {
			return err
		}
		defer out.Close()
		_, err = io.Copy(out, in)
		return err
	})
}

func run(t *testing.T, a *App, out, errw *bytes.Buffer, args ...string) (int, string, string) {
	t.Helper()
	out.Reset()
	errw.Reset()
	a.JSON = false
	code := a.Main(args)
	return code, out.String(), errw.String()
}

func TestReads(t *testing.T) {
	a, out, errw := app(t)
	code, o, _ := run(t, a, out, errw, "today")
	if code != 0 || !strings.Contains(o, "hausfold/ship the thing") || !strings.Contains(o, "buy cat food") || !strings.Contains(o, "2 item(s)") {
		t.Errorf("today: %d\n%s", code, o)
	}
	code, o, _ = run(t, a, out, errw, "today", "--json")
	var items []map[string]any
	if err := json.Unmarshal([]byte(o), &items); err != nil || len(items) != 2 {
		t.Fatalf("today --json: %v\n%s", err, o)
	}
	for _, k := range []string{"id", "title", "folder", "project", "when", "bucket", "due", "done", "dropped", "tags", "created", "lane", "repo", "path"} {
		if _, ok := items[0][k]; !ok {
			t.Errorf("json lacks %q", k)
		}
	}
	if items[0]["bucket"] != "now" || items[0]["when"] != "now" {
		t.Errorf("row %v", items[0])
	}
	_, o, _ = run(t, a, out, errw, "later")
	if !strings.Contains(o, "── hausfold ──") || !strings.Contains(o, "── (inbox) ──") {
		t.Errorf("later groups:\n%s", o)
	}
	_, o, _ = run(t, a, out, errw, "upcoming", "30000")
	if !strings.Contains(o, "◔ 2099-01-01") {
		t.Errorf("upcoming:\n%s", o)
	}
	_, o, _ = run(t, a, out, errw, "due", "100")
	if !strings.Contains(o, "due 2026-12-01") {
		t.Errorf("due:\n%s", o)
	}
	_, o, _ = run(t, a, out, errw, "done", "1")
	if !strings.Contains(o, "1 item(s)") {
		t.Errorf("done 1:\n%s", o)
	}
	_, o, _ = run(t, a, out, errw, "list", "hausfold")
	if !strings.Contains(o, "── now ──") || !strings.Contains(o, "hausfold/ci/cache the store") {
		t.Errorf("list:\n%s", o)
	}
	_, o, _ = run(t, a, out, errw, "projects")
	if !strings.Contains(o, "  ci ") || !strings.Contains(o, "~/code/workshop") || !strings.Contains(o, "(inbox)") {
		t.Errorf("projects:\n%s", o)
	}
	_, o, _ = run(t, a, out, errw, "projects", "--json")
	var rows []map[string]any
	if err := json.Unmarshal([]byte(o), &rows); err != nil || len(rows) != 5 {
		t.Errorf("projects --json: %v %d", err, len(rows))
	}
	_, o, _ = run(t, a, out, errw, "search", "shipped")
	if !strings.Contains(o, "log/old thing") {
		t.Errorf("search body:\n%s", o)
	}
	_, o, _ = run(t, a, out, errw, "show", "ship the")
	if !strings.HasPrefix(o, "id:    hausfold/ship the thing\nfile://") || !strings.Contains(o, "obsidian://open?vault=") || !strings.Contains(o, "- [ ] draft") {
		t.Errorf("show:\n%s", o)
	}
	_, o, _ = run(t, a, out, errw, "link", "with colon")
	if !strings.HasPrefix(o, "file:///") || !strings.Contains(o, "Title%20with%20colon.md\n") {
		t.Errorf("link:\n%s", o)
	}
	_, o, _ = run(t, a, out, errw, "index", "--json")
	if !strings.Contains(o, `"id": "log/old thing"`) {
		t.Error("index lacks the log")
	}
	code, o, _ = run(t, a, out, errw, "help")
	if code != 0 || !strings.Contains(o, "tracker add <title>") {
		t.Error("help")
	}
}

func TestExitCodes(t *testing.T) {
	a, out, errw := app(t)
	code, _, e := run(t, a, out, errw, "bogus")
	if code != 2 || !strings.Contains(e, "unknown verb") {
		t.Errorf("unknown verb: %d %q", code, e)
	}
	code, _, e = run(t, a, out, errw, "done", "nothing here")
	if code != 1 || !strings.Contains(e, "nothing open matches") {
		t.Errorf("no match: %d %q", code, e)
	}
	code, _, e = run(t, a, out, errw, "done", "the")
	if code != 1 || !strings.Contains(e, "ambiguous") || !strings.Contains(e, "hausfold/ship the thing") {
		t.Errorf("ambiguous: %d %q", code, e)
	}
	code, _, _ = run(t, a, out, errw, "when", "ship the", "nonsense")
	if code != 2 {
		t.Errorf("bad when: %d", code)
	}
	code, _, _ = run(t, a, out, errw, "add")
	if code != 2 {
		t.Errorf("add without a title: %d", code)
	}
	code, _, _ = run(t, a, out, errw, "add", "x", "--in", "nowhere")
	if code != 1 {
		t.Errorf("add into a missing project: %d", code)
	}
}

func TestWrites(t *testing.T) {
	a, out, errw := app(t)
	code, o, _ := run(t, a, out, errw, "add", "buy", "cat", "food", "again", "--in", "pers", "--when", "tomorrow", "--deadline", "+3d", "--tags", "errand,#buy", "--checklist", "a|b")
	lines := strings.Split(strings.TrimSpace(o), "\n")
	if code != 0 || lines[0] != "added: Personal/buy cat food again" || !strings.HasPrefix(lines[len(lines)-1], "file:///") {
		t.Fatalf("add: %d\n%s", code, o)
	}
	got, _ := os.ReadFile(a.V.Path("Personal/buy cat food again"))
	if string(got) != "---\nwhen: 2026-09-21\ndue: 2026-09-23\ntags:\n  - errand\n  - buy\ncreated: 2026-09-20\n---\n- [ ] a\n- [ ] b\n" {
		t.Errorf("added note:\n%s", got)
	}
	// DRY_RUN prints, writes nothing.
	code, o, _ = run(t, a, out, errw, "add", "dry", "--dry-run")
	if code != 0 || !strings.Contains(o, "would add: dry") {
		t.Errorf("dry add: %s", o)
	}
	if _, err := os.Stat(a.V.Path("dry")); err == nil {
		t.Error("dry run wrote")
	}
	a.V.DryRun = false

	code, o, _ = run(t, a, out, errw, "complete", "cat food again")
	if code != 0 || !strings.HasPrefix(o, "✓ buy cat food again  (Personal/buy cat food again)\nfile://") {
		t.Errorf("complete: %s", o)
	}
	code, o, _ = run(t, a, out, errw, "reopen", "cat food again")
	if code != 0 || !strings.HasPrefix(o, "reopened: Personal/buy cat food again") {
		t.Errorf("reopen: %s", o)
	}
	code, o, _ = run(t, a, out, errw, "update", "cat food again", "--when", "someday", "--due", "none", "--add-tags", "x", "--title", "Cat food: again", "--in", "inbox", "--append-notes", "ps")
	if code != 0 || !strings.Contains(o, "moved: Cat food again  → inbox") {
		t.Errorf("update: %d %s", code, o)
	}
	got, _ = os.ReadFile(a.V.Path("Cat food again"))
	want := "---\nwhen: someday\ntags:\n  - errand\n  - buy\n  - x\ncreated: 2026-09-20\ntitle: \"Cat food: again\"\n---\n- [ ] a\n- [ ] b\n\nps\n"
	if string(got) != want {
		t.Errorf("updated note:\n%s\nwant:\n%s", got, want)
	}
	code, o, _ = run(t, a, out, errw, "tag", "food again", "-x", "+y")
	if code != 0 || !strings.Contains(o, "tags: errand, buy, y") {
		t.Errorf("tag: %s", o)
	}
	code, o, _ = run(t, a, out, errw, "move", "food again", "hausfold/ci")
	if code != 0 || !strings.Contains(o, "moved: hausfold/ci/Cat food again  → hausfold/ci") {
		t.Errorf("move: %s", o)
	}
	code, o, _ = run(t, a, out, errw, "project", "add", "garden", "--in", "Personal", "--repo", "~/g", "--todos", "dig|plant")
	if code != 0 || !strings.Contains(o, "added project: Personal/garden") || !strings.Contains(o, "added: Personal/garden/plant") {
		t.Errorf("project add: %s", o)
	}
	code, o, _ = run(t, a, out, errw, "project", "set", "garden", "repo=~/garden")
	if code != 0 || !strings.Contains(o, "repo: ~/garden") {
		t.Errorf("project set: %s", o)
	}
	code, o, _ = run(t, a, out, errw, "spawn", "dig", "--dry-run")
	if code != 0 || !strings.Contains(o, "--derived-name dig --agent claude --prompt-file -") || !strings.Contains(o, "/garden --derived-name") {
		t.Errorf("spawn dry: %d %s", code, o)
	}
	a.V.DryRun = false
	code, o, _ = run(t, a, out, errw, "promote", "plant")
	if code != 0 || !strings.Contains(o, "promoted: Personal/garden/plant  → project Personal/garden/plant") {
		t.Errorf("promote: %s", o)
	}
	code, o, _ = run(t, a, out, errw, "archive", "--older", "5", "--dry-run")
	if code != 0 || !strings.Contains(o, "nas/replace disk") || !strings.Contains(o, "dry run") {
		t.Errorf("archive dry: %s", o)
	}
	a.V.DryRun = false
	code, o, _ = run(t, a, out, errw, "done", "--json", "old thing")
	if code != 1 {
		t.Errorf("done on a closed note should refuse: %d %s", code, o)
	}
	code, o, _ = run(t, a, out, errw, "now", "--json", "call mom")
	if code != 0 || !strings.Contains(o, `"file": "file:///`) {
		t.Errorf("--json write: %s", o)
	}
	code, o, _ = run(t, a, out, errw, "init")
	if code != 0 || !strings.Contains(o, "tracker.base is the shipped one") {
		t.Errorf("init: %s", o)
	}
}

// `later` and `someday` are a view alone and a verb with an id — the pounce
// list flips a row with `tracker later <id>`; `due` is the view with days and
// the verb with an id and a date, the id unquoted.
func TestLaterSomedayDue(t *testing.T) {
	a, out, errw := app(t)
	code, o, _ := run(t, a, out, errw, "later", "ship the thing")
	if code != 0 || !strings.HasPrefix(o, "○ ship the thing  → when: later\nfile:///") {
		t.Errorf("later <id>: %d %s", code, o)
	}
	code, o, _ = run(t, a, out, errw, "someday", "ship", "the", "thing")
	if code != 0 || !strings.HasPrefix(o, "◌ ship the thing  → when: someday\nfile:///") {
		t.Errorf("someday <id>: %d %s", code, o)
	}
	code, o, _ = run(t, a, out, errw, "someday")
	if code != 0 || !strings.Contains(o, "hausfold/ship the thing") || !strings.Contains(o, "item(s)") {
		t.Errorf("someday view: %d %s", code, o)
	}
	code, o, _ = run(t, a, out, errw, "due", "ship", "the", "thing", "+3d")
	if code != 0 || !strings.HasPrefix(o, "ship the thing  → due 2026-09-23\nfile:///") {
		t.Errorf("due <id> <date>: %d %s", code, o)
	}
	code, o, _ = run(t, a, out, errw, "due", "7")
	if code != 0 || !strings.Contains(o, "due 2026-09-23") || !strings.Contains(o, "hausfold/ship the thing") {
		t.Errorf("due 7: %d %s", code, o)
	}
	code, o, _ = run(t, a, out, errw, "due", "ship the thing", "none")
	if code != 0 || !strings.HasPrefix(o, "ship the thing  → no due date\n") {
		t.Errorf("due <id> none: %d %s", code, o)
	}
	code, _, _ = run(t, a, out, errw, "when", "call", "mom", "tomorrow")
	if got, _ := os.ReadFile(a.V.Path("Personal/call mom")); code != 0 || !strings.Contains(string(got), "when: 2026-09-21\n") {
		t.Errorf("when unquoted: %d %s", code, got)
	}
	if code, _, _ := run(t, a, out, errw, "due", "call mom"); code != 2 {
		t.Errorf("due with an id and no date is usage, got %d", code)
	}
}
