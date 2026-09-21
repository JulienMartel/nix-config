package vault

import (
	"os"
	"path/filepath"
	"testing"
)

// captureGolden is the note the phone's capture makes: a link shared from
// Safari, landing unfiled. The Obsidian plugin's own test asserts the same
// bytes (obsidian-plugin/main.test.js), so the two halves of tracker cannot
// drift on what a to-do looks like.
func captureGolden(t *testing.T) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("..", "..", "testdata", "capture.golden.md"))
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

// The title as shared, and what `tracker add` and the plugin both name it.
const (
	captureTitle = "Why Nix flakes: a field guide | example.com"
	captureName  = "Why Nix flakes a field guide example.com"
)

func TestCaptureAddMatchesGolden(t *testing.T) {
	v := fixture(t)
	r, err := v.Add(NewTodo{
		Title: captureTitle,
		When:  Later,
		Due:   "2026-09-30",
		Tags:  Tags("read, #example.com"),
		Notes: "https://example.com/nix-flakes",
	})
	if err != nil {
		t.Fatal(err)
	}
	if want := filepath.Join(v.Dir, captureName+".md"); r.Path != want {
		t.Errorf("path = %q, want %q", r.Path, want)
	}
	if got := mustRead(t, r.Path); got != captureGolden(t) {
		t.Errorf("add wrote\n%s\nwant\n%s", got, captureGolden(t))
	}
}

// A note the phone wrote straight into the vault — the share-sheet Shortcut
// saves this file into tracker/ over iCloud, with no Mac and no Obsidian in
// the loop. It has to read as an ordinary unfiled to-do, and reading it must
// not rewrite it: a churned byte here is an iCloud conflict later.
func TestCaptureFromPhoneReadsAndDoesNotChurn(t *testing.T) {
	v := fixture(t)
	path := filepath.Join(v.Dir, captureName+".md")
	golden := captureGolden(t)
	if err := os.WriteFile(path, []byte(golden), 0o644); err != nil {
		t.Fatal(err)
	}
	idx, err := v.Load()
	if err != nil {
		t.Fatal(err)
	}
	it := idx.Get(captureName)
	if it == nil {
		t.Fatalf("the phone's note is not in the index: %s", captureName)
	}
	switch {
	case it.Title != captureTitle:
		t.Errorf("title = %q, want %q", it.Title, captureTitle)
	case it.When != Later || it.Bucket != BucketLater:
		t.Errorf("when = %q / %q, want later", it.When, it.Bucket)
	case it.Project != "" || it.Folder != "":
		t.Errorf("project = %q / folder = %q, want unfiled", it.Project, it.Folder)
	case it.Due != "2026-09-30":
		t.Errorf("due = %q", it.Due)
	case len(it.Tags) != 2 || it.Tags[0] != "read" || it.Tags[1] != "example-com":
		t.Errorf("tags = %v", it.Tags)
	case it.Created != "2026-09-20":
		t.Errorf("created = %q", it.Created)
	case it.Body() != "https://example.com/nix-flakes\n":
		t.Errorf("body = %q", it.Body())
	case !it.Open():
		t.Error("the note reads as closed")
	}
	if it.Note.Changed() {
		t.Errorf("reading the phone's note would rewrite it:\n%s", it.Note.Bytes())
	}
	if got := mustRead(t, path); got != golden {
		t.Errorf("the file changed on disk:\n%s", got)
	}
}

// The one file the phone writes by hand and the Mac must still understand:
// nothing but a body. `when` is absent, which the README says reads as later.
func TestCaptureBareNoteReadsAsLater(t *testing.T) {
	v := fixture(t)
	path := filepath.Join(v.Dir, "shared from the phone.md")
	if err := os.WriteFile(path, []byte("https://example.com/\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	idx, err := v.Load()
	if err != nil {
		t.Fatal(err)
	}
	it := idx.Get("shared from the phone")
	if it == nil {
		t.Fatal("a body-only note is not in the index")
	}
	if it.When != Later || !it.Open() || it.Project != "" {
		t.Errorf("when = %q, open = %v, project = %q", it.When, it.Open(), it.Project)
	}
	if it.Note.Changed() {
		t.Error("reading a body-only note would rewrite it")
	}
}
