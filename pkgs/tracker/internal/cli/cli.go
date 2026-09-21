// Package cli is the shell face of the list: every verb in the README, for
// agents, scripts and pounce. Reads print rows or `--json`; writes print a
// report that ends on the file:// line a pane makes clickable. Nothing here
// ever opens the app or touches the screen.
package cli

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/julienmartel/tracker/internal/vault"
)

// App is one invocation's state.
type App struct {
	V    *vault.Vault
	Out  io.Writer
	Err  io.Writer
	JSON bool
	Run  vault.Runner
}

// aliases kept for the skills and old habits.
var aliases = map[string]string{
	"complete": "done", "cancel": "drop", "anytime": "later", "add-project": "project-add",
	"deadlines": "due", "log": "done", "sweep": "archive", "ls": "today", "rm": "drop",
}

// Main runs argv and returns the exit code: 0 ok · 1 refused · 2 usage.
func Main(args []string, out, errw io.Writer) int {
	a := &App{V: vault.Open(), Out: out, Err: errw, Run: vault.ExecRunner{}}
	return a.Main(args)
}

// Main on an App, for tests that point the vault elsewhere.
func (a *App) Main(args []string) int {
	var rest []string
	for _, x := range args {
		switch x {
		case "--json":
			a.JSON = true
		case "--dry-run", "-n":
			a.V.DryRun = true
		default:
			rest = append(rest, x)
		}
	}
	if len(rest) == 0 {
		rest = []string{"today"}
	}
	verb, rest := rest[0], rest[1:]
	if al, ok := aliases[verb]; ok {
		verb = al
	}
	if verb == "project" && len(rest) > 0 {
		verb, rest = "project-"+rest[0], rest[1:]
	}
	err := a.dispatch(verb, rest)
	if err != nil {
		switch e := err.(type) {
		case vault.UsageError:
			fmt.Fprintf(a.Err, "tracker: %s\n", e)
		case *vault.AmbiguousError:
			fmt.Fprintf(a.Err, "tracker: %s\n", e)
		default:
			fmt.Fprintf(a.Err, "tracker: %s\n", err)
		}
	}
	return vault.ExitCode(err)
}

func (a *App) dispatch(verb string, args []string) error {
	switch verb {
	case "today", "upcoming", "inbox", "done-list", "index":
		return a.view(verb, args)
	case "later", "someday":
		// `later` alone is the view; `later <id>` is the verb — the pounce
		// list flips a row with exactly that.
		if len(args) == 0 {
			return a.view(verb, args)
		}
		return a.oneItem(verb, args)
	case "due":
		// `due [days]` is the view; `due <id> <date|none>` sets the deadline.
		if len(args) == 0 || len(args) == 1 && isNumber(args[0]) {
			return a.view(verb, args)
		}
		return a.oneItem("due-set", args)
	case "done":
		// `done` alone is the Done view; `done <id>` closes one.
		if len(args) == 0 || isNumber(args[0]) {
			return a.view("done-list", args)
		}
		return a.oneItem(verb, args)
	case "list":
		return a.list(args)
	case "projects":
		return a.projects()
	case "search":
		return a.search(args)
	case "show":
		return a.show(args)
	case "link":
		return a.link(args)
	case "add":
		return a.add(args)
	case "now", "drop", "reopen", "promote", "edit":
		return a.oneItem(verb, args)
	case "when", "due-set", "move", "rename", "tag", "note", "update", "spawn":
		return a.oneItem(verb, args)
	case "project-add":
		return a.projectAdd(args)
	case "project-set":
		return a.projectSet(args)
	case "archive":
		return a.archive(args)
	case "migrate":
		return a.migrate()
	case "init":
		return a.initVault(args)
	case "help", "-h", "--help":
		fmt.Fprint(a.Out, Usage)
		return nil
	case "version", "--version":
		fmt.Fprintln(a.Out, "tracker "+Version)
		return nil
	}
	return vault.UsageError("unknown verb " + strconv.Quote(verb) + " — tracker help")
}

// Version is stamped by the build.
var Version = "dev"

func isNumber(s string) bool { _, err := strconv.Atoi(s); return err == nil }

// ── output ───────────────────────────────────────────────────────────────────

func (a *App) printJSON(v any) error {
	enc := json.NewEncoder(a.Out)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	return enc.Encode(v)
}

// report prints a write's lines and, last, the file:// line.
func (a *App) report(r *vault.Report) error {
	if a.JSON {
		return a.printJSON(map[string]any{
			"id": r.ID, "path": r.Path, "lines": r.Lines,
			"file": vault.FileURL(r.Path), "obsidian": a.V.ObsidianURL(r.Path),
		})
	}
	for _, l := range r.Lines {
		fmt.Fprintln(a.Out, l)
	}
	if r.Path != "" {
		fmt.Fprintln(a.Out, vault.FileURL(r.Path))
	}
	return nil
}

func (a *App) load() (*vault.Index, error) { return a.V.Load() }

func (a *App) resolve(idx *vault.Index, q string, closed bool) (*vault.Item, error) {
	return a.V.Resolve(idx, q, closed)
}

// editor opens the note in $EDITOR on the terminal — the one verb that hands
// the terminal to another program.
func (a *App) editor(path string) error {
	ed := os.Getenv("EDITOR")
	if ed == "" {
		ed = "vi"
	}
	parts := strings.Fields(ed)
	cmd := exec.Command(parts[0], append(parts[1:], path)...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd.Run()
}

// Usage is `tracker help`.
const Usage = `tracker — my to-do list: markdown notes in the Obsidian vault, one folder per project

READ   tracker today | later | someday | upcoming [days=14] | due [days=30] | inbox | done [n=20]
       tracker list <project> · projects · search <text> · show <id> · link <id> · index
WRITE  tracker add <title> [--in <project>] [--now | --someday | --when <date|today|tomorrow|+3d>]
                           [--due <date>] [--tags a,b] [--notes <text>] [--checklist 'a|b'] [--edit]
       tracker now | later | someday <id>       tracker when <id> <now|later|someday|date>
       tracker due <id> <date|none>             tracker done <id> · drop <id> · reopen <id>
       tracker move <id> <project|inbox>        tracker rename <id> <title>
       tracker tag <id> +a -b                   tracker note <id> <text>        (append)
       tracker edit <id>                        ($EDITOR, then re-read)
       tracker update <id> [--when …] [--due …] [--tags …] [--add-tags …] [--in …] [--title …] [--append-notes …]
       tracker project add <name> [--in <parent>] [--repo <path>] [--notes <brief>] [--todos 'a|b']
       tracker project set <name> repo=<path>   tracker promote <id>           (to-do → project)
       tracker spawn <id> [--repo <path>] [--follow] [--again]   a lane for this to-do
       tracker archive [--older 30] [--dry-run] · migrate [--dry-run] · init [--force]
IDS    folder/name under tracker/ (no .md), or any unique bit of an open to-do's id or title
FLAGS  --json on any read · DRY_RUN=1 / --dry-run on add, archive, migrate, spawn
EXIT   0 ok · 1 nothing matched / refused · 2 usage
ENV    TRACKER_VAULT / TRACKER_DIR point it elsewhere
`
