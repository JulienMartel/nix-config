package vault

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// ── resolving what the user typed ────────────────────────────────────────────

// Resolve finds one to-do: an exact id (with or without `tracker/` or `.md`)
// or a unique case-insensitive substring of an OPEN to-do's id or title.
// closed=true (the reopen verb) searches the closed ones instead, and a bare
// name is tried under log/ too. Ambiguity is an error that lists the
// candidates — show them, never pick one.
func (v *Vault) Resolve(idx *Index, query string, closed bool) (*Item, error) {
	s := strings.TrimSuffix(strings.TrimSpace(query), ".md")
	s = strings.TrimPrefix(s, "tracker/")
	s = strings.Trim(s, "/")
	if s == "" {
		return nil, UsageError("an id or a bit of a title is needed")
	}
	if it := idx.Get(s); it != nil {
		return it, nil
	}
	if closed {
		if it := idx.Get("log/" + s); it != nil {
			return it, nil
		}
	}
	// A file that exists but is not indexed (a race with a write) still counts.
	if _, err := os.Stat(v.Path(s)); err == nil {
		if n, err := ReadNote(v.Path(s), s); err == nil {
			return v.item(n), nil
		}
	}
	q := strings.ToLower(s)
	var hits []*Item
	for _, it := range idx.Todos() {
		if it.Open() == closed {
			continue
		}
		if strings.Contains(strings.ToLower(it.ID), q) || strings.Contains(strings.ToLower(it.Title), q) {
			hits = append(hits, it)
		}
	}
	switch len(hits) {
	case 0:
		if closed {
			return nil, RefusedError("nothing closed matches " + quote(query))
		}
		return nil, RefusedError("nothing open matches " + quote(query))
	case 1:
		return hits[0], nil
	}
	ids := make([]string, len(hits))
	for i, h := range hits {
		ids[i] = h.ID
	}
	sort.Strings(ids)
	return nil, &AmbiguousError{Query: query, Candidates: ids}
}

// ResolveFolder finds a project folder: "" / inbox / "/" is the root; else an
// exact folder path, else a unique case-insensitive substring of one. log/ is
// never a project.
func (v *Vault) ResolveFolder(idx *Index, query string) (string, error) {
	s := strings.Trim(strings.TrimSpace(query), "/")
	s = strings.TrimPrefix(s, "tracker/")
	switch strings.ToLower(s) {
	case "", "inbox", ".", "root":
		return "", nil
	}
	if s == "log" || strings.HasPrefix(s, "log/") {
		return "", RefusedError("log/ is the archive, not a project")
	}
	if st, err := os.Stat(filepath.Join(v.Dir, filepath.FromSlash(s))); err == nil && st.IsDir() {
		return s, nil
	}
	q := strings.ToLower(s)
	var hits []string
	for _, f := range v.Folders(idx) {
		if strings.ToLower(f.Path) == q {
			return f.Path, nil
		}
		if strings.Contains(strings.ToLower(f.Path), q) {
			hits = append(hits, f.Path)
		}
	}
	switch len(hits) {
	case 0:
		return "", RefusedError("no project matches " + quote(query) + " — tracker projects · tracker project add")
	case 1:
		return hits[0], nil
	}
	return "", &AmbiguousError{Query: query, Candidates: hits}
}

func quote(s string) string { return `"` + s + `"` }
