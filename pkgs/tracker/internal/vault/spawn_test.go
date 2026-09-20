package vault

import (
	"strings"
	"testing"
)

// fakeRunner records every command and answers like scruff would.
type fakeRunner struct {
	calls [][]string
	envs  [][]string
	stdin []string
	dir   string
	code  int
}

func (f *fakeRunner) Run(env []string, stdin string, name string, args ...string) (string, string, int, error) {
	f.calls = append(f.calls, append([]string{name}, args...))
	f.envs = append(f.envs, env)
	f.stdin = append(f.stdin, stdin)
	if name == "scruff" && len(args) > 0 && args[0] == "agent" {
		return "claude\n", "", 0, nil
	}
	if name == "scruff" {
		return f.dir + "\n", "boom", f.code, nil
	}
	return "", "", 0, nil
}

func TestSpawn(t *testing.T) {
	v, idx := migrated(t)
	it, _ := v.Resolve(idx, "ship the thing", false)
	run := &fakeRunner{dir: "/Users/me/.cache/scruff/workshop/ship-thing"}

	p, err := v.Plan(idx, it, SpawnOpts{}, run)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasSuffix(p.Repo, "/code/workshop") || p.Slug != "ship-thing" || p.Agent != "claude" {
		t.Errorf("plan: %+v", p)
	}
	if !strings.HasPrefix(p.Prompt, "ship the thing\n\nWhere: haus.\n\n- [ ] draft\n- [x] review\n\ntracker: hausfold/ship the thing\nOn /ship: tracker done \"hausfold/ship the thing\"\n") {
		t.Errorf("prompt:\n%s", p.Prompt)
	}
	if strings.Join(p.Args, " ") != "spawn "+p.Repo+" --derived-name ship-thing --agent claude --prompt-file -" || p.Env[0] != "HAUS_LANE_BACKGROUND=1" {
		t.Errorf("args %v env %v", p.Args, p.Env)
	}
	if p, _ := v.Plan(idx, it, SpawnOpts{Follow: true}, run); p.Env[0] != "HAUS_LANE_BACKGROUND=" {
		t.Errorf("follow env %v", p.Env)
	}

	// No repo anywhere: refused, naming the project to set it on.
	orphan, _ := v.Resolve(idx, "buy cat food", false)
	if _, err := v.Plan(idx, orphan, SpawnOpts{}, run); err == nil || !strings.Contains(err.Error(), "--repo") {
		t.Errorf("want a refusal naming --repo, got %v", err)
	}
	mom, _ := v.Resolve(idx, "call mom", false)
	if _, err := v.Plan(idx, mom, SpawnOpts{}, run); err == nil || !strings.Contains(err.Error(), `tracker project set "Personal" repo=<path>`) {
		t.Errorf("want the project named, got %v", err)
	}
	if p, err := v.Plan(idx, mom, SpawnOpts{Repo: "/tmp"}, run); err != nil || p.Repo != "/tmp" {
		t.Errorf("--repo fallback: %v %v", p, err)
	}

	// Dry run prints the command and writes nothing.
	v.DryRun = true
	run = &fakeRunner{dir: "/x"}
	r, err := v.Spawn(idx, it, SpawnOpts{}, run)
	if err != nil || !strings.HasPrefix(r.Lines[0], "would run: HAUS_LANE_BACKGROUND=1 scruff spawn ") {
		t.Fatalf("dry run: %v %v", r, err)
	}
	if len(run.calls) != 1 || strings.Contains(mustRead(t, it.Path), "lane:") {
		t.Errorf("dry run touched something: %v", run.calls)
	}
	v.DryRun = false

	// The real thing, against the fake: the note gets its lane and the banner fires.
	NotifyPath = "haus-notify"
	run = &fakeRunner{dir: t.TempDir()}
	r, err = v.Spawn(idx, it, SpawnOpts{Repo: "/tmp"}, run)
	if err != nil {
		t.Fatal(err)
	}
	got := mustRead(t, it.Path)
	laneName := run.dir[strings.LastIndex(run.dir, "/")+1:]
	if !strings.Contains(got, "when: now\n") || !strings.Contains(got, "lane: workshop/"+laneName+"\n") {
		t.Errorf("after spawn:\n%s", got)
	}
	spawn := run.calls[1]
	if spawn[0] != "scruff" || spawn[1] != "spawn" || !strings.HasSuffix(run.stdin[1], "tracker done \"hausfold/ship the thing\"\n") {
		t.Errorf("spawn call %v", spawn)
	}
	banner := run.calls[2]
	if banner[0] != "haus-notify" || !strings.Contains(strings.Join(banner, " "), "--source tracker --kind pulse") || !strings.Contains(strings.Join(banner, " "), "--action Go to lane=lane:workshop/"+laneName) {
		t.Errorf("banner %v", banner)
	}
	// A note with a lane refuses without --again.
	idx, _ = v.Load()
	it, _ = v.Resolve(idx, "ship the thing", false)
	if _, err := v.Spawn(idx, it, SpawnOpts{Repo: "/tmp"}, run); err == nil || !strings.Contains(err.Error(), "--again") {
		t.Errorf("want --again refusal, got %v", err)
	}
	// scruff failing is reported, and nothing is written.
	bad := &fakeRunner{dir: "", code: 3}
	if _, err := v.Spawn(idx, it, SpawnOpts{Repo: "/tmp", Again: true}, bad); err == nil || !strings.Contains(err.Error(), "boom") {
		t.Errorf("want scruff's stderr, got %v", err)
	}
}

func TestSlug(t *testing.T) {
	cases := map[string]string{
		"can you look into why the bar pill flickers": "look-bar-pill-flickers",
		"the": "the",
		"A bare darwinModules.windows import needs six overlays nobody names": "bare-darwinmodules-windows-import",
		"fix \"JULIEN BERNARD MARTEL\" as the published in ios app store":     "fix-julien-bernard-martel",
		"": "todo",
		"supercalifragilisticexpialidocious-and-then-some words": "supercalifragilisticexpialidocious-words",
	}
	for in, want := range cases {
		if got := Slug(in); got != want {
			t.Errorf("Slug(%q) = %q, want %q", in, got, want)
		}
	}
	if _, ok := laneTarget("work shop", "x"); ok {
		t.Error("a space is not a lane target")
	}
	if tgt, ok := laneTarget("workshop", "ship-thing"); !ok || tgt != "workshop/ship-thing" {
		t.Error("lane target")
	}
}
