package vault

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	tracker "github.com/julienmartel/tracker"
)

func TestBaseGolden(t *testing.T) {
	want, err := os.ReadFile(filepath.Join("..", "..", "testdata", "tracker.base.golden"))
	if err != nil {
		t.Fatal(err)
	}
	if string(tracker.Base) != string(want) {
		t.Error("assets/tracker.base drifted from testdata/tracker.base.golden")
	}
	v := fixture(t)
	if _, err := v.Init(true); err != nil {
		t.Fatal(err)
	}
	if got := mustRead(t, filepath.Join(v.Dir, "tracker.base")); got != string(want) {
		t.Error("init --force did not write the shipped base byte for byte")
	}
}

func TestMigrate(t *testing.T) {
	v := fixture(t)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	r, stats, err := v.Migrate()
	if err != nil {
		t.Fatal(err)
	}
	want := map[string]int{
		"type: todo dropped":                                      12,
		"type: area → type: project":                              1,
		"status: open + heading: now → when: now":                 1,
		"status: open + when: <date> kept":                        2,
		"status: open → when: later":                              4,
		"status: someday → when: someday":                         1,
		"status: done → done: kept":                               3,
		"status: done|canceled with no date → stamped from mtime": 1,
		"status: canceled → dropped:":                             1,
		"heading: now|later folded into when":                     2,
		"heading → tag":                                           1,
		"deadline → due":                                          1,
		"evening dropped":                                         1,
		"area dropped":                                            2,
		"project dropped (outside log/)":                          1,
		"inbox/ → tracker/":                                       2,
		"folder note: ```base → embed":                            4,
		"folder note: repo seeded":                                2,
		"notes untouched":                                         1,
	}
	for rule, n := range want {
		if stats.Counts[rule] != n {
			t.Errorf("%s: %d, want %d", rule, stats.Counts[rule], n)
		}
	}
	if !strings.HasPrefix(r.Lines[0], "backed up: ") {
		t.Errorf("no backup line: %q", r.Lines[0])
	}
	bak := strings.TrimPrefix(r.Lines[0], "backed up: ")
	if st, err := os.Stat(bak); err != nil || st.Size() == 0 {
		t.Errorf("backup missing: %s", bak)
	}
	// The shapes the table promises.
	ship := mustRead(t, v.Path("hausfold/ship the thing"))
	if !strings.HasPrefix(ship, "---\nwhen: now\ntags:\n  - fable\ncreated: 2026-09-15\n---\n") {
		t.Errorf("ship the thing:\n%s", ship)
	}
	cache := mustRead(t, v.Path("hausfold/ci/cache the store"))
	if !strings.Contains(cache, "when: later\n") || !strings.Contains(cache, "tags:\n  - build\n") || strings.Contains(cache, "heading") {
		t.Errorf("cache the store:\n%s", cache)
	}
	notes := mustRead(t, v.Path("organize notes"))
	if !strings.Contains(notes, "due: 2026-12-01\n") || strings.Contains(notes, "evening") || strings.Contains(notes, "deadline") {
		t.Errorf("organize notes:\n%s", notes)
	}
	if _, err := os.Stat(filepath.Join(v.Dir, "inbox")); !os.IsNotExist(err) {
		t.Error("inbox/ should be gone")
	}
	dropped := mustRead(t, v.Path("log/dropped thing"))
	if !strings.Contains(dropped, "dropped: 2026-02-01\n") || strings.Contains(dropped, "done:") || !strings.Contains(dropped, "project: Personal") {
		t.Errorf("dropped thing:\n%s", dropped)
	}
	half := mustRead(t, v.Path("nas/half closed"))
	if !strings.Contains(half, "done: 20") || strings.Contains(half, "status") {
		t.Errorf("half closed:\n%s", half)
	}
	disk := mustRead(t, v.Path("nas/replace disk"))
	if strings.Contains(disk, "project:") || !strings.Contains(disk, "done: 2026-09-01") {
		t.Errorf("replace disk:\n%s", disk)
	}
	haus := mustRead(t, v.Path("hausfold/hausfold"))
	if !strings.Contains(haus, "repo: \"~/code/workshop\"\n") || !strings.Contains(haus, ProjectEmbed) || strings.Contains(haus, "```base") || strings.Contains(haus, "area:") {
		t.Errorf("hausfold folder note:\n%s", haus)
	}
	personal := mustRead(t, v.Path("Personal/Personal"))
	if !strings.HasPrefix(personal, "---\ntype: project\n---\n"+ProjectEmbed+"\n") {
		t.Errorf("Personal folder note:\n%s", personal)
	}
	v2 := mustRead(t, v.Path("Personal/already v2"))
	if !strings.Contains(v2, "color: blue\n") {
		t.Errorf("unknown key lost:\n%s", v2)
	}
	types := mustRead(t, filepath.Join(v.Root, ".obsidian", "types.json"))
	for _, old := range []string{`"status"`, `"heading"`, `"deadline"`, `"evening"`, `"area"`, `"": `} {
		if strings.Contains(types, old) {
			t.Errorf("types.json still has %s", old)
		}
	}
	for _, want := range []string{`"when": "text"`, `"due": "date"`, `"dropped": "date"`, `"lane": "text"`, `"aliases": "aliases"`} {
		if !strings.Contains(types, want) {
			t.Errorf("types.json lacks %s", want)
		}
	}
	plugins := mustRead(t, filepath.Join(v.Root, ".obsidian", "community-plugins.json"))
	if !strings.Contains(plugins, `"tracker"`) || !strings.Contains(plugins, `"obsidian-style-settings"`) {
		t.Errorf("community-plugins.json: %s", plugins)
	}
	for _, f := range []string{"main.js", "manifest.json"} {
		if _, err := os.Stat(filepath.Join(v.Root, ".obsidian", "plugins", "tracker", f)); err != nil {
			t.Errorf("plugin file %s not installed", f)
		}
	}

	// Idempotent: a second run touches nothing.
	_, stats2, err := v.Migrate()
	if err != nil {
		t.Fatal(err)
	}
	for rule, n := range stats2.Counts {
		if rule == "notes untouched" {
			continue
		}
		if n != 0 {
			t.Errorf("second migrate: %s = %d", rule, n)
		}
	}

	// Today is what `when: now` and an arrived date say.
	idx, err := v.Load()
	if err != nil {
		t.Fatal(err)
	}
	var today []string
	for _, it := range idx.Open() {
		if it.Bucket == BucketNow {
			today = append(today, it.ID)
		}
	}
	if strings.Join(today, "|") != "buy cat food|hausfold/ship the thing" {
		t.Errorf("today = %v", today)
	}
	if got := mustRead(t, v.Path("buy cat food")); !strings.Contains(got, "when: now\n") {
		t.Errorf("arrived date not folded on disk:\n%s", got)
	}
}

func TestMigrateDryRunTouchesNothing(t *testing.T) {
	v := fixture(t)
	v.DryRun = true
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	before := mustRead(t, v.Path("inbox/buy cat food"))
	if _, _, err := v.Migrate(); err != nil {
		t.Fatal(err)
	}
	if got := mustRead(t, v.Path("inbox/buy cat food")); got != before {
		t.Error("dry run wrote a note")
	}
}

func migrated(t *testing.T) (*Vault, *Index) {
	t.Helper()
	v := fixture(t)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	if _, _, err := v.Migrate(); err != nil {
		t.Fatal(err)
	}
	idx, err := v.Load()
	if err != nil {
		t.Fatal(err)
	}
	return v, idx
}

func TestResolve(t *testing.T) {
	v, idx := migrated(t)
	for _, q := range []string{"hausfold/ship the thing", "tracker/hausfold/ship the thing.md", "SHIP THE", "ship the thing"} {
		it, err := v.Resolve(idx, q, false)
		if err != nil || it.ID != "hausfold/ship the thing" {
			t.Errorf("Resolve(%q) = %v, %v", q, it, err)
		}
	}
	// Title matches too, and case does not matter.
	if it, err := v.Resolve(idx, "with colon", false); err != nil || it.ID != "Personal/Title with colon" {
		t.Errorf("title substring: %v %v", it, err)
	}
	// "the" is in several ids: ambiguous, candidates listed.
	_, err := v.Resolve(idx, "the", false)
	amb, ok := err.(*AmbiguousError)
	if !ok || len(amb.Candidates) < 2 {
		t.Fatalf("want ambiguity, got %v", err)
	}
	// Closed notes are only for reopen, and log/ is implied there.
	if _, err := v.Resolve(idx, "old thing", false); err == nil {
		t.Error("a closed note matched an open search")
	}
	if it, err := v.Resolve(idx, "old thing", true); err != nil || it.ID != "log/old thing" {
		t.Errorf("reopen resolve: %v %v", it, err)
	}
	if _, err := v.Resolve(idx, "nothing like this", false); err == nil {
		t.Error("no match should refuse")
	}
	if ExitCode(err) != 1 {
		t.Error("ambiguity exits 1")
	}
	// Folders.
	for q, want := range map[string]string{"": "", "inbox": "", "hausfold": "hausfold", "CI": "hausfold/ci", "pers": "Personal"} {
		if got, err := v.ResolveFolder(idx, q); err != nil || got != want {
			t.Errorf("ResolveFolder(%q) = %q, %v", q, got, err)
		}
	}
	if _, err := v.ResolveFolder(idx, "log"); err == nil {
		t.Error("log is not a project")
	}
}

func TestVerbs(t *testing.T) {
	v, idx := migrated(t)
	it, _ := v.Resolve(idx, "write docs", false)
	r, err := v.Done(it)
	if err != nil {
		t.Fatal(err)
	}
	if got := mustRead(t, r.Path); !strings.Contains(got, "done: 2026-09-20\n") {
		t.Errorf("done:\n%s", got)
	}
	if _, err := v.Done(it); err == nil {
		t.Error("done twice should refuse")
	}
	// Undo puts the bytes back.
	if err := r.Change.Undo(); err != nil {
		t.Fatal(err)
	}
	if got := mustRead(t, r.Path); strings.Contains(got, "done:") {
		t.Error("undo did not restore")
	}

	idx, _ = v.Load()
	it, _ = v.Resolve(idx, "write docs", false)
	if r, err = v.Move(it, "Personal"); err != nil || r.ID != "Personal/write docs" {
		t.Fatalf("move: %v %v", r, err)
	}
	if _, err := os.Stat(v.Path("Personal/write docs")); err != nil {
		t.Error("moved file missing")
	}
	if err := r.Change.Undo(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(v.Path("hausfold/write docs")); err != nil {
		t.Error("undo of a move did not put the file back")
	}
	if _, err := os.Stat(v.Path("Personal/write docs")); err == nil {
		t.Error("undo of a move left the copy")
	}

	idx, _ = v.Load()
	it, _ = v.Resolve(idx, "write docs", false)
	if r, err = v.Rename(it, "Write: the docs"); err != nil || r.ID != "hausfold/Write the docs" {
		t.Fatalf("rename: %v %v", r, err)
	}
	if got := mustRead(t, r.Path); !strings.Contains(got, `title: "Write: the docs"`) {
		t.Errorf("rename title:\n%s", got)
	}
	idx, _ = v.Load()
	it, _ = v.Resolve(idx, "Write the docs", false)
	if r, err = v.Tag(it, []string{"+fable", "haus.x", "-fable"}); err != nil || strings.Join(it.Note.FM.List("tags"), ",") != "haus-x" {
		t.Fatalf("tag: %v %v", it.Note.FM.List("tags"), err)
	}
	if r, err = v.Append(it, "a note"); err != nil || !strings.HasSuffix(mustRead(t, r.Path), "\na note\n") {
		t.Fatalf("append: %v", err)
	}
	if _, err = v.SetDue(it, "2026-10-01"); err != nil || it.Note.FM.Get("due") != "2026-10-01" {
		t.Fatal("due")
	}
	if _, err = v.SetWhen(it, Someday); err != nil || it.Note.FM.Get("when") != Someday {
		t.Fatal("when")
	}

	// Reopen out of log/ goes back to the stamped project and loses the stamp.
	idx, _ = v.Load()
	old, _ := v.Resolve(idx, "old thing", true)
	if r, err = v.Reopen(old); err != nil || r.ID != "hausfold/old thing" {
		t.Fatalf("reopen: %v %v", r, err)
	}
	if got := mustRead(t, r.Path); strings.Contains(got, "project:") || strings.Contains(got, "done:") {
		t.Errorf("reopened note:\n%s", got)
	}

	// Add, with a title that needs sanitizing and a checklist.
	r, err = v.Add(NewTodo{Title: "buy: milk?", Folder: "Personal", When: Now, Due: "2026-09-25", Tags: []string{"errand"}, Notes: "2%", Checklist: []string{"a", "b"}})
	if err != nil {
		t.Fatal(err)
	}
	want := "---\nwhen: now\ndue: 2026-09-25\ntags:\n  - errand\ncreated: 2026-09-20\ntitle: \"buy: milk?\"\n---\n2%\n\n- [ ] a\n- [ ] b\n"
	if got := mustRead(t, r.Path); got != want || r.ID != "Personal/buy milk" {
		t.Errorf("add wrote %q as %q", got, r.ID)
	}
	if _, err := v.Add(NewTodo{Title: "x", Folder: "nowhere"}); err == nil {
		t.Error("add into a missing project should refuse")
	}
	// A second add with the same name gets (2).
	r, _ = v.Add(NewTodo{Title: "buy milk", Folder: "Personal"})
	if r.ID != "Personal/buy milk (2)" {
		t.Errorf("collision id %q", r.ID)
	}

	// Project add + promote.
	r, err = v.AddProject(NewProject{Name: "kitchen", Parent: "Personal", Repo: "~/x", Notes: "brief", Todos: []string{"measure", "quote"}})
	if err != nil || r.ID != "Personal/kitchen/kitchen" {
		t.Fatalf("project add: %v %v", r, err)
	}
	if got := mustRead(t, r.Path); got != "---\ntype: project\ncreated: 2026-09-20\nrepo: \"~/x\"\n---\nbrief\n\n"+ProjectEmbed+"\n" {
		t.Errorf("folder note:\n%s", got)
	}
	idx, _ = v.Load()
	if len(idx.Get("Personal/kitchen/measure").ID) == 0 {
		t.Error("first to-dos missing")
	}
	q, _ := v.Resolve(idx, "quote", false)
	if r, err = v.Promote(q); err != nil || r.ID != "Personal/kitchen/quote/quote" {
		t.Fatalf("promote: %v %v", r, err)
	}
	if got := mustRead(t, r.Path); !strings.Contains(got, "type: project") || strings.Contains(got, "when:") || !strings.Contains(got, ProjectEmbed) {
		t.Errorf("promoted:\n%s", got)
	}
	idx, _ = v.Load()
	if got := idx.RepoFor(idx.Get("Personal/kitchen/measure")); got != "~/x" {
		t.Errorf("RepoFor = %q", got)
	}
}

func TestArchive(t *testing.T) {
	v, idx := migrated(t)
	// replace disk closed 2026-09-01: 19 days ago, so 30 keeps it, 10 moves it.
	r, err := v.Archive(idx, 30)
	if err != nil || !strings.Contains(strings.Join(r.Lines, "\n"), "nothing to archive") {
		t.Fatalf("archive 30: %v %v", r.Lines, err)
	}
	v.DryRun = true
	r, _ = v.Archive(idx, 10)
	if _, err := os.Stat(v.Path("nas/replace disk")); err != nil || !strings.Contains(r.Lines[0], "nas/replace disk") {
		t.Errorf("dry run: %v", r.Lines)
	}
	v.DryRun = false
	idx, _ = v.Load()
	r, err = v.Archive(idx, 10)
	if err != nil || r.ID != "" {
		t.Fatal(err)
	}
	got := mustRead(t, v.Path("log/replace disk"))
	if !strings.Contains(got, "project: nas\n") {
		t.Errorf("archived note:\n%s", got)
	}
}

func TestLinks(t *testing.T) {
	v := New("/Users/me/vault notes")
	p := v.Path("hausfold/ship the #thing")
	if got := FileURL(p); got != "file:///Users/me/vault%20notes/tracker/hausfold/ship%20the%20%23thing.md" {
		t.Errorf("FileURL %q", got)
	}
	if got := v.ObsidianURL(p); got != "obsidian://open?vault=vault%20notes&file=tracker%2Fhausfold%2Fship%20the%20%23thing.md" {
		t.Errorf("ObsidianURL %q", got)
	}
}

func TestWhen(t *testing.T) {
	v := New(t.TempDir())
	v.SetToday("2026-09-20")
	cases := map[string]string{"today": "now", "tomorrow": "2026-09-21", "+3d": "2026-09-23", "2020-01-01": "now", "2027-01-01": "2027-01-01", "now": "now", "later": "later", "someday": "someday", "anytime": "later"}
	for in, want := range cases {
		if got, err := ParseWhen(in, v.Now()); err != nil || got != want {
			t.Errorf("ParseWhen(%q) = %q, %v", in, got, err)
		}
	}
	if _, err := ParseWhen("nope", v.Now()); ExitCode(err) != 2 {
		t.Error("a bad when is a usage error")
	}
	if Bucket("2026-12-01") != BucketScheduled || Bucket("") != BucketLater || Bucket("garbage") != BucketLater {
		t.Error("bucket")
	}
}

// A case-only rename on the Mac's case-insensitive disk must not step aside to
// ` (2)`: the only file at the new name is the note itself.
func TestRenameCaseOnly(t *testing.T) {
	v, idx := migrated(t)
	it, _ := v.Resolve(idx, "write docs", false)
	r, err := v.Rename(it, "Write Docs")
	if err != nil || r.ID != "hausfold/Write Docs" {
		t.Fatalf("rename: %v %v", r, err)
	}
	names, _ := filepath.Glob(filepath.Join(v.Dir, "hausfold", "*ocs*.md"))
	if len(names) != 1 || filepath.Base(names[0]) != "Write Docs.md" {
		t.Errorf("on disk: %v", names)
	}
}
