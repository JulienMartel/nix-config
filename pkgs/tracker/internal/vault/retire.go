package vault

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// ── project done: a finished project leaves the tree ─────────────────────────
//
// `archive` sweeps closed to-dos and never touches a folder note, and
// `projects` walks the directory tree — so a project whose work is all done
// keeps its row for good, at 0 open. This is the verb that ends one: every
// closed to-do goes to log/ the way archive sends it, the folder note is
// demoted to a closed note and follows it, and the empty folder goes. The
// brief keeps its whole body and shows up in Done on the day it closed.
//
// Reversal is one verb: `reopen` puts the brief back in a re-made folder,
// and restores the folder-note shape it is landing back into.

// dsStore is the only thing in a project folder this verb will remove: Finder
// writes it, nobody reads it, and it is all that usually stands between an
// emptied folder and `os.Remove`.
const dsStore = ".DS_Store"

// RetireProject closes a finished project. It refuses one that still has open
// to-dos or a sub-project: those are a decision, not a sweep.
func (v *Vault) RetireProject(idx *Index, folder string) (*Report, error) {
	if folder == "" {
		return nil, RefusedError("the inbox is not a project")
	}
	dir := filepath.Join(v.Dir, filepath.FromSlash(folder))
	if st, err := os.Stat(dir); err != nil || !st.IsDir() {
		return nil, RefusedError(quote(folder) + " is not a project folder")
	}
	for _, f := range v.Folders(idx) {
		if strings.HasPrefix(f.Path, folder+"/") {
			return nil, RefusedError(f.Path + " is a sub-project — retire it first")
		}
	}
	var open, closed []*Item
	for _, it := range idx.Items {
		if it.Folder != folder || it.IsProject {
			continue
		}
		if it.Open() {
			open = append(open, it)
		} else {
			closed = append(closed, it)
		}
	}
	if n := len(open); n > 0 {
		return nil, RefusedError(fmt.Sprintf("%s has %d open to-do%s — close or drop %s first",
			folder, n, plural(n), theyThem(n)))
	}
	note := idx.FolderNote(folder)
	if note != nil {
		if k := toDoField(note.Note); k != "" {
			return nil, RefusedError(note.ID + " carries a to-do's " + k +
				": — open work the index reads as a folder note, not a brief. Rename it first")
		}
	}
	if err := v.retireLeftovers(dir, closed, note); err != nil {
		return nil, err
	}
	sort.Slice(closed, func(i, j int) bool { return closed[i].ID < closed[j].ID })

	r := &Report{}
	for _, it := range closed {
		if err := v.logNote(r, it.Note, folder); err != nil {
			return nil, err
		}
		r.say("%s %s  → %s", Glyph(State(it)), it.ID, it.Note.ID)
	}
	if note != nil {
		n := note.Note
		n.FM.Delete("type")
		if !n.FM.Has("when") {
			n.FM.Set("when", "later")
		}
		n.FM.Set("done", v.Today())
		n.Body = withoutEmbed(n.Body)
		if err := v.logNote(r, n, folder); err != nil {
			return nil, err
		}
		r.say("✓ %s  → %s  (the brief, closed %s)", note.ID, n.ID, v.Today())
		r.ID, r.Path = n.ID, n.Path
	}
	if !v.DryRun {
		// Every note has moved by now, so a failure here leaves the folder
		// empty rather than half swept — say that, because re-running the
		// verb on an emptied folder is all it takes to finish the job.
		if err := os.Remove(filepath.Join(dir, dsStore)); err != nil && !os.IsNotExist(err) {
			return nil, halfRetired(err, folder)
		}
		if err := os.Remove(dir); err != nil {
			return nil, halfRetired(err, folder)
		}
	}
	if v.DryRun {
		r.say("%d note%s would leave %s/ — dry run, nothing written", len(closed)+btoi(note != nil), plural(len(closed)+btoi(note != nil)), folder)
	} else {
		r.say("retired: %s — the folder is gone; tracker reopen brings it back", folder)
	}
	if r.Path == "" {
		r.Path = v.LogDir()
	}
	return r, nil
}

// logNote stamps the project a note sat in and moves it to log/, which is
// exactly what `archive` does to a note it sweeps.
func (v *Vault) logNote(r *Report, n *Note, folder string) error {
	n.FM.Set("project", folder)
	if err := v.save(r, n); err != nil {
		return err
	}
	return v.move(r, n, v.LogDir())
}

// retireLeftovers refuses before anything moves if the folder holds a file
// this verb has no answer for — an attachment, a stray note, a sub-directory.
func (v *Vault) retireLeftovers(dir string, closed []*Item, note *Item) error {
	keep := map[string]bool{dsStore: true}
	for _, it := range closed {
		keep[filepath.Base(it.Note.Path)] = true
	}
	if note != nil {
		keep[filepath.Base(note.Note.Path)] = true
	}
	ents, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, e := range ents {
		if !keep[e.Name()] {
			return RefusedError(filepath.Join(dir, e.Name()) + " is not a note this verb can move — take it out first")
		}
	}
	return nil
}

// withoutEmbed drops the Project view line: the brief is leaving the folder
// the view was for, and `promote` puts the line back if it ever returns.
func withoutEmbed(body string) string {
	var out []string
	for _, l := range strings.Split(body, "\n") {
		if strings.TrimSpace(l) == ProjectEmbed {
			continue
		}
		out = append(out, l)
	}
	return strings.TrimRight(strings.Join(out, "\n"), "\n") + "\n"
}

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}

func theyThem(n int) string {
	if n == 1 {
		return "it"
	}
	return "them"
}

func btoi(b bool) int {
	if b {
		return 1
	}
	return 0
}

// withEmbed puts the Project view line at the end of a brief that has none —
// what makes a folder note show its own to-dos in Obsidian.
func withEmbed(body string) string {
	if strings.Contains(body, ProjectEmbed) {
		return body
	}
	body = strings.TrimRight(body, "\n")
	if body != "" {
		body += "\n\n"
	}
	return body + ProjectEmbed + "\n"
}

// toDoField names the first of a to-do's own fields on a note, "" if it has
// none. A folder note never carries one — `project add` writes none and
// `promote` deletes them all — so a note named after its folder that does is
// somebody's to-do the index is reading as a brief, and closing a project is
// not the verb that gets to close it.
func toDoField(n *Note) string {
	for _, k := range []string{"when", "repeat", "due", "lane"} {
		if n.FM.Has(k) {
			return k
		}
	}
	return ""
}

// halfRetired says what state the vault is in when the folder outlives its
// notes, which is the only way this verb can stop halfway.
func halfRetired(err error, folder string) error {
	return fmt.Errorf("%w — the notes are in log/ already; %s is empty, re-run to finish", err, folder)
}
