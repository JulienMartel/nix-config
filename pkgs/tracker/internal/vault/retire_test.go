package vault

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// retirable closes the one open to-do in hausfold/ci so the project is
// finished, and hands back a fresh index.
func retirable(t *testing.T) (*Vault, *Index) {
	t.Helper()
	v, idx := migrated(t)
	it, err := v.Resolve(idx, "cache the store", false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := v.Done(it); err != nil {
		t.Fatal(err)
	}
	if idx, err = v.Load(); err != nil {
		t.Fatal(err)
	}
	return v, idx
}

func TestRetireProject(t *testing.T) {
	v, idx := retirable(t)
	before := mustRead(t, v.Path("hausfold/ci/ci"))
	r, err := v.RetireProject(idx, "hausfold/ci")
	if err != nil {
		t.Fatal(err)
	}

	// Every closed to-do went to log/, stamped the way archive stamps one.
	todo := mustRead(t, v.Path("log/cache the store"))
	if !strings.Contains(todo, "project: hausfold/ci\n") {
		t.Errorf("swept to-do lost its project stamp:\n%s", todo)
	}

	// The folder note followed it, demoted to a closed note.
	brief := mustRead(t, v.Path("log/ci"))
	for _, want := range []string{"when: later\n", "done: 2026-09-20\n", "project: hausfold/ci\n"} {
		if !strings.Contains(brief, want) {
			t.Errorf("demoted brief missing %q:\n%s", want, brief)
		}
	}
	for _, gone := range []string{"type: project", ProjectEmbed} {
		if strings.Contains(brief, gone) {
			t.Errorf("demoted brief kept %q:\n%s", gone, brief)
		}
	}
	if r.ID != "log/ci" {
		t.Errorf("report ends on %q, want log/ci", r.ID)
	}

	// The folder itself is gone, so the row goes with it.
	if _, err := os.Stat(filepath.Join(v.Dir, "hausfold", "ci")); !os.IsNotExist(err) {
		t.Error("the folder is still there")
	}
	if idx, err = v.Load(); err != nil {
		t.Fatal(err)
	}
	for _, f := range v.Folders(idx) {
		if f.Path == "hausfold/ci" || f.Path == "log" {
			t.Errorf("tracker projects still lists %q", f.Path)
		}
	}
	// The brief is a closed to-do now: it shows in Done on the day it closed.
	it, err := v.Resolve(idx, "log/ci", true)
	if err != nil || it.Done != "2026-09-20" || it.IsProject {
		t.Fatalf("the brief is not a closed to-do: %v %v", it, err)
	}

	// Reopen is the inverse: the project comes back whole.
	if _, err := v.Reopen(it); err != nil {
		t.Fatal(err)
	}
	if got := mustRead(t, v.Path("hausfold/ci/ci")); got != before {
		t.Errorf("reopen did not rebuild the folder note byte for byte:\nwant:\n%s\ngot:\n%s", before, got)
	}
	if idx, err = v.Load(); err != nil {
		t.Fatal(err)
	}
	if idx.FolderNote("hausfold/ci") == nil {
		t.Error("the rebuilt project has no folder note")
	}
}

func TestRetireProjectRefuses(t *testing.T) {
	v, idx := migrated(t)
	if _, err := v.RetireProject(idx, "hausfold/ci"); err == nil {
		t.Error("a project with an open to-do was retired")
	} else if !strings.Contains(err.Error(), "1 open to-do") {
		t.Errorf("unhelpful refusal: %v", err)
	}
	if _, err := v.RetireProject(idx, "hausfold"); err == nil {
		t.Error("a project with a sub-project was retired")
	}
	if _, err := v.RetireProject(idx, ""); err == nil {
		t.Error("the inbox was retired")
	}
	if _, err := v.RetireProject(idx, "no such project"); err == nil {
		t.Error("a folder that is not there was retired")
	}

	// A file the verb cannot move stops it before anything moves.
	v, idx = retirable(t)
	if err := os.WriteFile(filepath.Join(v.Dir, "hausfold", "ci", "shot.png"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := v.RetireProject(idx, "hausfold/ci"); err == nil {
		t.Error("a folder with an attachment was retired")
	}
	if _, err := os.Stat(v.Path("hausfold/ci/ci")); err != nil {
		t.Error("the refusal moved a note anyway")
	}
}

func TestRetireProjectDryRun(t *testing.T) {
	v, idx := retirable(t)
	before := mustRead(t, v.Path("hausfold/ci/ci"))
	v.DryRun = true
	if _, err := v.RetireProject(idx, "hausfold/ci"); err != nil {
		t.Fatal(err)
	}
	if got := mustRead(t, v.Path("hausfold/ci/ci")); got != before {
		t.Error("dry run wrote the folder note")
	}
	if _, err := os.Stat(v.Path("log/ci")); !os.IsNotExist(err) {
		t.Error("dry run moved a note")
	}
}

// A folder note swept into log/ by hand — the only way to retire a project
// before this verb existed — must not put a `log` row on the project tree.
func TestFoldersIgnoreLog(t *testing.T) {
	v, _ := migrated(t)
	if err := os.WriteFile(v.Path("log/an old project"),
		[]byte("---\ntype: project\ncreated: 2026-01-01\n---\nbrief\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	idx, err := v.Load()
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range v.Folders(idx) {
		if f.Path == "log" {
			t.Error("log/ is listed as a project")
		}
	}
}
