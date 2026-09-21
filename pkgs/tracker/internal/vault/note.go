package vault

import (
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

// ── one note, and the index of all of them ───────────────────────────────────

// Note is one file: its frontmatter, its body and the bytes it was read from
// (for undo, and to know whether a write would change anything).
type Note struct {
	Path string
	ID   string
	FM   *Frontmatter
	Body string
	raw  []byte
}

// ReadNote loads one file.
func ReadNote(path, id string) (*Note, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	fm, body := Parse(data)
	return &Note{Path: path, ID: id, FM: fm, Body: body, raw: data}, nil
}

// Bytes is what the note serializes to now.
func (n *Note) Bytes() []byte { return n.FM.Serialize(n.Body) }

// Changed reports whether a write would alter the file.
func (n *Note) Changed() bool { return string(n.Bytes()) != string(n.raw) }

// Raw is the file as it was read.
func (n *Note) Raw() []byte { return n.raw }

// Folder is the directory part of the id, "" at the root.
func (n *Note) Folder() string {
	if i := strings.LastIndex(n.ID, "/"); i >= 0 {
		return n.ID[:i]
	}
	return ""
}

// Name is the file name without .md.
func (n *Note) Name() string { return path.Base(n.ID) }

// Title is `title:` when the file name had to be sanitized, else the name.
func (n *Note) Title() string {
	if t := n.FM.Get("title"); t != "" {
		return t
	}
	return n.Name()
}

// IsFolderNote: `type: project`, or the note named after its folder.
func (n *Note) IsFolderNote() bool {
	if n.FM.Get("type") == "project" || n.FM.Get("type") == "area" {
		return true
	}
	f := n.Folder()
	return f != "" && path.Base(f) == n.Name()
}

// Item is one row of the index and the `--json` shape, exactly as the README
// lists it. A folder note is an Item too (IsProject), for the tree.
type Item struct {
	ID      string   `json:"id"`
	Title   string   `json:"title"`
	Folder  string   `json:"folder"`
	Project string   `json:"project"`
	When    string   `json:"when"`
	Bucket  string   `json:"bucket"`
	Repeat  string   `json:"repeat"`
	Due     string   `json:"due"`
	Done    string   `json:"done"`
	Dropped string   `json:"dropped"`
	Tags    []string `json:"tags"`
	Created string   `json:"created"`
	Lane    string   `json:"lane"`
	Repo    string   `json:"repo"`
	Path    string   `json:"path"`

	IsProject bool  `json:"-"`
	Note      *Note `json:"-"`
}

// Open is a to-do nobody has closed.
func (it *Item) Open() bool { return !it.IsProject && it.Done == "" && it.Dropped == "" }

// Closed is the date a to-do was closed on, "" while open.
func (it *Item) Closed() string {
	if it.Done != "" {
		return it.Done
	}
	return it.Dropped
}

// InLog is a note `archive` already moved.
func (it *Item) InLog() bool { return it.Folder == "log" || strings.HasPrefix(it.Folder, "log/") }

// Body is the note's text.
func (it *Item) Body() string { return it.Note.Body }

func (v *Vault) item(n *Note) *Item {
	it := &Item{
		ID:        n.ID,
		Title:     n.Title(),
		Folder:    n.Folder(),
		Repeat:    n.FM.Get("repeat"),
		Due:       n.FM.Get("due"),
		Done:      n.FM.Get("done"),
		Dropped:   n.FM.Get("dropped"),
		Tags:      n.FM.List("tags"),
		Created:   n.FM.Get("created"),
		Lane:      n.FM.Get("lane"),
		Repo:      n.FM.Get("repo"),
		Path:      n.Path,
		IsProject: n.IsFolderNote(),
		Note:      n,
	}
	if it.Tags == nil {
		it.Tags = []string{}
	}
	if i := strings.Index(it.Folder, "/"); i >= 0 {
		it.Project = it.Folder[:i]
	} else {
		it.Project = it.Folder
	}
	if !it.IsProject {
		it.When = Normalize(n.FM.Get("when"), v.Now())
		it.Bucket = Bucket(it.When)
	}
	return it
}

// Index is every note under tracker/, in path order.
type Index struct {
	Items []*Item
	byID  map[string]*Item
}

// Load walks tracker/ and reads every note. A to-do whose `when` is a date
// that has arrived is written back as `now` here — the one write a read
// makes, so the phone and the CLI agree on what Today is. A repeating one
// keeps its date: that date is the grid its next occurrence counts from, and
// the index reads it as now either way, as does the Bases Today view.
func (v *Vault) Load() (*Index, error) {
	if !v.Exists() {
		return nil, RefusedError("no tracker at " + v.Dir + " — run: tracker init")
	}
	idx := &Index{byID: map[string]*Item{}}
	err := filepath.WalkDir(v.Dir, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		name := d.Name()
		if strings.HasPrefix(name, ".") && p != v.Dir {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if d.IsDir() || !strings.HasSuffix(name, ".md") {
			return nil
		}
		n, err := ReadNote(p, v.ID(p))
		if err != nil {
			return nil
		}
		it := v.item(n)
		if it.Open() && !it.IsProject && it.Repeat == "" && IsDate(n.FM.Get("when")) && it.When == Now && !v.NoNormalize && !v.DryRun {
			n.FM.Set("when", Now)
			_ = v.writeFile(n.Path, n.Bytes())
			n.raw = n.Bytes()
		}
		idx.Items = append(idx.Items, it)
		idx.byID[it.ID] = it
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.SliceStable(idx.Items, func(i, j int) bool { return idx.Items[i].ID < idx.Items[j].ID })
	return idx, nil
}

// Get is the item of an id, nil if none.
func (idx *Index) Get(id string) *Item { return idx.byID[id] }

// Todos is every to-do, open and closed, log included.
func (idx *Index) Todos() []*Item {
	var out []*Item
	for _, it := range idx.Items {
		if !it.IsProject {
			out = append(out, it)
		}
	}
	return out
}

// Open is every open to-do.
func (idx *Index) Open() []*Item {
	var out []*Item
	for _, it := range idx.Items {
		if it.Open() {
			out = append(out, it)
		}
	}
	return out
}

// Closed is every closed to-do, wherever it sits.
func (idx *Index) Closed() []*Item {
	var out []*Item
	for _, it := range idx.Items {
		if !it.IsProject && !it.Open() {
			out = append(out, it)
		}
	}
	return out
}

// FolderNote is the folder note of a folder path, nil if it has none.
func (idx *Index) FolderNote(folder string) *Item {
	if folder == "" {
		return nil
	}
	return idx.byID[folder+"/"+path.Base(folder)]
}

// Folder is one project in the tree.
type Folder struct {
	Path  string // "hausfold/ci"
	Name  string // "ci"
	Depth int
	Open  int // open to-dos here and below
	Own   int // open to-dos here only
	Repo  string
	Note  *Item
}

// Folders is the project tree: every folder under tracker/ but log/, in path
// order, with open counts that include subfolders — an area's number is the
// sum of its projects, which is the one worth reading.
func (v *Vault) Folders(idx *Index) []*Folder {
	seen := map[string]*Folder{}
	add := func(p string) *Folder {
		if f, ok := seen[p]; ok {
			return f
		}
		f := &Folder{Path: p, Name: path.Base(p), Depth: strings.Count(p, "/")}
		seen[p] = f
		return f
	}
	_ = filepath.WalkDir(v.Dir, func(p string, d os.DirEntry, err error) error {
		if err != nil || !d.IsDir() || p == v.Dir {
			return nil
		}
		if strings.HasPrefix(d.Name(), ".") {
			return filepath.SkipDir
		}
		rel := filepath.ToSlash(strings.TrimPrefix(p, v.Dir+string(filepath.Separator)))
		if rel == "log" || strings.HasPrefix(rel, "log/") {
			return filepath.SkipDir
		}
		add(rel)
		return nil
	})
	for _, it := range idx.Items {
		if it.InLog() {
			// log/ is the archive, never a project — a folder note that was
			// demoted and swept there must not put a row back on the tree.
			continue
		}
		if it.IsProject {
			f := add(it.Folder)
			if it.ID == it.Folder+"/"+path.Base(it.Folder) {
				f.Note = it
				f.Repo = it.Repo
			}
			continue
		}
		if !it.Open() || it.Folder == "" {
			continue
		}
		add(it.Folder).Own++
		for p := it.Folder; p != ""; p = parentOf(p) {
			add(p).Open++
		}
	}
	out := make([]*Folder, 0, len(seen))
	for _, f := range seen {
		out = append(out, f)
	}
	sort.Slice(out, func(i, j int) bool { return strings.ToLower(out[i].Path) < strings.ToLower(out[j].Path) })
	return out
}

func parentOf(p string) string {
	if i := strings.LastIndex(p, "/"); i >= 0 {
		return p[:i]
	}
	return ""
}

// RepoFor is what `spawn` spawns on: the to-do's own `repo:`, else the nearest
// ancestor folder note's. "" when nobody said.
func (idx *Index) RepoFor(it *Item) string {
	if it.Repo != "" {
		return it.Repo
	}
	for p := it.Folder; p != ""; p = parentOf(p) {
		if fn := idx.FolderNote(p); fn != nil && fn.Repo != "" {
			return fn.Repo
		}
	}
	return ""
}
