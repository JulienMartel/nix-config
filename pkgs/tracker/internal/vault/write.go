package vault

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// ── writes: atomic, recorded, reported ───────────────────────────────────────
//
// Every write goes beside the file and renames over it, so iCloud and
// Obsidian see one change and never a half-written note. Every write also
// records what the files looked like before, which is all `u` in the TUI
// needs to put them back.

// FileState is one file before a change; Existed=false means it was not there.
type FileState struct {
	Path    string
	Before  []byte
	Existed bool
}

// Change is what one verb did to the disk, in the order it did it.
type Change struct {
	Files []FileState
}

func (c *Change) record(path string) {
	for _, f := range c.Files {
		if f.Path == path {
			return
		}
	}
	data, err := os.ReadFile(path)
	c.Files = append(c.Files, FileState{Path: path, Before: data, Existed: err == nil})
}

// Undo puts every file back the way it was, last write first.
func (c *Change) Undo() error {
	for i := len(c.Files) - 1; i >= 0; i-- {
		f := c.Files[i]
		if !f.Existed {
			if err := os.Remove(f.Path); err != nil && !os.IsNotExist(err) {
				return err
			}
			continue
		}
		if err := writeAtomic(f.Path, f.Before); err != nil {
			return err
		}
	}
	return nil
}

// Report is what a verb tells the caller: lines to print, the id and path it
// ended on (for the file:// line), and the change (for undo).
type Report struct {
	Lines  []string
	ID     string
	Path   string
	Change Change
}

func (r *Report) say(format string, a ...any) {
	r.Lines = append(r.Lines, fmt.Sprintf(format, a...))
}

func writeAtomic(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp := fmt.Sprintf("%s.tmp.%d", path, os.Getpid())
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return err
	}
	return nil
}

func (v *Vault) writeFile(path string, data []byte) error {
	if v.DryRun {
		return nil
	}
	return writeAtomic(path, data)
}

// save writes a note if it changed.
func (v *Vault) save(r *Report, n *Note) error {
	if !n.Changed() {
		return nil
	}
	r.Change.record(n.Path)
	if err := v.writeFile(n.Path, n.Bytes()); err != nil {
		return err
	}
	n.raw = n.Bytes()
	return nil
}

// UniquePath is dir/name.md, or dir/name (2).md and up when that exists.
func UniquePath(dir, name string) string {
	p := filepath.Join(dir, name+".md")
	for i := 2; ; i++ {
		if _, err := os.Lstat(p); os.IsNotExist(err) {
			return p
		}
		p = filepath.Join(dir, fmt.Sprintf("%s (%d).md", name, i))
	}
}

// move renames a note's file to a unique path in dir, updating its id.
func (v *Vault) move(r *Report, n *Note, dir string) error {
	dest := UniquePath(dir, n.Name())
	if v.DryRun {
		n.Path, n.ID = dest, v.ID(dest)
		return nil
	}
	r.Change.record(n.Path)
	r.Change.record(dest)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	if err := os.Rename(n.Path, dest); err != nil {
		return err
	}
	n.Path, n.ID = dest, v.ID(dest)
	return nil
}

// ── the verbs on one to-do ───────────────────────────────────────────────────

// finish saves the note and re-derives the item from it, so a caller holding
// the item sees the write (the TUI's list, a second verb in `update`).
func (v *Vault) finish(r *Report, it *Item) (*Report, error) {
	n := it.Note
	if err := v.save(r, n); err != nil {
		return nil, err
	}
	*it = *v.item(n)
	r.ID, r.Path = n.ID, n.Path
	return r, nil
}

func requireOpen(it *Item) error {
	if it.IsProject {
		return RefusedError(it.ID + " is a project, not a to-do")
	}
	if !it.Open() {
		return RefusedError(it.ID + " is already closed — tracker reopen")
	}
	return nil
}

// SetWhen: now | later | someday | a date (already normalized by ParseWhen).
func (v *Vault) SetWhen(it *Item, when string) (*Report, error) {
	if err := requireOpen(it); err != nil {
		return nil, err
	}
	n := it.Note
	n.FM.Set("when", when)
	r := &Report{}
	r.say("%s %s  → when: %s", Glyph(Bucket(when)), it.Title, when)
	return v.finish(r, it)
}

// SetDue sets or, with "", clears the deadline.
func (v *Vault) SetDue(it *Item, due string) (*Report, error) {
	if err := requireOpen(it); err != nil {
		return nil, err
	}
	n := it.Note
	n.FM.Set("due", due)
	r := &Report{}
	if due == "" {
		r.say("%s  → no due date", it.Title)
	} else {
		r.say("%s  → due %s", it.Title, due)
	}
	return v.finish(r, it)
}

// SetRepeat sets or, with "", clears how often a to-do comes back. Nothing
// happens until it is done: `repeat:` is read only there.
func (v *Vault) SetRepeat(it *Item, spec string) (*Report, error) {
	if err := requireOpen(it); err != nil {
		return nil, err
	}
	it.Note.FM.Set("repeat", spec)
	r := &Report{}
	if spec == "" {
		r.say("%s  → no repeat", it.Title)
	} else {
		r.say("↻ %s  → repeat: %s", it.Title, spec)
	}
	return v.finish(r, it)
}

// Done closes a to-do today. Nothing moves: closed is a date, not a place.
// A `repeat:` to-do also comes back as a fresh note beside this one — written
// first, so a series can never lose its successor to a failed write.
func (v *Vault) Done(it *Item) (*Report, error) {
	if err := requireOpen(it); err != nil {
		return nil, err
	}
	r := &Report{}
	again, err := v.repeatNext(r, it)
	if err != nil {
		return nil, err
	}
	n := it.Note
	n.FM.Set("done", v.Today())
	n.FM.Delete("dropped")
	r.say("✓ %s  (%s)", it.Title, it.ID)
	if again != "" {
		r.say("%s", again)
	}
	return v.finish(r, it)
}

// repeatNext writes the note a repeating to-do comes back as: the same to-do
// on its next date, in the same folder, carrying every key and the body it was
// closed with — but its own `created:`, no `done:` / `dropped:` / `lane:`, and
// an untouched checklist. A closed note is never rolled forward.
//
// It returns the line the report says about it, "" when the to-do does not
// repeat.
func (v *Vault) repeatNext(r *Report, it *Item) (string, error) {
	if it.Repeat == "" {
		return "", nil
	}
	when, shift, err := NextWhen(it.Note.FM.Get("when"), it.Repeat, v.Now())
	if err != nil {
		// A `repeat:` typed by hand that this does not parse must never block
		// the completion — the to-do closes, and says what it could not read.
		return "↻ " + err.Error() + " — closed, nothing repeated", nil
	}
	dir := filepath.Dir(it.Note.Path)
	if id, ok := v.occurrence(dir, it.Title, it.Repeat, it.Note.Path); ok {
		return "↻ next: " + id + " is open already", nil
	}
	fm := it.Note.FM.Clone()
	fm.Set("when", when)
	fm.Set("created", v.Today())
	for _, k := range []string{"done", "dropped", "lane"} {
		fm.Delete(k)
	}
	if due := fm.Get("due"); IsDate(due) {
		d, _ := time.Parse(dateLayout, due)
		fm.Set("due", d.AddDate(0, 0, shift).Format(dateLayout))
	}
	name := Sanitize(it.Title)
	if name == "" {
		name = it.Note.Name()
	}
	dest := UniquePath(dir, name)
	if base := strings.TrimSuffix(filepath.Base(dest), ".md"); base == it.Title {
		fm.Delete("title")
	} else {
		fm.Set("title", it.Title)
	}
	n := &Note{Path: dest, ID: v.ID(dest), FM: fm, Body: untick(it.Body())}
	if v.DryRun {
		return fmt.Sprintf("↻ would repeat: %s  → when: %s", n.ID, when), nil
	}
	r.Change.record(dest)
	if err := writeAtomic(dest, n.Bytes()); err != nil {
		return "", err
	}
	return fmt.Sprintf("↻ %s  → when: %s", n.ID, when), nil
}

// occurrence is an open to-do in dir, other than `self`, with the same title
// and the same `repeat:` — the same series, in other words. It is what a
// `reopen` and a second `done` would otherwise duplicate.
func (v *Vault) occurrence(dir, title, spec, self string) (string, bool) {
	if spec == "" {
		return "", false
	}
	ents, err := os.ReadDir(dir)
	if err != nil {
		return "", false
	}
	for _, e := range ents {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		p := filepath.Join(dir, e.Name())
		if p == self {
			continue
		}
		n, err := ReadNote(p, v.ID(p))
		if err != nil || n.IsFolderNote() {
			continue
		}
		if n.Title() != title || n.FM.Get("repeat") != spec {
			continue
		}
		if n.FM.Get("done") == "" && n.FM.Get("dropped") == "" {
			return n.ID, true
		}
	}
	return "", false
}

// ticked is a checked box anywhere in a body; a chore comes back with its
// checklist empty.
var ticked = regexp.MustCompile(`(?m)^(\s*[-*+] +\[)[xX](\])`)

func untick(body string) string { return ticked.ReplaceAllString(body, "${1} ${2}") }

// Drop abandons a to-do today. A repeating one ends here: drop is how a
// series stops, where `done` is how it goes round again.
func (v *Vault) Drop(it *Item) (*Report, error) {
	if err := requireOpen(it); err != nil {
		return nil, err
	}
	n := it.Note
	n.FM.Set("dropped", v.Today())
	n.FM.Delete("done")
	r := &Report{}
	r.say("✗ %s  (%s)", it.Title, it.ID)
	return v.finish(r, it)
}

// Reopen clears the close date. An archived note goes back to the project
// `archive` stamped on it (made again if it is gone), and loses the stamp.
func (v *Vault) Reopen(it *Item) (*Report, error) {
	if it.IsProject {
		return nil, RefusedError(it.ID + " is a project, not a to-do")
	}
	if it.Open() {
		return nil, RefusedError(it.ID + " is open already")
	}
	n := it.Note
	n.FM.Delete("done")
	n.FM.Delete("dropped")
	r := &Report{}
	if id, ok := v.occurrence(filepath.Dir(n.Path), it.Title, it.Repeat, n.Path); ok {
		// The occurrence `done` wrote stays where it is: reopening the note
		// that made it is not a reason to take it back.
		r.say("↻ next: %s is open already", id)
	}
	if it.InLog() {
		folder := n.FM.Get("project")
		n.FM.Delete("project")
		if err := v.save(r, n); err != nil {
			return nil, err
		}
		if err := v.move(r, n, filepath.Join(v.Dir, filepath.FromSlash(folder))); err != nil {
			return nil, err
		}
	}
	r.say("reopened: %s", n.ID)
	return v.finish(r, it)
}

// Move files a to-do under a folder ("" = the root, unfiled).
func (v *Vault) Move(it *Item, folder string) (*Report, error) {
	if it.IsProject {
		return nil, RefusedError(it.ID + " is a project — move its folder in Obsidian")
	}
	n := it.Note
	if it.Folder == folder {
		return nil, RefusedError(it.ID + " is there already")
	}
	r := &Report{}
	if err := v.move(r, n, filepath.Join(v.Dir, filepath.FromSlash(folder))); err != nil {
		return nil, err
	}
	where := folder
	if where == "" {
		where = "inbox"
	}
	r.say("moved: %s  → %s", n.ID, where)
	return v.finish(r, it)
}

// Rename retitles a to-do: the file is renamed to the sanitized title and
// `title:` is written only when the two differ.
func (v *Vault) Rename(it *Item, title string) (*Report, error) {
	if it.IsProject {
		return nil, RefusedError(it.ID + " is a project — rename its folder in Obsidian")
	}
	name := Sanitize(title)
	if name == "" {
		return nil, UsageError("the title sanitizes to nothing")
	}
	n := it.Note
	r := &Report{}
	if name != title {
		n.FM.Set("title", title)
	} else {
		n.FM.Delete("title")
	}
	if err := v.save(r, n); err != nil {
		return nil, err
	}
	if name != n.Name() {
		// A case-only rename on the Mac's case-insensitive disk: UniquePath
		// would see the note itself at the new name and step aside to ` (2)`,
		// so the one file that may already be there is this one.
		dest := filepath.Join(filepath.Dir(n.Path), name+".md")
		if !sameFile(dest, n.Path) {
			dest = UniquePath(filepath.Dir(n.Path), name)
		}
		if !v.DryRun {
			r.Change.record(n.Path)
			r.Change.record(dest)
			if err := os.Rename(n.Path, dest); err != nil {
				return nil, err
			}
		}
		n.Path, n.ID = dest, v.ID(dest)
	}
	r.say("renamed: %s", n.ID)
	return v.finish(r, it)
}

// Tag adds (+a) and removes (-b) tags; a bare word adds.
func (v *Vault) Tag(it *Item, ops []string) (*Report, error) {
	if it.IsProject {
		return nil, RefusedError(it.ID + " is a project")
	}
	n := it.Note
	tags := n.FM.List("tags")
	for _, op := range ops {
		switch {
		case strings.HasPrefix(op, "-"):
			t := SanitizeTag(op[1:])
			tags = without(tags, t)
		default:
			t := SanitizeTag(strings.TrimPrefix(op, "+"))
			if t != "" && !contains(tags, t) {
				tags = append(tags, t)
			}
		}
	}
	n.FM.SetList("tags", tags)
	r := &Report{}
	r.say("%s  → tags: %s", it.Title, strings.Join(tags, ", "))
	return v.finish(r, it)
}

// SetTags replaces the tag list.
func (v *Vault) SetTags(it *Item, tags []string) (*Report, error) {
	n := it.Note
	n.FM.SetList("tags", tags)
	r := &Report{}
	r.say("%s  → tags: %s", it.Title, strings.Join(tags, ", "))
	return v.finish(r, it)
}

// Append adds text to the end of the body, on its own paragraph.
func (v *Vault) Append(it *Item, text string) (*Report, error) {
	n := it.Note
	body := n.Body
	if body != "" && !strings.HasSuffix(body, "\n") {
		body += "\n"
	}
	if body != "" && !strings.HasSuffix(body, "\n\n") {
		body += "\n"
	}
	n.Body = body + text + "\n"
	r := &Report{}
	r.say("noted: %s", n.ID)
	return v.finish(r, it)
}

// SetBody replaces the body — the TUI's checklist ticks go through here.
func (v *Vault) SetBody(it *Item, body string) (*Report, error) {
	n := it.Note
	n.Body = body
	r := &Report{}
	r.say("updated: %s", n.ID)
	return v.finish(r, it)
}

// SetKey writes one frontmatter key on any note (a folder note's `repo:`).
func (v *Vault) SetKey(it *Item, key, value string) (*Report, error) {
	if !keyLine.MatchString(key + ":") {
		return nil, UsageError(quote(key) + " is not a property name")
	}
	n := it.Note
	if key == "tags" {
		n.FM.SetList("tags", Tags(value))
	} else {
		n.FM.Set(key, value)
	}
	r := &Report{}
	if value == "" {
		r.say("%s  → %s removed", n.ID, key)
	} else {
		r.say("%s  → %s: %s", n.ID, key, value)
	}
	return v.finish(r, it)
}

// sameFile is whether two paths name one file — true for a case variant on a
// case-insensitive disk, false when either is not there.
func sameFile(a, b string) bool {
	sa, err := os.Stat(a)
	if err != nil {
		return false
	}
	sb, err := os.Stat(b)
	if err != nil {
		return false
	}
	return os.SameFile(sa, sb)
}

func contains(xs []string, s string) bool {
	for _, x := range xs {
		if x == s {
			return true
		}
	}
	return false
}

func without(xs []string, s string) []string {
	var out []string
	for _, x := range xs {
		if x != s {
			out = append(out, x)
		}
	}
	return out
}
