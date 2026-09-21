package cli

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/julienmartel/tracker/internal/vault"
)

// ── writes ───────────────────────────────────────────────────────────────────

// flags walks argv for `--flag value` pairs and bare flags; the words left
// over are the positional text (a title, an id, a note).
type flags struct {
	vals  map[string]string
	set   map[string]bool
	words []string
}

var flagAliases = map[string]string{"--project": "--in", "--list": "--in", "--deadline": "--due"}

func parseFlags(args []string, bare ...string) (*flags, error) {
	f := &flags{vals: map[string]string{}, set: map[string]bool{}}
	isBare := map[string]bool{}
	for _, b := range bare {
		isBare[b] = true
	}
	for i := 0; i < len(args); i++ {
		x := args[i]
		if !strings.HasPrefix(x, "--") || x == "--" {
			f.words = append(f.words, x)
			continue
		}
		name, val, has := strings.Cut(x, "=")
		if al, ok := flagAliases[name]; ok {
			name = al
		}
		f.set[name] = true
		if isBare[name] {
			continue
		}
		if !has {
			if i+1 >= len(args) {
				return nil, vault.UsageError(name + " needs a value")
			}
			i++
			val = args[i]
		}
		f.vals[name] = val
	}
	return f, nil
}

func (f *flags) text() string { return strings.Join(f.words, " ") }

func (a *App) add(args []string) error {
	f, err := parseFlags(args, "--now", "--someday", "--later", "--edit")
	if err != nil {
		return err
	}
	title := f.text()
	if title == "" {
		return vault.UsageError("usage: tracker add <title> [--in <project>] [--now | --someday | --when <date>] [--due <date>] [--repeat <daily|weekly|monthly|yearly|every N days>] [--tags a,b] [--notes <text>] [--checklist 'a|b'] [--edit]")
	}
	idx, err := a.load()
	if err != nil {
		return err
	}
	t := vault.NewTodo{Title: title, Notes: f.vals["--notes"], Tags: vault.Tags(f.vals["--tags"])}
	if in, ok := f.vals["--in"]; ok {
		if t.Folder, err = a.V.ResolveFolder(idx, in); err != nil {
			return err
		}
	}
	switch {
	case f.set["--now"]:
		t.When = vault.Now
	case f.set["--someday"]:
		t.When = vault.Someday
	case f.set["--later"]:
		t.When = vault.Later
	case f.set["--when"]:
		if t.When, err = vault.ParseWhen(f.vals["--when"], a.V.Now()); err != nil {
			return err
		}
	}
	if d, ok := f.vals["--due"]; ok {
		if t.Due, err = vault.ParseDate(d, a.V.Now()); err != nil {
			return err
		}
	}
	if s, ok := f.vals["--repeat"]; ok {
		if t.Repeat, err = vault.ParseRepeat(s); err != nil {
			return err
		}
	}
	if c := f.vals["--checklist"]; c != "" {
		t.Checklist = strings.Split(c, "|")
	}
	r, err := a.V.Add(t)
	if err != nil {
		return err
	}
	if f.set["--edit"] && !a.V.DryRun {
		if err := a.editor(r.Path); err != nil {
			return err
		}
	}
	return a.report(r)
}

// oneItem is every verb of the form `tracker <verb> <id> [more]`.
func (a *App) oneItem(verb string, args []string) error {
	if len(args) == 0 {
		return vault.UsageError("usage: tracker " + verb + " <id> …")
	}
	idx, err := a.load()
	if err != nil {
		return err
	}
	// Which words are the id: a verb with no trailing value takes the whole
	// line; `when` and `due` take a one-token value, so the last word is it
	// and the id is the rest (an unquoted `tracker due ship the thing +3d`
	// reads the way it was typed); the others take a value of any length, so
	// the id is the first word alone.
	id, rest := args[0], args[1:]
	switch verb {
	case "done", "now", "later", "someday", "drop", "reopen", "promote", "edit":
		id, rest = strings.Join(args, " "), nil
	case "spawn":
		f, err := parseFlags(args, "--follow", "--again")
		if err != nil {
			return err
		}
		id, rest = f.text(), nil
	case "when", "due-set":
		if len(args) >= 2 {
			id, rest = strings.Join(args[:len(args)-1], " "), args[len(args)-1:]
		}
	case "repeat":
		id, rest = splitRepeat(args)
	}
	it, err := a.resolve(idx, id, verb == "reopen")
	if err != nil {
		return err
	}
	var r *vault.Report
	switch verb {
	case "now":
		r, err = a.V.SetWhen(it, vault.Now)
	case "later":
		r, err = a.V.SetWhen(it, vault.Later)
	case "someday":
		r, err = a.V.SetWhen(it, vault.Someday)
	case "done":
		r, err = a.V.Done(it)
	case "drop":
		r, err = a.V.Drop(it)
	case "reopen":
		r, err = a.V.Reopen(it)
	case "promote":
		r, err = a.V.Promote(it)
	case "edit":
		if err := a.editor(it.Path); err != nil {
			return err
		}
		n, err := vault.ReadNote(it.Path, it.ID)
		if err != nil {
			return err
		}
		r = &vault.Report{ID: it.ID, Path: it.Path}
		r.Lines = append(r.Lines, "edited: "+it.ID)
		_ = n
	case "when":
		if len(rest) != 1 {
			return vault.UsageError("usage: tracker when <id> <now|later|someday|date>")
		}
		w, err := vault.ParseWhen(rest[0], a.V.Now())
		if err != nil {
			return err
		}
		r, err = a.V.SetWhen(it, w)
		if err != nil {
			return err
		}
	case "repeat":
		if len(rest) == 0 {
			return vault.UsageError("usage: tracker repeat <id> <daily|weekly|monthly|yearly|every N days|none>")
		}
		spec, err := vault.ParseRepeat(strings.Join(rest, " "))
		if err != nil {
			return err
		}
		r, err = a.V.SetRepeat(it, spec)
		if err != nil {
			return err
		}
	case "due-set":
		if len(rest) != 1 {
			return vault.UsageError("usage: tracker due <id> <date|none>")
		}
		d := ""
		if rest[0] != "none" {
			if d, err = vault.ParseDate(rest[0], a.V.Now()); err != nil {
				return err
			}
		}
		r, err = a.V.SetDue(it, d)
	case "move":
		if len(rest) == 0 {
			return vault.UsageError("usage: tracker move <id> <project|inbox>")
		}
		folder, err := a.V.ResolveFolder(idx, strings.Join(rest, " "))
		if err != nil {
			return err
		}
		r, err = a.V.Move(it, folder)
		if err != nil {
			return err
		}
	case "rename":
		if len(rest) == 0 {
			return vault.UsageError("usage: tracker rename <id> <title>")
		}
		r, err = a.V.Rename(it, strings.Join(rest, " "))
	case "tag":
		if len(rest) == 0 {
			return vault.UsageError("usage: tracker tag <id> +a -b")
		}
		r, err = a.V.Tag(it, rest)
	case "note":
		if len(rest) == 0 {
			return vault.UsageError("usage: tracker note <id> <text>")
		}
		r, err = a.V.Append(it, strings.Join(rest, " "))
	case "update":
		r, err = a.update(idx, it, rest)
	case "spawn":
		f, _ := parseFlags(args, "--follow", "--again")
		r, err = a.V.Spawn(idx, it, vault.SpawnOpts{Repo: f.vals["--repo"], Follow: f.set["--follow"], Again: f.set["--again"], Agent: f.vals["--agent"]}, a.Run)
	}
	if err != nil {
		return err
	}
	return a.report(r)
}

// splitRepeat cuts `tracker repeat water the plants every 3 days` where it
// reads: the longest trailing run of up to three words that is a repeat, the
// id being everything before it.
func splitRepeat(args []string) (string, []string) {
	for n := 3; n >= 1; n-- {
		if len(args) <= n {
			continue
		}
		tail := args[len(args)-n:]
		if s := strings.Join(tail, " "); s == "none" || s == "never" || vault.IsRepeat(s) {
			return strings.Join(args[:len(args)-n], " "), tail
		}
	}
	// Nothing trailing parses: the spec is still what the person meant it to
	// be — from `every` on, or the last word — so the error names the repeat
	// and not the to-do.
	for i := len(args) - 1; i > 0; i-- {
		if strings.EqualFold(args[i], "every") {
			return strings.Join(args[:i], " "), args[i:]
		}
	}
	if len(args) > 1 {
		return strings.Join(args[:len(args)-1], " "), args[len(args)-1:]
	}
	return strings.Join(args, " "), nil
}

// update applies several changes in the order given; the report is theirs
// joined, ending on the file the note ended up in.
func (a *App) update(idx *vault.Index, it *vault.Item, args []string) (*vault.Report, error) {
	f, err := parseFlags(args)
	if err != nil {
		return nil, err
	}
	if len(f.set) == 0 {
		return nil, vault.UsageError("usage: tracker update <id> [--when …] [--repeat …] [--due …] [--tags …] [--add-tags …] [--in …] [--title …] [--append-notes …]")
	}
	if len(f.words) > 0 {
		return nil, vault.UsageError("unexpected " + strconv.Quote(f.text()))
	}
	all := &vault.Report{}
	apply := func(r *vault.Report, err error) error {
		if err != nil {
			return err
		}
		all.Lines = append(all.Lines, r.Lines...)
		all.Change.Files = append(all.Change.Files, r.Change.Files...)
		all.ID, all.Path = r.ID, r.Path
		return nil
	}
	for _, name := range []string{"--when", "--repeat", "--due", "--tags", "--add-tags", "--append-notes", "--title", "--in"} {
		if !f.set[name] {
			continue
		}
		val := f.vals[name]
		switch name {
		case "--when":
			w, err := vault.ParseWhen(val, a.V.Now())
			if err != nil {
				return nil, err
			}
			err = apply(a.V.SetWhen(it, w))
			if err != nil {
				return nil, err
			}
		case "--repeat":
			spec, err := vault.ParseRepeat(val)
			if err != nil {
				return nil, err
			}
			if err := apply(a.V.SetRepeat(it, spec)); err != nil {
				return nil, err
			}
		case "--due":
			d := ""
			if val != "none" && val != "" {
				if d, err = vault.ParseDate(val, a.V.Now()); err != nil {
					return nil, err
				}
			}
			if err := apply(a.V.SetDue(it, d)); err != nil {
				return nil, err
			}
		case "--tags":
			if err := apply(a.V.SetTags(it, vault.Tags(val))); err != nil {
				return nil, err
			}
		case "--add-tags":
			var ops []string
			for _, t := range vault.Tags(val) {
				ops = append(ops, "+"+t)
			}
			if err := apply(a.V.Tag(it, ops)); err != nil {
				return nil, err
			}
		case "--append-notes":
			if err := apply(a.V.Append(it, val)); err != nil {
				return nil, err
			}
		case "--title":
			if err := apply(a.V.Rename(it, val)); err != nil {
				return nil, err
			}
		case "--in":
			folder, err := a.V.ResolveFolder(idx, val)
			if err != nil {
				return nil, err
			}
			if err := apply(a.V.Move(it, folder)); err != nil {
				return nil, err
			}
		}
	}
	return all, nil
}

func (a *App) projectAdd(args []string) error {
	f, err := parseFlags(args)
	if err != nil {
		return err
	}
	name := f.text()
	if name == "" {
		return vault.UsageError("usage: tracker project add <name> [--in <parent>] [--repo <path>] [--notes <brief>] [--todos 'a|b']")
	}
	idx, err := a.load()
	if err != nil {
		return err
	}
	p := vault.NewProject{Name: name, Repo: f.vals["--repo"], Notes: f.vals["--notes"]}
	if in, ok := f.vals["--in"]; ok {
		if p.Parent, err = a.V.ResolveFolder(idx, in); err != nil {
			return err
		}
	}
	if t := f.vals["--todos"]; t != "" {
		p.Todos = strings.Split(t, "|")
	}
	r, err := a.V.AddProject(p)
	if err != nil {
		return err
	}
	return a.report(r)
}

func (a *App) projectSet(args []string) error {
	var name string
	var sets []string
	for _, x := range args {
		if strings.Contains(x, "=") {
			sets = append(sets, x)
		} else {
			name = strings.TrimSpace(name + " " + x)
		}
	}
	if name == "" || len(sets) == 0 {
		return vault.UsageError("usage: tracker project set <name> repo=<path>")
	}
	idx, err := a.load()
	if err != nil {
		return err
	}
	folder, err := a.V.ResolveFolder(idx, name)
	if err != nil {
		return err
	}
	if folder == "" {
		return vault.RefusedError("the inbox has no folder note")
	}
	fn := idx.FolderNote(folder)
	if fn == nil {
		return vault.RefusedError(folder + " has no folder note — tracker project add makes one")
	}
	all := &vault.Report{}
	for _, s := range sets {
		k, v, _ := strings.Cut(s, "=")
		r, err := a.V.SetKey(fn, k, v)
		if err != nil {
			return err
		}
		all.Lines = append(all.Lines, r.Lines...)
		all.ID, all.Path = r.ID, r.Path
	}
	return a.report(all)
}

func (a *App) projectDone(args []string) error {
	name := strings.TrimSpace(strings.Join(args, " "))
	if name == "" {
		return vault.UsageError("usage: tracker project done <name>")
	}
	idx, err := a.load()
	if err != nil {
		return err
	}
	folder, err := a.V.ResolveFolder(idx, name)
	if err != nil {
		return err
	}
	r, err := a.V.RetireProject(idx, folder)
	if err != nil {
		return err
	}
	return a.report(r)
}

func (a *App) archive(args []string) error {
	f, err := parseFlags(args)
	if err != nil {
		return err
	}
	older := 30
	if o, ok := f.vals["--older"]; ok {
		if older, err = strconv.Atoi(o); err != nil || older < 0 {
			return vault.UsageError("--older takes a number of days")
		}
	}
	idx, err := a.load()
	if err != nil {
		return err
	}
	r, err := a.V.Archive(idx, older)
	if err != nil {
		return err
	}
	return a.report(r)
}

func (a *App) migrate() error {
	r, _, err := a.V.Migrate()
	if err != nil {
		return err
	}
	return a.report(r)
}

func (a *App) initVault(args []string) error {
	f, err := parseFlags(args, "--force")
	if err != nil {
		return err
	}
	r, err := a.V.Init(f.set["--force"])
	if err != nil {
		return err
	}
	return a.report(r)
}

var _ = fmt.Sprintf
