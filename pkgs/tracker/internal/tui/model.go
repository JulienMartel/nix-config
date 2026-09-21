// Package tui is the fullscreen face of the list: three panes, the seven
// views and the project tree, nebelung colours, keyboard only. Every write
// goes through the same vault code the CLI uses, so the two cannot drift;
// what this package adds is a cursor, a watcher and an undo.
package tui

import (
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"

	"github.com/julienmartel/tracker/internal/vault"
)

type pane int

const (
	paneSidebar pane = iota
	paneList
	paneNote
)

type mode int

const (
	modeNormal mode = iota
	modeAdd
	modePrompt
	modePicker
	modeFilter
	modeHelp
	modeConfirm
)

type promptKind int

const (
	promptWhen promptKind = iota
	promptDue
	promptTags
	promptRename
	promptAddDue
)

// view is one of the seven sidebar views; a project is view == -1.
type view struct {
	name  string
	glyph string
	keep  func(*vault.Item) bool
	group func(*vault.Item) string // "" = no groups
	less  []func(a, b *vault.Item) int
}

// sideItem is one sidebar row: a view or a project folder.
type sideItem struct {
	view   int // index into views, -1 for a folder
	folder *vault.Folder
}

// span is one clickable run on a row: columns [x0,x1) select index i.
type span struct{ x0, x1, i int }

// box is where one pane landed on screen this frame, and how its rows map back
// to indices: line n of the pane is hits[n] (-1 = not selectable).
type box struct {
	which          pane
	y0, y1, x0, x1 int
	hits           []int
}

// row is one list line: a group header (item == nil) or an item.
type row struct {
	header string
	item   *vault.Item
}

// Model is the whole TUI.
type Model struct {
	v       *vault.Vault
	idx     *vault.Index
	folders []*vault.Folder
	counts  []int
	lanes   int
	loadErr error

	width, height int
	focus         pane
	mode          mode

	side     []sideItem
	sideCur  int
	rows     []row
	listCur  int
	listOff  int
	sideOff  int
	noteOff  int
	checkCur int

	filter    string
	input     textinput.Model
	prompt    promptKind
	addWhen   string
	addDue    string
	addTitle  string
	picker    []string
	pickerCur int

	status    string
	statusErr bool
	undo      *vault.Change
	undoWhat  string

	// Where things were drawn last frame, for the mouse. Filled by View.
	tabHits  []span
	boxes    []box
	sideHits []int
	listHits []int

	reload  chan struct{}
	watcher *watcher
	quit    bool
}

// New builds the model over a vault; the index is loaded in Init.
func New(v *vault.Vault) *Model {
	in := textinput.New()
	in.Prompt = ""
	in.CharLimit = 200
	return &Model{v: v, input: in, focus: paneList, checkCur: -1, addWhen: vault.Later, reload: make(chan struct{}, 1)}
}

// Run opens the TUI and returns the exit code.
func Run(v *vault.Vault) int {
	m := New(v)
	// Mouse reporting: the header reads as a row of tabs and the panes as
	// lists, so they should answer a click. It costs the terminal's own
	// text selection, which in Ghostty comes back with ⇧ held.
	p := tea.NewProgram(m, tea.WithAltScreen(), tea.WithMouseCellMotion())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "tracker:", err)
		return 1
	}
	if m.watcher != nil {
		m.watcher.close()
	}
	return 0
}

// ── messages ─────────────────────────────────────────────────────────────────

type reloadMsg struct{}
type writeMsg struct {
	r   *vault.Report
	err error
}
type editedMsg struct{ err error }

func (m *Model) Init() tea.Cmd {
	m.load()
	if w, err := newWatcher(m.v.Dir, m.reload); err == nil {
		m.watcher = w
	}
	return m.waitReload()
}

func (m *Model) waitReload() tea.Cmd {
	ch := m.reload
	return func() tea.Msg {
		<-ch
		return reloadMsg{}
	}
}

// ── the index and what the panes show ────────────────────────────────────────

var views = []view{
	{name: "Today", glyph: "●", keep: func(it *vault.Item) bool { return it.Open() && it.Bucket == vault.BucketNow },
		group: byProject, less: []func(a, b *vault.Item) int{cmpDue, cmpTitle}},
	{name: "Later", glyph: "○", keep: func(it *vault.Item) bool { return it.Open() && it.Bucket == vault.BucketLater },
		group: byFolder, less: []func(a, b *vault.Item) int{cmpCreatedDesc, cmpTitle}},
	{name: "Someday", glyph: "◌", keep: func(it *vault.Item) bool { return it.Open() && it.Bucket == vault.BucketSomeday },
		group: byFolder, less: []func(a, b *vault.Item) int{cmpTitle}},
	{name: "Upcoming", glyph: "◔", keep: func(it *vault.Item) bool { return it.Open() && it.Bucket == vault.BucketScheduled },
		group: nil, less: []func(a, b *vault.Item) int{cmpWhen, cmpTitle}},
	{name: "Due", glyph: "!", keep: func(it *vault.Item) bool { return it.Open() && it.Due != "" },
		group: nil, less: []func(a, b *vault.Item) int{cmpDue, cmpTitle}},
	{name: "Inbox", glyph: "▸", keep: func(it *vault.Item) bool { return it.Open() && it.Folder == "" && it.Bucket == vault.BucketLater },
		group: nil, less: []func(a, b *vault.Item) int{cmpCreatedDesc, cmpTitle}},
	{name: "Done", glyph: "✓", keep: func(it *vault.Item) bool { return !it.IsProject && !it.Open() },
		group: byProject, less: []func(a, b *vault.Item) int{cmpClosedDesc, cmpTitle}},
}

func byProject(it *vault.Item) string {
	if it.Project == "" {
		return "unfiled"
	}
	return it.Project
}

func byFolder(it *vault.Item) string {
	if it.Folder == "" {
		return "unfiled"
	}
	return it.Folder
}

func cmpS(a, b string) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	}
	return 0
}

func cmpDateS(a, b string) int {
	switch {
	case a == b:
		return 0
	case a == "":
		return 1
	case b == "":
		return -1
	}
	return cmpS(a, b)
}

func cmpTitle(a, b *vault.Item) int       { return cmpS(strings.ToLower(a.Title), strings.ToLower(b.Title)) }
func cmpDue(a, b *vault.Item) int         { return cmpDateS(a.Due, b.Due) }
func cmpWhen(a, b *vault.Item) int        { return cmpDateS(a.When, b.When) }
func cmpCreatedDesc(a, b *vault.Item) int { return -cmpDateS(a.Created, b.Created) }
func cmpClosedDesc(a, b *vault.Item) int  { return -cmpS(a.Closed(), b.Closed()) }
func cmpBucket(a, b *vault.Item) int      { return cmpS(bucketKey(a.Bucket), bucketKey(b.Bucket)) }

func bucketKey(b string) string {
	switch b {
	case vault.BucketNow:
		return "1 · now"
	case vault.BucketScheduled:
		return "2 · scheduled"
	case vault.BucketLater:
		return "3 · later"
	}
	return "4 · someday"
}

// load reads the index and rebuilds everything derived from it, keeping the
// cursor on the same id where it still exists.
func (m *Model) load() {
	var curID, curSide string
	if it := m.current(); it != nil {
		curID = it.ID
	}
	if m.sideCur < len(m.side) && m.side[m.sideCur].folder != nil {
		curSide = m.side[m.sideCur].folder.Path
	}
	idx, err := m.v.Load()
	if err != nil {
		m.loadErr = err
		m.idx = &vault.Index{}
		m.folders = nil
	} else {
		m.loadErr = nil
		m.idx = idx
		m.folders = m.v.Folders(idx)
	}
	m.counts = make([]int, len(views))
	m.lanes = 0
	for _, it := range m.idx.Items {
		for i, vw := range views {
			if vw.keep(it) {
				m.counts[i]++
			}
		}
		if it.Open() && it.Lane != "" {
			m.lanes++
		}
	}
	m.side = m.side[:0]
	for i := range views {
		m.side = append(m.side, sideItem{view: i})
	}
	for _, f := range m.folders {
		m.side = append(m.side, sideItem{view: -1, folder: f})
	}
	if curSide != "" {
		m.sideCur = 0
		for i, s := range m.side {
			if s.folder != nil && s.folder.Path == curSide {
				m.sideCur = i
			}
		}
	}
	if m.sideCur >= len(m.side) {
		m.sideCur = 0
	}
	m.buildRows()
	if curID != "" {
		for i, r := range m.rows {
			if r.item != nil && r.item.ID == curID {
				m.listCur = i
			}
		}
	}
	m.clampList()
}

// buildRows is the list for the selected sidebar item, filtered.
func (m *Model) buildRows() {
	m.rows = m.rows[:0]
	if len(m.side) == 0 {
		return
	}
	s := m.side[m.sideCur]
	var items []*vault.Item
	var group func(*vault.Item) string
	var less []func(a, b *vault.Item) int
	if s.view >= 0 {
		vw := views[s.view]
		for _, it := range m.idx.Items {
			if vw.keep(it) {
				items = append(items, it)
			}
		}
		group, less = vw.group, vw.less
		if s.view == len(views)-1 && len(items) > 200 {
			sortItems(items, less)
			items = items[:200]
		}
	} else {
		f := s.folder.Path
		for _, it := range m.idx.Open() {
			if it.Folder == f || strings.HasPrefix(it.Folder, f+"/") {
				items = append(items, it)
			}
		}
		group = func(it *vault.Item) string { return bucketKey(it.Bucket) }
		less = []func(a, b *vault.Item) int{cmpBucket, cmpDue, cmpTitle}
	}
	if q := strings.ToLower(m.filter); q != "" {
		var kept []*vault.Item
		for _, it := range items {
			if strings.Contains(strings.ToLower(it.Title), q) || strings.Contains(strings.ToLower(it.ID), q) || strings.Contains(strings.ToLower(strings.Join(it.Tags, " ")), q) {
				kept = append(kept, it)
			}
		}
		items = kept
	}
	if group != nil {
		// Unfiled first: a to-do with no project is what needs filing.
		key := func(it *vault.Item) string {
			g := group(it)
			if g == "unfiled" {
				return ""
			}
			return strings.ToLower(g)
		}
		less = append([]func(a, b *vault.Item) int{func(a, b *vault.Item) int { return cmpS(key(a), key(b)) }}, less...)
	}
	sortItems(items, less)
	prev := "\x00"
	for _, it := range items {
		if group != nil {
			if g := group(it); g != prev {
				m.rows = append(m.rows, row{header: g})
				prev = g
			}
		}
		m.rows = append(m.rows, row{item: it})
	}
}

func sortItems(items []*vault.Item, less []func(a, b *vault.Item) int) {
	sort.SliceStable(items, func(i, j int) bool {
		for _, l := range less {
			if c := l(items[i], items[j]); c != 0 {
				return c < 0
			}
		}
		return false
	})
}

// current is the item under the list cursor, nil on a header or nothing.
func (m *Model) current() *vault.Item {
	if m.listCur >= 0 && m.listCur < len(m.rows) {
		return m.rows[m.listCur].item
	}
	return nil
}

// currentFolder is the project the sidebar is on, "" for a view.
func (m *Model) currentFolder() string {
	if m.sideCur < len(m.side) && m.side[m.sideCur].folder != nil {
		return m.side[m.sideCur].folder.Path
	}
	return ""
}

func (m *Model) clampList() {
	if len(m.rows) == 0 {
		m.listCur, m.listOff = 0, 0
		return
	}
	if m.listCur >= len(m.rows) {
		m.listCur = len(m.rows) - 1
	}
	if m.listCur < 0 {
		m.listCur = 0
	}
	// Never rest on a header.
	if m.rows[m.listCur].item == nil {
		if m.listCur+1 < len(m.rows) {
			m.listCur++
		} else if m.listCur > 0 {
			m.listCur--
		}
	}
	m.noteOff = 0
	m.checkCur = -1
}

// moveList steps the list cursor over headers.
func (m *Model) moveList(delta int) {
	if len(m.rows) == 0 {
		return
	}
	i := m.listCur
	for {
		i += delta
		if i < 0 || i >= len(m.rows) {
			return
		}
		if m.rows[i].item != nil {
			m.listCur = i
			m.noteOff, m.checkCur = 0, -1
			return
		}
	}
}

// viewIndex is the view the list is showing. The sidebar's cursor doubles as it,
// so a project row (view -1) reports the view it was filtered out of — which is
// what makes ⇥ from a project land on Today rather than nowhere.
func (m *Model) viewIndex() int {
	if m.sideCur >= 0 && m.sideCur < len(m.side) && m.side[m.sideCur].view >= 0 {
		return m.side[m.sideCur].view
	}
	return 0
}

// gotoView selects a view by index, wrapping, and is what ⇥ and the digits and
// a click on the header all go through.
func (m *Model) gotoView(i int) {
	if len(views) == 0 {
		return
	}
	if i < 0 {
		i = len(views) - 1
	}
	if i >= len(views) {
		i = 0
	}
	m.selectSide(i)
}

// selectSide puts the sidebar cursor on one row and rebuilds the list under it.
func (m *Model) selectSide(i int) {
	if i < 0 || i >= len(m.side) || i == m.sideCur {
		return
	}
	m.sideCur = i
	m.listCur, m.listOff = 0, 0
	m.buildRows()
	m.clampList()
}

func (m *Model) moveSide(delta int) {
	n := m.sideCur + delta
	if n < 0 || n >= len(m.side) {
		return
	}
	m.sideCur = n
	m.listCur, m.listOff = 0, 0
	m.buildRows()
	m.clampList()
}

// ── writes ───────────────────────────────────────────────────────────────────

// did records a write's result: the status line, the undo, and a reload.
func (m *Model) did(r *vault.Report, err error) {
	if err != nil {
		m.status, m.statusErr = err.Error(), true
		return
	}
	m.statusErr = false
	if len(r.Lines) > 0 {
		m.status = r.Lines[0]
	}
	if len(r.Change.Files) > 0 {
		c := r.Change
		m.undo, m.undoWhat = &c, m.status
	}
	m.load()
}

func (m *Model) undoLast() {
	if m.undo == nil {
		m.status, m.statusErr = "nothing to undo", false
		return
	}
	if err := m.undo.Undo(); err != nil {
		m.status, m.statusErr = err.Error(), true
		return
	}
	m.status, m.statusErr = "undone: "+m.undoWhat, false
	m.undo = nil
	m.load()
}

// toggleCheck flips the checklist line under the note cursor.
func (m *Model) toggleCheck() {
	it := m.current()
	if it == nil || m.checkCur < 0 {
		return
	}
	lines := strings.Split(it.Body(), "\n")
	k := 0
	for i, l := range lines {
		box, ok := checkbox(l)
		if !ok {
			continue
		}
		if k == m.checkCur {
			if box == " " {
				lines[i] = strings.Replace(l, "[ ]", "[x]", 1)
			} else {
				lines[i] = strings.Replace(l, "["+box+"]", "[ ]", 1)
			}
			break
		}
		k++
	}
	cur := m.checkCur
	m.did(m.v.SetBody(it, strings.Join(lines, "\n")))
	m.checkCur = cur
}

// checkbox is the state of a `- [ ]` line, and whether it is one.
func checkbox(line string) (string, bool) {
	t := strings.TrimLeft(line, " \t")
	if len(t) >= 5 && (t[0] == '-' || t[0] == '*') && t[1] == ' ' && t[2] == '[' && t[4] == ']' {
		return string(t[3]), true
	}
	return "", false
}

func (m *Model) checklistCount() int {
	it := m.current()
	if it == nil {
		return 0
	}
	n := 0
	for _, l := range strings.Split(it.Body(), "\n") {
		if _, ok := checkbox(l); ok {
			n++
		}
	}
	return n
}

// ── commands that leave the program for a moment ─────────────────────────────

func (m *Model) editCmd(it *vault.Item) tea.Cmd {
	ed := os.Getenv("EDITOR")
	if ed == "" {
		ed = "vi"
	}
	parts := strings.Fields(ed)
	c := exec.Command(parts[0], append(parts[1:], it.Path)...)
	return tea.ExecProcess(c, func(err error) tea.Msg { return editedMsg{err} })
}

// openCmd hands the note to Obsidian: the user's key, the user's screen.
func (m *Model) openCmd(it *vault.Item) tea.Cmd {
	url := m.v.ObsidianURL(it.Path)
	return func() tea.Msg {
		err := exec.Command("open", url).Start()
		return writeMsg{r: &vault.Report{Lines: []string{"opened in Obsidian: " + it.ID}}, err: err}
	}
}

// spawnCmd runs `tracker spawn` off the UI thread, on its own index so the
// one under the cursor is never written from two goroutines.
func (m *Model) spawnCmd(id string) tea.Cmd {
	v := m.v
	return func() tea.Msg {
		idx, err := v.Load()
		if err != nil {
			return writeMsg{err: err}
		}
		it := idx.Get(id)
		if it == nil {
			return writeMsg{err: vault.RefusedError(id + " is gone")}
		}
		r, err := v.Spawn(idx, it, vault.SpawnOpts{}, vault.ExecRunner{})
		return writeMsg{r: r, err: err}
	}
}
