package vault

import (
	"os"
	"path"
	"path/filepath"
	"strings"
)

// ── making things: a to-do, a project, a project out of a to-do ──────────────

// NewTodo is what `add` takes.
type NewTodo struct {
	Title     string
	Folder    string // "" = unfiled
	When      string // already normalized; "" = later
	Due       string
	Tags      []string
	Notes     string
	Checklist []string
}

// ProjectEmbed is the line every folder note carries: the Project view, with
// `this` the embedding note, so one base serves every project.
const ProjectEmbed = "![[tracker.base#Project]]"

// Add writes a new note. The folder must exist already; a title that
// sanitizes to something else keeps the original as `title:`.
func (v *Vault) Add(t NewTodo) (*Report, error) {
	name := Sanitize(t.Title)
	if name == "" {
		return nil, UsageError("the title sanitizes to nothing")
	}
	dir := filepath.Join(v.Dir, filepath.FromSlash(t.Folder))
	if t.Folder != "" {
		if st, err := os.Stat(dir); err != nil || !st.IsDir() {
			return nil, RefusedError("no project " + quote(t.Folder) + " — tracker project add")
		}
	}
	fm := Empty()
	when := t.When
	if when == "" {
		when = Later
	}
	fm.Set("when", when)
	fm.Set("due", t.Due)
	fm.SetList("tags", t.Tags)
	fm.Set("created", v.Today())
	if name != t.Title {
		fm.Set("title", t.Title)
	}
	var body strings.Builder
	if t.Notes != "" {
		body.WriteString(t.Notes)
		body.WriteString("\n")
	}
	if len(t.Checklist) > 0 {
		if body.Len() > 0 {
			body.WriteString("\n")
		}
		for _, c := range t.Checklist {
			if c = strings.TrimSpace(c); c != "" {
				body.WriteString("- [ ] " + c + "\n")
			}
		}
	}
	dest := UniquePath(dir, name)
	n := &Note{Path: dest, ID: v.ID(dest), FM: fm, Body: body.String()}
	r := &Report{}
	if v.DryRun {
		r.say("would add: %s", n.ID)
		r.Lines = append(r.Lines, strings.TrimRight(string(n.Bytes()), "\n"))
		r.ID, r.Path = n.ID, n.Path
		return r, nil
	}
	r.Change.record(dest)
	if err := writeAtomic(dest, n.Bytes()); err != nil {
		return nil, err
	}
	r.say("added: %s", n.ID)
	r.ID, r.Path = n.ID, n.Path
	return r, nil
}

// NewProject is what `project add` takes.
type NewProject struct {
	Name   string
	Parent string // "" = top level
	Repo   string
	Notes  string
	Todos  []string
}

// AddProject makes a folder and its folder note, then any first to-dos.
func (v *Vault) AddProject(p NewProject) (*Report, error) {
	name := Sanitize(p.Name)
	if name == "" {
		return nil, UsageError("the name sanitizes to nothing")
	}
	rel := name
	if p.Parent != "" {
		rel = p.Parent + "/" + name
	}
	dir := filepath.Join(v.Dir, filepath.FromSlash(rel))
	if _, err := os.Stat(dir); err == nil {
		return nil, RefusedError(quote(rel) + " already exists")
	}
	fm := Empty()
	fm.Set("type", "project")
	fm.Set("created", v.Today())
	fm.Set("repo", p.Repo)
	if name != p.Name {
		fm.Set("title", p.Name)
	}
	body := ProjectEmbed + "\n"
	if p.Notes != "" {
		body = p.Notes + "\n\n" + body
	}
	notePath := filepath.Join(dir, name+".md")
	n := &Note{Path: notePath, ID: rel + "/" + name, FM: fm, Body: body}
	r := &Report{}
	if v.DryRun {
		r.say("would add project: %s", rel)
		r.Lines = append(r.Lines, strings.TrimRight(string(n.Bytes()), "\n"))
	} else {
		r.Change.record(notePath)
		if err := writeAtomic(notePath, n.Bytes()); err != nil {
			return nil, err
		}
		r.say("added project: %s", rel)
	}
	r.ID, r.Path = n.ID, n.Path
	for _, t := range p.Todos {
		if t = strings.TrimSpace(t); t == "" {
			continue
		}
		sub, err := v.Add(NewTodo{Title: t, Folder: rel})
		if err != nil {
			return nil, err
		}
		r.Lines = append(r.Lines, sub.Lines...)
		r.Change.Files = append(r.Change.Files, sub.Change.Files...)
	}
	return r, nil
}

// Promote turns a to-do into a project: a folder named after it, beside it,
// with the note as the folder note. The body is the brief; the to-do's own
// fields go, since a project has no when.
func (v *Vault) Promote(it *Item) (*Report, error) {
	if it.IsProject {
		return nil, RefusedError(it.ID + " is a project already")
	}
	if it.InLog() {
		return nil, RefusedError(it.ID + " is archived — reopen it first")
	}
	n := it.Note
	dir := filepath.Join(filepath.Dir(n.Path), n.Name())
	if _, err := os.Stat(dir); err == nil {
		return nil, RefusedError(quote(v.ID(dir)) + " exists already")
	}
	for _, k := range []string{"when", "due", "done", "dropped", "lane"} {
		n.FM.Delete(k)
	}
	n.FM.Set("type", "project")
	if !strings.Contains(n.Body, ProjectEmbed) {
		body := strings.TrimRight(n.Body, "\n")
		if body != "" {
			body += "\n\n"
		}
		n.Body = body + ProjectEmbed + "\n"
	}
	r := &Report{}
	if err := v.save(r, n); err != nil {
		return nil, err
	}
	if err := v.move(r, n, dir); err != nil {
		return nil, err
	}
	r.say("promoted: %s  → project %s", it.ID, path.Dir(n.ID))
	return v.finish(r, it)
}
