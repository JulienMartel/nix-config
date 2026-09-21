package vault

import (
	"path/filepath"
	"sort"
)

// ── archive: closed notes older than N days go to log/ ───────────────────────
//
// Nothing moves on completion, so the phone can close a to-do with one
// property. This is the sweep that keeps a project folder from filling with
// history: a note closed more than `older` days ago moves to log/, stamped
// with the project it sat in so `reopen` can put it back.

// Archive moves the closed notes older than `older` days. DryRun lists them.
func (v *Vault) Archive(idx *Index, older int) (*Report, error) {
	cutoff := v.Now().AddDate(0, 0, -older).Format(dateLayout)
	var due []*Item
	for _, it := range idx.Closed() {
		if it.InLog() {
			continue
		}
		if c := it.Closed(); c != "" && c <= cutoff {
			due = append(due, it)
		}
	}
	sort.Slice(due, func(i, j int) bool { return due[i].ID < due[j].ID })
	r := &Report{}
	for _, it := range due {
		n := it.Note
		if it.Folder != "" {
			n.FM.Set("project", it.Folder)
		}
		if v.DryRun {
			r.say("%s %s  → log/%s  (%s)", Glyph(State(it)), it.ID, n.Name(), it.Closed())
			continue
		}
		if err := v.save(r, n); err != nil {
			return nil, err
		}
		if err := v.move(r, n, v.LogDir()); err != nil {
			return nil, err
		}
		r.say("%s %s  → %s  (%s)", Glyph(State(it)), it.ID, n.ID, it.Closed())
	}
	switch {
	case len(due) == 0:
		r.say("(nothing to archive)")
	case v.DryRun:
		r.say("%d to archive — dry run, nothing written", len(due))
	default:
		r.say("%d archived → log/", len(due))
	}
	r.Path = filepath.Join(v.LogDir())
	return r, nil
}
