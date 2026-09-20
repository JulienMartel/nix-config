// Package vault is the list itself: markdown notes under the Obsidian vault's
// tracker/ folder, read into an index and written back one atomic file at a
// time. Every verb the CLI and the TUI expose is a method here, so the two
// front ends cannot drift.
package vault

import (
	"os"
	"path/filepath"
	"strings"
	"time"
)

// DefaultVault is the notes vault on this Mac: iCloud, so the phone has it.
func DefaultVault() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Library", "Mobile Documents", "iCloud~md~obsidian", "Documents", "notes")
}

// Vault is one list: where the vault is, where tracker/ is inside it, and
// what day it is — injectable, so a test's Today does not move.
type Vault struct {
	Root string // the Obsidian vault
	Dir  string // the tracker folder, normally Root/tracker

	// DryRun makes every write print what it would do and touch nothing.
	DryRun bool
	// NoNormalize stops a read from folding arrived dates into `now` on disk.
	// The index still reads them as now; only the write is skipped.
	NoNormalize bool

	today time.Time
}

// Open resolves the vault from the environment: TRACKER_VAULT and TRACKER_DIR
// point it elsewhere (tests, a copy), DRY_RUN=1 stops writes, and
// TRACKER_TODAY pins the date for a reproducible run.
func Open() *Vault {
	v := &Vault{Root: os.Getenv("TRACKER_VAULT")}
	if v.Root == "" {
		v.Root = DefaultVault()
	}
	v.Dir = os.Getenv("TRACKER_DIR")
	if v.Dir == "" {
		v.Dir = filepath.Join(v.Root, "tracker")
	}
	v.DryRun = os.Getenv("DRY_RUN") == "1"
	if d := os.Getenv("TRACKER_TODAY"); IsDate(d) {
		v.today, _ = time.Parse(dateLayout, d)
	}
	return v
}

// New is a vault at a path, for tests and copies.
func New(root string) *Vault {
	return &Vault{Root: root, Dir: filepath.Join(root, "tracker")}
}

// SetToday pins the clock.
func (v *Vault) SetToday(d string) {
	v.today, _ = time.Parse(dateLayout, d)
}

// Now is the clock; Today its date as `when:` stores it.
func (v *Vault) Now() time.Time {
	if v.today.IsZero() {
		return time.Now()
	}
	return v.today
}

func (v *Vault) Today() string { return v.Now().Format(dateLayout) }

// Path is the absolute file of an id.
func (v *Vault) Path(id string) string { return filepath.Join(v.Dir, filepath.FromSlash(id)+".md") }

// ID is the id of an absolute path under the tracker dir: `folder/name`.
func (v *Vault) ID(path string) string {
	rel, err := filepath.Rel(v.Dir, path)
	if err != nil {
		return strings.TrimSuffix(filepath.Base(path), ".md")
	}
	return strings.TrimSuffix(filepath.ToSlash(rel), ".md")
}

// Exists reports whether tracker/ is there at all.
func (v *Vault) Exists() bool {
	st, err := os.Stat(v.Dir)
	return err == nil && st.IsDir()
}

// LogDir is where `archive` moves closed notes.
func (v *Vault) LogDir() string { return filepath.Join(v.Dir, "log") }
