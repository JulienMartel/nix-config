package tui

import (
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/x/ansi"

	"github.com/julienmartel/tracker/internal/vault"
)

// The TUI cannot be feel-tested here; this drives the model headless — a
// window size, then keys — and reads the frame back.

func model(t *testing.T, w, h int) *Model {
	t.Helper()
	src, _ := filepath.Abs(filepath.Join("..", "..", "testdata", "vault"))
	dst := t.TempDir()
	if err := copyTree(src, dst); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	v := vault.New(dst)
	v.SetToday("2026-09-20")
	if _, _, err := v.Migrate(); err != nil {
		t.Fatal(err)
	}
	m := New(v)
	m.load()
	m.Update(tea.WindowSizeMsg{Width: w, Height: h})
	return m
}

func copyTree(src, dst string) error {
	return filepath.WalkDir(src, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, p)
		if d.IsDir() {
			return os.MkdirAll(filepath.Join(dst, rel), 0o755)
		}
		in, err := os.Open(p)
		if err != nil {
			return err
		}
		defer in.Close()
		out, err := os.Create(filepath.Join(dst, rel))
		if err != nil {
			return err
		}
		defer out.Close()
		_, err = io.Copy(out, in)
		return err
	})
}

func press(m *Model, keys ...string) {
	for _, k := range keys {
		var msg tea.KeyMsg
		switch k {
		case "enter":
			msg = tea.KeyMsg{Type: tea.KeyEnter}
		case "esc":
			msg = tea.KeyMsg{Type: tea.KeyEsc}
		case "tab":
			msg = tea.KeyMsg{Type: tea.KeyTab}
		case "space":
			msg = tea.KeyMsg{Type: tea.KeySpace, Runes: []rune{' '}}
		case "ctrl+d":
			msg = tea.KeyMsg{Type: tea.KeyCtrlD}
		case "down":
			msg = tea.KeyMsg{Type: tea.KeyDown}
		default:
			msg = tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(k)}
		}
		m.Update(msg)
	}
}

func typeText(m *Model, s string) {
	for _, r := range s {
		m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{r}})
	}
}

// seek puts the list cursor on an id wherever it sorted. Walking down with
// `j` to find a row hangs when the row is above the cursor: `j` at the end of
// the list moves nothing.
func seek(t *testing.T, m *Model, id string) {
	t.Helper()
	for i, r := range m.rows {
		if r.item != nil && r.item.ID == id {
			m.listCur = i
			m.noteOff, m.checkCur = 0, -1
			return
		}
	}
	t.Fatalf("%s is not in the list", id)
}

// checkFrame proves no line reaches the last column and the frame is the
// window's height.
func checkFrame(t *testing.T, m *Model, w, h int) string {
	t.Helper()
	frame := m.View()
	lines := strings.Split(frame, "\n")
	if len(lines) > h {
		t.Errorf("%dx%d: %d lines for %d rows", w, h, len(lines), h)
	}
	for i, l := range lines {
		if cw := ansi.StringWidth(l); cw >= w {
			t.Errorf("%dx%d line %d is %d cells wide (max %d): %q", w, h, i, cw, w-1, ansi.Strip(l))
		}
	}
	return ansi.Strip(frame)
}

func TestFramesFitEverySize(t *testing.T) {
	for _, sz := range [][2]int{{140, 45}, {120, 40}, {100, 30}, {99, 30}, {90, 30}, {80, 24}, {70, 20}, {69, 20}, {60, 20}, {50, 16}, {30, 10}} {
		m := model(t, sz[0], sz[1])
		for _, keys := range [][]string{{}, {"j"}, {"tab"}, {"tab", "tab"}, {"?"}, {"a"}, {"m"}, {"/", "s"}, {"w"}, {"A"}} {
			press(m, keys...)
			checkFrame(t, m, sz[0], sz[1])
			press(m, "esc", "esc")
			m.mode = modeNormal
		}
		// Every sidebar row, with the cursor drawn.
		for i := 0; i < len(m.side); i++ {
			m.focus = paneSidebar
			m.sideCur = i
			m.buildRows()
			m.clampList()
			checkFrame(t, m, sz[0], sz[1])
		}
	}
}

func TestViewsAndCursor(t *testing.T) {
	m := model(t, 120, 40)
	frame := checkFrame(t, m, 120, 40)
	if !strings.Contains(frame, "Today 2") || !strings.Contains(frame, "Later 5") || !strings.Contains(frame, "Someday 1") || !strings.Contains(frame, "Inbox 2") {
		t.Errorf("header counts:\n%s", strings.SplitN(frame, "\n", 2)[0])
	}
	if !strings.Contains(frame, "hausfold") || !strings.Contains(frame, "ci") || !strings.Contains(frame, "3") {
		t.Error("project tree missing")
	}
	// Today: two items grouped by project; cursor on the first item.
	if it := m.current(); it == nil || it.ID != "buy cat food" {
		t.Errorf("first item %v", it)
	}
	press(m, "j")
	if it := m.current(); it == nil || it.ID != "hausfold/ship the thing" {
		t.Errorf("after j: %v", it)
	}
	press(m, "j")
	if it := m.current(); it.ID != "hausfold/ship the thing" {
		t.Error("j past the end moved")
	}
	press(m, "k", "k", "k")
	if it := m.current(); it.ID != "buy cat food" {
		t.Error("k past the top moved")
	}
	// The note pane shows the body and the checklist glyphs.
	press(m, "j")
	frame = checkFrame(t, m, 120, 40)
	if !strings.Contains(frame, "☐ draft") || !strings.Contains(frame, "☑ review") || !strings.Contains(frame, "#fable") {
		t.Errorf("note pane:\n%s", frame)
	}
	// Sidebar: down to Later.
	m.focus = paneSidebar
	press(m, "j")
	if m.sideCur != 1 || m.current() == nil || m.current().Bucket != vault.BucketLater {
		t.Errorf("Later view: side %d item %v", m.sideCur, m.current())
	}
	// Down to a project: rows grouped by bucket.
	for m.side[m.sideCur].folder == nil {
		if m.sideCur+1 >= len(m.side) {
			t.Fatal("no project folder in the sidebar")
		}
		press(m, "j")
	}
	frame = checkFrame(t, m, 120, 40)
	if !strings.Contains(frame, "1 · now") || !strings.Contains(frame, "3 · later") || !strings.Contains(frame, "ci/") {
		t.Errorf("project view:\n%s", frame)
	}
}

func TestAddDoneUndo(t *testing.T) {
	m := model(t, 120, 40)
	press(m, "a")
	if m.mode != modeAdd || m.addWhen != vault.Now {
		t.Fatalf("add from Today should default to now: %v %q", m.mode, m.addWhen)
	}
	press(m, "tab")
	if m.addWhen != vault.Later {
		t.Errorf("tab cycles: %q", m.addWhen)
	}
	press(m, "tab", "tab")
	typeText(m, "water the plants")
	press(m, "ctrl+d")
	if m.mode != modePrompt || m.prompt != promptAddDue {
		t.Fatal("ctrl+d opens the due prompt")
	}
	typeText(m, "+2d")
	press(m, "enter")
	if m.mode != modeAdd || m.addDue != "2026-09-22" || m.input.Value() != "water the plants" {
		t.Fatalf("back to add with due: %v %q %q", m.mode, m.addDue, m.input.Value())
	}
	press(m, "enter")
	got, err := os.ReadFile(m.v.Path("water the plants"))
	if err != nil || string(got) != "---\nwhen: now\ndue: 2026-09-22\ncreated: 2026-09-20\n---\n" {
		t.Fatalf("added: %v %q", err, got)
	}
	if !strings.Contains(m.status, "added: water the plants") {
		t.Errorf("status %q", m.status)
	}
	// It is on Today now (its due date sorts it above the cursor). Done, then undo.
	seek(t, m, "water the plants")
	press(m, "x")
	got, _ = os.ReadFile(m.v.Path("water the plants"))
	if !strings.Contains(string(got), "done: 2026-09-20") {
		t.Errorf("x did not close it: %s", got)
	}
	press(m, "u")
	got, _ = os.ReadFile(m.v.Path("water the plants"))
	if strings.Contains(string(got), "done:") || !strings.HasPrefix(m.status, "undone:") {
		t.Errorf("undo: %s / %q", got, m.status)
	}
	// Undo of an add removes the file.
	press(m, "a")
	typeText(m, "temp")
	press(m, "enter", "u")
	if _, err := os.Stat(m.v.Path("temp")); err == nil {
		t.Error("undo of add left the file")
	}
}

func TestMovePickerFilterAndPrompts(t *testing.T) {
	m := model(t, 120, 40)
	press(m, "m")
	if m.mode != modePicker || len(m.picker) < 3 || m.picker[0] != "inbox" {
		t.Fatalf("picker: %v %v", m.mode, m.picker)
	}
	typeText(m, "ci")
	if len(m.picker) == 0 || m.picker[0] != "hausfold/ci" {
		t.Errorf("fuzzy: %v", m.picker)
	}
	checkFrame(t, m, 120, 40)
	press(m, "enter")
	if _, err := os.Stat(m.v.Path("hausfold/ci/buy cat food")); err != nil {
		t.Errorf("move: %v / %q", err, m.status)
	}
	// Filter narrows the list live.
	m.focus = paneSidebar
	press(m, "j") // Later
	press(m, "/")
	typeText(m, "docs")
	n := 0
	for _, r := range m.rows {
		if r.item != nil {
			n++
		}
	}
	if n != 1 || m.current().ID != "hausfold/write docs" {
		t.Errorf("filter: %d rows, %v", n, m.current())
	}
	press(m, "enter")
	if m.filter != "docs" || m.mode != modeNormal {
		t.Error("enter keeps the filter")
	}
	press(m, "esc")
	if m.filter != "" {
		t.Error("esc clears the filter")
	}
	// Prompts: when, due, tags, rename.
	seek(t, m, "hausfold/write docs")
	press(m, "w")
	typeText(m, "tomorrow")
	press(m, "enter")
	got, _ := os.ReadFile(m.v.Path("hausfold/write docs"))
	if !strings.Contains(string(got), "when: 2026-09-21") {
		t.Errorf("when prompt: %s", got)
	}
	// It left the Later view, so find it under Upcoming.
	m.focus = paneSidebar
	press(m, "j", "j") // Upcoming
	if m.current() == nil || m.current().ID != "hausfold/write docs" {
		t.Fatalf("upcoming: %v", m.current())
	}
	press(m, "d")
	typeText(m, "2026-10-01")
	press(m, "enter")
	press(m, "t")
	m.input.SetValue("")
	typeText(m, "a, b")
	press(m, "enter")
	press(m, "r")
	m.input.SetValue("")
	typeText(m, "Write: docs")
	press(m, "enter")
	got, _ = os.ReadFile(m.v.Path("hausfold/Write docs"))
	if !strings.Contains(string(got), "due: 2026-10-01") || !strings.Contains(string(got), "tags:\n  - a\n  - b") || !strings.Contains(string(got), `title: "Write: docs"`) {
		t.Errorf("prompts: %s / %q", got, m.status)
	}
	// A bad date is an error in the status line, nothing written.
	press(m, "d")
	m.input.SetValue("")
	typeText(m, "nope")
	press(m, "enter")
	if !m.statusErr {
		t.Error("bad date should be an error")
	}
}

func TestChecklistTickAndNarrowLayouts(t *testing.T) {
	m := model(t, 120, 40)
	press(m, "j") // ship the thing
	press(m, "enter")
	if m.focus != paneNote {
		t.Fatal("enter opens the note pane")
	}
	press(m, "j")
	if m.checkCur != 0 {
		t.Fatalf("checklist cursor %d", m.checkCur)
	}
	press(m, "space")
	got, _ := os.ReadFile(m.v.Path("hausfold/ship the thing"))
	if !strings.Contains(string(got), "- [x] draft") {
		t.Errorf("tick: %s", got)
	}
	press(m, "j", "space")
	got, _ = os.ReadFile(m.v.Path("hausfold/ship the thing"))
	if !strings.Contains(string(got), "- [ ] review") {
		t.Errorf("untick: %s", got)
	}
	// Narrow: the tab strip carries the views.
	m.Update(tea.WindowSizeMsg{Width: 60, Height: 20})
	frame := checkFrame(t, m, 60, 20)
	if !strings.Contains(frame, "● Today") || !strings.Contains(frame, "○ Later") {
		t.Errorf("tab strip:\n%s", frame)
	}
	m.Update(tea.WindowSizeMsg{Width: 85, Height: 24})
	frame = checkFrame(t, m, 85, 24)
	if !strings.Contains(frame, "Today") || !strings.Contains(frame, "☐") && !strings.Contains(frame, "☑") {
		t.Errorf("medium layout:\n%s", frame)
	}
}

func TestHelpAndQuit(t *testing.T) {
	m := model(t, 100, 30)
	press(m, "?")
	frame := checkFrame(t, m, 100, 30)
	if !strings.Contains(frame, "spawn a lane") {
		t.Error("help overlay")
	}
	press(m, "j")
	if m.mode != modeNormal {
		t.Error("any key closes help")
	}
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("q")})
	if cmd == nil || !m.quit {
		t.Error("q quits")
	}
	if m.View() != "" {
		t.Error("the last frame is empty so the alt screen closes clean")
	}
}

func TestFuzzy(t *testing.T) {
	if s, ok := fuzzy("hausfold/ci", "hci"); !ok || s <= 0 {
		t.Error("subsequence match")
	}
	if _, ok := fuzzy("Personal", "xyz"); ok {
		t.Error("no match")
	}
	a, _ := fuzzy("hausfold/ci", "ci")
	b, _ := fuzzy("Personal/kitchen", "ci")
	if a <= b {
		t.Errorf("word-start match should win: %d vs %d", a, b)
	}
}

// n / l / s in the list pane are the three whens; each write leaves the row
// for another view, so the test follows it there. `l` is `later` only in the
// list pane — elsewhere it is the pane to the right.
func TestNowLaterSomeday(t *testing.T) {
	m := model(t, 90, 30)
	seek(t, m, "buy cat food")
	press(m, "l")
	if got, _ := os.ReadFile(m.v.Path("buy cat food")); !strings.Contains(string(got), "when: later\n") {
		t.Fatalf("l: %s", got)
	}
	if m.counts[0] != 1 {
		t.Errorf("Today should have lost it: %d", m.counts[0])
	}
	m.focus = paneSidebar
	press(m, "j") // Later
	m.focus = paneList
	seek(t, m, "buy cat food")
	press(m, "s")
	if got, _ := os.ReadFile(m.v.Path("buy cat food")); !strings.Contains(string(got), "when: someday\n") {
		t.Fatalf("s: %s", got)
	}
	m.focus = paneSidebar
	press(m, "j") // Someday
	m.focus = paneList
	seek(t, m, "buy cat food")
	press(m, "n")
	if got, _ := os.ReadFile(m.v.Path("buy cat food")); !strings.Contains(string(got), "when: now\n") {
		t.Fatalf("n: %s", got)
	}
	if m.counts[0] != 2 {
		t.Errorf("Today should have it back: %d", m.counts[0])
	}
	// `l` with the sidebar focused moves focus, writes nothing.
	m.focus = paneSidebar
	press(m, "l")
	if m.focus != paneList {
		t.Error("l from the sidebar should focus the list")
	}
	checkFrame(t, m, 90, 30)
}
