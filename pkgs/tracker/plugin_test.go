package tracker

import (
	"io/fs"
	"os/exec"
	"strings"
	"testing"
)

// The plugin is these two files and nothing else: `tracker init` copies every
// embedded file into the vault, so a test file or an editor's leftovers
// getting embedded would ship them to the phone as part of the plugin.
func TestPluginShipsOnlyThePlugin(t *testing.T) {
	var got []string
	err := fs.WalkDir(Plugin, "obsidian-plugin", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		got = append(got, p)
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if want := "obsidian-plugin/main.js obsidian-plugin/manifest.json"; strings.Join(got, " ") != want {
		t.Errorf("embedded %v, want %s", got, want)
	}
}

// The plugin's own tests: node runs them, and they assert the note it writes
// against testdata/capture.golden.md — the same file the CLI is held to in
// internal/vault/capture_test.go. Without node there is nothing to run.
func TestPluginJS(t *testing.T) {
	node, err := exec.LookPath("node")
	if err != nil {
		t.Skip("no node — nix shell nixpkgs#go nixpkgs#nodejs -c go test ./...")
	}
	out, err := exec.Command(node, "--test", "obsidian-plugin/main.test.js").CombinedOutput()
	if err != nil {
		t.Fatalf("node --test obsidian-plugin/main.test.js: %v\n%s", err, out)
	}
}
