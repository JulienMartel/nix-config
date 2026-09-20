package vault

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

// ── spawn: a lane for this to-do, the way haus's Spawn Agent does it ─────────

// Runner runs a command with extra environment and stdin, and hands back
// stdout, stderr and the exit code. Injectable so a test never spawns a lane.
type Runner interface {
	Run(env []string, stdin string, name string, args ...string) (stdout, stderr string, code int, err error)
}

// ExecRunner is the real one.
type ExecRunner struct{}

func (ExecRunner) Run(env []string, stdin string, name string, args ...string) (string, string, int, error) {
	cmd := exec.Command(name, args...)
	cmd.Env = append(os.Environ(), env...)
	cmd.Stdin = strings.NewReader(stdin)
	var out, errb bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &errb
	err := cmd.Run()
	code := 0
	if ee, ok := err.(*exec.ExitError); ok {
		code, err = ee.ExitCode(), nil
	}
	return out.String(), errb.String(), code, err
}

// SpawnOpts is what the verb takes.
type SpawnOpts struct {
	Repo   string // --repo: the fallback when neither the to-do nor a folder note says
	Follow bool   // --follow: take the screen (clears HAUS_LANE_BACKGROUND)
	Again  bool   // --again: spawn even though a lane: is on the note
	Agent  string // the client; "" asks `scruff agent default`
}

// NotifyPath is haus-notify at the path haus installs it; absolute, so no
// PATH prelude can shadow it. Empty is "no banner".
var NotifyPath = "/run/current-system/sw/bin/haus-notify"

// SpawnPlan is what would run: shown by --dry-run, then run for real.
type SpawnPlan struct {
	Repo   string
	Slug   string
	Agent  string
	Prompt string
	Env    []string
	Args   []string
}

// Command is the plan as one shell line, for the eye.
func (p SpawnPlan) Command() string {
	return strings.Join(append(append([]string{}, p.Env...), "scruff "+strings.Join(p.Args, " ")), " ")
}

// Plan resolves the repo, composes the prompt and names the lane without
// running anything.
func (v *Vault) Plan(idx *Index, it *Item, o SpawnOpts, run Runner) (*SpawnPlan, error) {
	if err := requireOpen(it); err != nil {
		return nil, err
	}
	if it.Lane != "" && !o.Again {
		return nil, RefusedError(it.ID + " already has a lane: " + it.Lane + " — --again spawns another")
	}
	repo := idx.RepoFor(it)
	if repo == "" {
		repo = o.Repo
	}
	if repo == "" {
		on := "the to-do"
		if it.Project != "" {
			on = "tracker project set " + quote(it.Project) + " repo=<path>"
		}
		return nil, RefusedError("no repo for " + quote(it.ID) + " — " + on + ", or --repo <path>")
	}
	repo = expandHome(repo)
	agent := o.Agent
	if agent == "" {
		out, _, code, err := run.Run(nil, "", "scruff", "agent", "default")
		if err == nil && code == 0 {
			agent = strings.TrimSpace(out)
		}
	}
	if agent == "" {
		agent = "claude"
	}
	var prompt strings.Builder
	prompt.WriteString(it.Title + "\n\n")
	if body := strings.TrimSpace(it.Body()); body != "" {
		prompt.WriteString(body + "\n\n")
	}
	fmt.Fprintf(&prompt, "tracker: %s\nOn /ship: tracker done %q\n", it.ID, it.ID)
	p := &SpawnPlan{
		Repo:   repo,
		Slug:   Slug(it.Title),
		Agent:  agent,
		Prompt: prompt.String(),
		Env:    []string{"HAUS_LANE_BACKGROUND=1"},
	}
	if o.Follow {
		// Exported empty rather than unset, the way haus does it: nothing
		// stale in the environment may silence a spawn that asked to be seen.
		p.Env = []string{"HAUS_LANE_BACKGROUND="}
	}
	p.Args = []string{"spawn", repo, "--derived-name", p.Slug, "--agent", agent, "--prompt-file", "-"}
	return p, nil
}

// Spawn runs the plan, then marks the note `when: now` with its `lane:` and
// puts a banner up with a way to the lane.
func (v *Vault) Spawn(idx *Index, it *Item, o SpawnOpts, run Runner) (*Report, error) {
	p, err := v.Plan(idx, it, o, run)
	if err != nil {
		return nil, err
	}
	r := &Report{}
	if v.DryRun {
		r.say("would run: %s", p.Command())
		r.say("--- prompt ---")
		r.Lines = append(r.Lines, strings.TrimRight(p.Prompt, "\n"))
		r.ID, r.Path = it.ID, it.Path
		return r, nil
	}
	if st, err := os.Stat(p.Repo); err != nil || !st.IsDir() {
		return nil, RefusedError("no repo at " + p.Repo)
	}
	out, errOut, code, err := run.Run(p.Env, p.Prompt, "scruff", p.Args...)
	if err != nil {
		return nil, fmt.Errorf("scruff: %w", err)
	}
	dir := strings.TrimSpace(out)
	if code != 0 || dir == "" {
		msg := strings.TrimSpace(errOut)
		if msg == "" {
			msg = fmt.Sprintf("scruff spawn exited %d", code)
		}
		return nil, RefusedError(msg)
	}
	name := filepath.Base(dir)
	repoName := filepath.Base(p.Repo)
	lane := repoName + "/" + name
	n := it.Note
	n.FM.Set("when", Now)
	n.FM.Set("lane", lane)
	if err := v.save(r, n); err != nil {
		return nil, err
	}
	v.banner(run, repoName, name)
	r.say("⚡ %s  → lane %s", it.Title, lane)
	r.say("   %s", dir)
	return v.finish(r, it)
}

// banner is the receipt: a background spawn puts nothing on any screen, so
// without it nothing says the lane took. Through haus-notify, so trill draws
// it and rules.json can route it; a `Go to lane` action only when trill would
// accept the target (its lane whitelist), else the banner minus the click.
func (v *Vault) banner(run Runner, repo, name string) {
	if NotifyPath == "" {
		return
	}
	args := []string{"--source", "tracker", "--kind", "pulse", "--symbol", "play.circle",
		"--thread", name, "--title", "tracker · agent lane", "--body", repo + " — " + name + " is working"}
	if target, ok := laneTarget(repo, name); ok {
		args = append(args, "--action", "Go to lane=lane:"+target)
	}
	_, _, _, _ = run.Run(nil, "", NotifyPath, args...)
}

var laneSafe = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)

// laneTarget is trill's whitelist, in full and halved: each side of a lane
// id is a basename with no slash of its own, no leading `-`, and the joined
// target at most 100 characters.
func laneTarget(repo, name string) (string, bool) {
	if repo == "" || name == "" || strings.HasPrefix(repo, "-") || !laneSafe.MatchString(repo) || !laneSafe.MatchString(name) {
		return "", false
	}
	if len(repo)+1+len(name) > 100 {
		return "", false
	}
	return repo + "/" + name, true
}

func expandHome(p string) string {
	if p == "~" || strings.HasPrefix(p, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, strings.TrimPrefix(p, "~"))
	}
	return p
}

// The words that carry no identity. "can you look into why the bar pill
// flickers" names itself `bar-pill-flickers`, not `can-you-look-into`.
var stopwords = map[string]bool{}

func init() {
	for _, w := range strings.Fields("a about all also an and any are as at be been being but by can could did do does doing done for from get give go going had has have how i if in into is it its just let make me my need needs no not now of on once only or our out over please put should so some still such take than that the their them then there these they this those to too try up us use want was way we were what when where which while who why will with would you your") {
		stopwords[w] = true
	}
}

var nonSlug = regexp.MustCompile(`[^a-z0-9]+`)

// Slug names a lane after its to-do: four words and forty bytes, whichever
// comes first, stopwords out on the first pass and back on the second for a
// title that is nothing else. A word that would bust either ends the name
// rather than being cut in half; the first word goes in whatever it costs.
func Slug(title string) string {
	words := strings.Fields(nonSlug.ReplaceAllString(strings.ToLower(title), " "))
	for _, keepAll := range []bool{false, true} {
		slug, kept := "", 0
		for _, w := range words {
			if len(w) < 2 || (!keepAll && stopwords[w]) {
				continue
			}
			next := w
			if slug != "" {
				next = slug + "-" + w
				if len(next) > 40 {
					break
				}
			}
			slug = next
			if kept++; kept >= 4 {
				break
			}
		}
		if slug != "" {
			return slug
		}
	}
	return "todo"
}
