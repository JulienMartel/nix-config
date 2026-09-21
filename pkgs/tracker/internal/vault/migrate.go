package vault

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

// ── migrate: the Things-shaped tracker becomes the four-property one ─────────
//
// Idempotent by construction: every rule keys on something the new shape does
// not have (`type: todo`, `status`, `heading`, `deadline`, `evening`, a
// ```base block), so a note already in v2 goes through untouched, and the
// counts on a second run are all zero.

// The folder notes that get a `repo:` seeded, because their lanes have one.
var seedRepos = map[string]string{
	"hausfold": "~/code/workshop",
	"hausfold CI cut the gate to what it protects": "~/code/workshop",
	"nas": "~/code/qnap-mediastack",
}

var baseBlock = regexp.MustCompile("(?s)```base\n.*?```[ \t]*\n?")

// MigrateStats is the count per rule, in table order.
type MigrateStats struct {
	Rules  []string
	Counts map[string]int
}

func (s *MigrateStats) add(rule string) {
	if _, ok := s.Counts[rule]; !ok {
		s.Rules = append(s.Rules, rule)
	}
	s.Counts[rule]++
}

// migrateRules is the table's order, so the report reads like the README.
var migrateRules = []string{
	"type: todo dropped",
	"type: area → type: project",
	"status: open + heading: now → when: now",
	"status: open + when: <date> kept",
	"status: open → when: later",
	"status: someday → when: someday",
	"status: done → done: kept",
	"status: canceled → dropped:",
	"status: done|canceled with no date → stamped from mtime",
	"heading: now|later folded into when",
	"heading → tag",
	"deadline → due",
	"evening dropped",
	"area dropped",
	"project dropped (outside log/)",
	"inbox/ → tracker/",
	"folder note: ```base → embed",
	"folder note: embed added",
	"folder note: repo seeded",
	"notes rewritten",
	"notes untouched",
}

// Migrate backs tracker/ up, converts every note, then runs init.
func (v *Vault) Migrate() (*Report, *MigrateStats, error) {
	r := &Report{}
	stats := &MigrateStats{Counts: map[string]int{}}
	for _, rule := range migrateRules {
		stats.Counts[rule] = 0
		stats.Rules = append(stats.Rules, rule)
	}
	if v.DryRun {
		r.say("dry run — would back up %s to %s", v.Dir, v.backupPath())
	} else {
		bak, err := v.Backup()
		if err != nil {
			return nil, nil, fmt.Errorf("backup: %w", err)
		}
		r.say("backed up: %s", bak)
	}
	saved := v.NoNormalize
	v.NoNormalize = true
	idx, err := v.Load()
	v.NoNormalize = saved
	if err != nil {
		return nil, nil, err
	}
	var inbox []*Item
	for _, it := range idx.Items {
		n := it.Note
		if it.IsProject {
			v.migrateFolderNote(n, stats)
		} else {
			v.migrateTodo(n, stats)
		}
		if n.Changed() {
			stats.add("notes rewritten")
			if err := v.save(r, n); err != nil {
				return nil, nil, err
			}
		} else {
			stats.add("notes untouched")
		}
		if it.Folder == "inbox" {
			inbox = append(inbox, it)
		}
	}
	for _, it := range inbox {
		stats.add("inbox/ → tracker/")
		if err := v.move(r, it.Note, v.Dir); err != nil {
			return nil, nil, err
		}
	}
	if !v.DryRun {
		// Empty now, or never there. A folder note for inbox is not a thing.
		_ = os.Remove(filepath.Join(v.Dir, "inbox"))
	}
	for _, rule := range stats.Rules {
		r.say("%4d  %s", stats.Counts[rule], rule)
	}
	init, err := v.Init(true)
	if err != nil {
		return nil, nil, err
	}
	r.Lines = append(r.Lines, init.Lines...)
	r.Path = v.Dir
	return r, stats, nil
}

func (v *Vault) migrateFolderNote(n *Note, s *MigrateStats) {
	fm := n.FM
	if fm.Get("type") == "area" {
		fm.Set("type", "project")
		s.add("type: area → type: project")
	}
	if fm.Has("area") {
		fm.Delete("area")
		s.add("area dropped")
	}
	if baseBlock.MatchString(n.Body) {
		n.Body = strings.TrimRight(baseBlock.ReplaceAllString(n.Body, ProjectEmbed+"\n"), "\n") + "\n"
		s.add("folder note: ```base → embed")
	}
	if !strings.Contains(n.Body, ProjectEmbed) {
		body := strings.TrimRight(n.Body, "\n")
		if body != "" {
			body += "\n\n"
		}
		n.Body = body + ProjectEmbed + "\n"
		s.add("folder note: embed added")
	}
	if repo, ok := seedRepos[n.Folder()]; ok && !fm.Has("repo") {
		fm.Set("repo", repo)
		s.add("folder note: repo seeded")
	}
}

func (v *Vault) migrateTodo(n *Note, s *MigrateStats) {
	fm := n.FM
	if fm.Get("type") == "todo" {
		fm.Delete("type")
		s.add("type: todo dropped")
	}
	status := fm.Get("status")
	heading := fm.Get("heading")
	inLog := n.Folder() == "log" || strings.HasPrefix(n.Folder(), "log/")
	// `status` becomes `when` on the line it was on.
	setWhen := func(w string) {
		fm.Rename("status", "when")
		fm.Set("when", w)
	}
	switch status {
	case "open":
		switch {
		case heading == "now":
			setWhen(Now)
			s.add("status: open + heading: now → when: now")
		case IsDate(fm.Get("when")):
			fm.Rename("status", "when")
			s.add("status: open + when: <date> kept")
		default:
			setWhen(Later)
			s.add("status: open → when: later")
		}
	case "someday":
		setWhen(Someday)
		s.add("status: someday → when: someday")
	case "done":
		fm.Delete("status")
		if fm.Get("done") == "" {
			// Half-closed in Obsidian: the status flipped, no date. The day
			// the file was last written is the best guess at when.
			fm.Set("done", v.closedOn(n.Path))
			s.add("status: done|canceled with no date → stamped from mtime")
		}
		if fm.Get("when") == "" {
			fm.Set("when", Later)
		}
		s.add("status: done → done: kept")
	case "canceled", "cancelled":
		d := fm.Get("done")
		if d == "" {
			d = v.closedOn(n.Path)
			s.add("status: done|canceled with no date → stamped from mtime")
		}
		fm.Delete("status")
		fm.Delete("done")
		fm.Set("dropped", d)
		if fm.Get("when") == "" {
			fm.Set("when", Later)
		}
		s.add("status: canceled → dropped:")
	case "":
	default:
		// Something hand-typed: open is the safe reading.
		setWhen(Normalize(fm.Get("when"), v.Now()))
		s.add("status: open → when: later")
	}
	switch {
	case heading == "now" || heading == "later":
		fm.Delete("heading")
		s.add("heading: now|later folded into when")
	case heading != "":
		tag := strings.ToLower(SanitizeTag(heading))
		tags := fm.List("tags")
		if tag != "" && !contains(tags, tag) {
			tags = append(tags, tag)
		}
		fm.SetList("tags", tags)
		fm.Delete("heading")
		s.add("heading → tag")
	}
	if fm.Has("deadline") {
		fm.Rename("deadline", "due")
		s.add("deadline → due")
	}
	if fm.Has("evening") {
		fm.Delete("evening")
		s.add("evening dropped")
	}
	if fm.Has("project") && !inLog {
		fm.Delete("project")
		s.add("project dropped (outside log/)")
	}
}

// closedOn is the day a half-closed note was last written, clamped to today,
// and today when the file will not say.
func (v *Vault) closedOn(path string) string {
	st, err := os.Stat(path)
	if err != nil {
		return v.Today()
	}
	d := st.ModTime().Format(dateLayout)
	if d > v.Today() {
		d = v.Today()
	}
	return d
}

// backupDir is ~/.cache/tracker (XDG_CACHE_HOME when set).
func backupDir() string {
	if x := os.Getenv("XDG_CACHE_HOME"); x != "" {
		return filepath.Join(x, "tracker")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".cache", "tracker")
}

// backupPath is stamped from the wall clock, not the pinned date: a backup's
// name has to be unique whatever a test says today is.
func (v *Vault) backupPath() string {
	return filepath.Join(backupDir(), "backup-"+time.Now().Format("20060102-150405")+".tgz")
}

// Backup writes tracker/ as a gzipped tar, paths relative to the vault so it
// unpacks beside the original.
func (v *Vault) Backup() (string, error) {
	out := v.backupPath()
	if err := os.MkdirAll(filepath.Dir(out), 0o755); err != nil {
		return "", err
	}
	f, err := os.Create(out)
	if err != nil {
		return "", err
	}
	defer f.Close()
	gz := gzip.NewWriter(f)
	tw := tar.NewWriter(gz)
	var files []string
	err = filepath.WalkDir(v.Dir, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() {
			files = append(files, p)
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	sort.Strings(files)
	for _, p := range files {
		st, err := os.Stat(p)
		if err != nil {
			return "", err
		}
		hdr, err := tar.FileInfoHeader(st, "")
		if err != nil {
			return "", err
		}
		rel, _ := filepath.Rel(filepath.Dir(v.Dir), p)
		hdr.Name = filepath.ToSlash(rel)
		if err := tw.WriteHeader(hdr); err != nil {
			return "", err
		}
		in, err := os.Open(p)
		if err != nil {
			return "", err
		}
		_, err = io.Copy(tw, in)
		in.Close()
		if err != nil {
			return "", err
		}
	}
	if err := tw.Close(); err != nil {
		return "", err
	}
	if err := gz.Close(); err != nil {
		return "", err
	}
	return out, nil
}
