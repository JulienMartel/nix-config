package tui

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/julienmartel/tracker/internal/vault"
)

// ── keys ─────────────────────────────────────────────────────────────────────

func (m *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.clampList()
		return m, nil
	case reloadMsg:
		m.load()
		return m, m.waitReload()
	case writeMsg:
		m.did(msg.r, msg.err)
		return m, nil
	case editedMsg:
		if msg.err != nil {
			m.status, m.statusErr = msg.err.Error(), true
		} else {
			m.status, m.statusErr = "edited", false
		}
		m.load()
		return m, nil
	case tea.MouseMsg:
		return m.mouse(msg)
	case tea.KeyMsg:
		return m.key(msg)
	}
	return m, nil
}

// mouse: a click selects what is under it, the wheel scrolls the pane under the
// pointer. Everything it can do has a key as well — this is for the hand that
// is already on the trackpad, never the only way to reach something.
func (m *Model) mouse(e tea.MouseMsg) (tea.Model, tea.Cmd) {
	// A modal owns the screen; a stray click behind it must not move the list.
	if m.mode != modeNormal {
		return m, nil
	}
	switch e.Button {
	case tea.MouseButtonWheelUp:
		return m, m.scrollAt(e.X, e.Y, -1)
	case tea.MouseButtonWheelDown:
		return m, m.scrollAt(e.X, e.Y, 1)
	case tea.MouseButtonLeft:
		if e.Action != tea.MouseActionPress {
			return m, nil
		}
	default:
		return m, nil
	}
	// The tab bar, which is what the header looks like.
	if e.Y < headerH {
		for _, sp := range m.tabHits {
			if e.X >= sp.x0 && e.X < sp.x1 {
				m.gotoView(sp.i)
				return m, nil
			}
		}
		return m, nil
	}
	b := m.boxAt(e.X, e.Y)
	if b == nil {
		return m, nil
	}
	switch b.which {
	case paneSidebar:
		if i := hitIndex(b, e.Y); i >= 0 {
			m.focus = paneSidebar
			m.selectSide(i)
		}
	case paneList:
		if i := hitIndex(b, e.Y); i >= 0 {
			// A click on the row already under the cursor is the second half
			// of "open it" — the same thing ⏎ does from here.
			if m.focus == paneList && i == m.listCur {
				m.focus = paneNote
			} else {
				m.focus = paneList
				m.listCur = i
				m.noteOff, m.checkCur = 0, 0
			}
		}
	case paneNote:
		m.focus = paneNote
	}
	return m, nil
}

// boxAt is the pane drawn under a point last frame.
func (m *Model) boxAt(x, y int) *box {
	for i := range m.boxes {
		b := &m.boxes[i]
		if y >= b.y0 && y < b.y1 && x >= b.x0 && x < b.x1 {
			return b
		}
	}
	return nil
}

// hitIndex maps a screen row back to the index the pane drew there.
func hitIndex(b *box, y int) int {
	n := y - b.y0
	if n < 0 || n >= len(b.hits) {
		return -1
	}
	return b.hits[n]
}

// scrollAt moves the pane under the pointer without taking focus from the one
// that has it — the wheel is a look, not a choice.
func (m *Model) scrollAt(x, y, delta int) tea.Cmd {
	b := m.boxAt(x, y)
	if b == nil {
		if y < headerH {
			m.gotoView(m.viewIndex() + delta)
		}
		return nil
	}
	saved := m.focus
	m.focus = b.which
	m.down(delta * 3)
	m.focus = saved
	return nil
}

func (m *Model) key(k tea.KeyMsg) (tea.Model, tea.Cmd) {
	if k.Type == tea.KeyCtrlC {
		m.quit = true
		return m, tea.Quit
	}
	switch m.mode {
	case modeHelp:
		m.mode = modeNormal
		return m, nil
	case modeAdd:
		return m.keyAdd(k)
	case modePrompt:
		return m.keyPrompt(k)
	case modePicker:
		return m.keyPicker(k)
	case modeFilter:
		return m.keyFilter(k)
	case modeConfirm:
		return m.keyConfirm(k)
	}
	return m.keyNormal(k)
}

func (m *Model) keyNormal(k tea.KeyMsg) (tea.Model, tea.Cmd) {
	it := m.current()
	s := k.String()
	switch s {
	case "q":
		m.quit = true
		return m, tea.Quit
	case "?":
		m.mode = modeHelp
		return m, nil
	case "tab", "]":
		m.gotoView(m.viewIndex() + 1)
		return m, nil
	case "shift+tab", "[":
		m.gotoView(m.viewIndex() - 1)
		return m, nil
	case "right":
		m.focus = (m.focus + 1) % 3
		return m, nil
	case "left":
		m.focus = (m.focus + 2) % 3
		return m, nil
	case "1", "2", "3", "4", "5", "6", "7", "8", "9":
		// The header is a row of tabs and reads like one, so it gets the
		// numbers as well as the cycle. Out of range is a no-op, not an error:
		// the count moves with the views table, and a digit is not a wrap.
		if n := int(s[0] - '1'); n < len(views) {
			m.gotoView(n)
		}
		return m, nil
	case "esc":
		if m.filter != "" {
			m.filter = ""
			m.buildRows()
			m.clampList()
		} else if m.focus != paneList {
			m.focus = paneList
		}
		return m, nil
	case "j", "down":
		m.down(1)
		return m, nil
	case "k", "up":
		m.down(-1)
		return m, nil
	case "ctrl+d", "pgdown":
		m.down(m.pageSize())
		return m, nil
	case "ctrl+u", "pgup":
		m.down(-m.pageSize())
		return m, nil
	case "g", "home":
		m.down(-1 << 20)
		return m, nil
	case "G", "end":
		m.down(1 << 20)
		return m, nil
	case "enter":
		switch m.focus {
		case paneSidebar:
			m.focus = paneList
		case paneList:
			m.focus = paneNote
		}
		return m, nil
	case "/":
		m.mode = modeFilter
		m.input.SetValue(m.filter)
		m.input.Focus()
		m.input.CursorEnd()
		return m, nil
	case "a":
		m.mode = modeAdd
		m.addWhen = vault.Later
		if m.sideCur < len(views) {
			switch views[m.sideCur].name {
			case "Today":
				m.addWhen = vault.Now
			case "Someday":
				m.addWhen = vault.Someday
			}
		}
		m.addDue = ""
		m.input.SetValue("")
		m.input.Focus()
		return m, nil
	case "u":
		m.undoLast()
		return m, nil
	case "A":
		m.mode = modeConfirm
		return m, nil
	}
	if it == nil {
		return m, nil
	}
	switch s {
	case " ":
		if m.focus == paneNote && m.checkCur >= 0 {
			m.toggleCheck()
			return m, nil
		}
		m.did(m.v.Done(it))
	case "x":
		m.did(m.v.Done(it))
	case "X":
		m.did(m.v.Drop(it))
	case "n":
		m.did(m.v.SetWhen(it, vault.Now))
	case "l":
		m.did(m.v.SetWhen(it, vault.Later))
	case "s":
		m.did(m.v.SetWhen(it, vault.Someday))
	case "w":
		m.openPrompt(promptWhen, it.When)
	case "d":
		m.openPrompt(promptDue, it.Due)
	case "t":
		m.openPrompt(promptTags, strings.Join(it.Tags, ", "))
	case "r":
		m.openPrompt(promptRename, it.Title)
	case "m":
		m.mode = modePicker
		m.input.SetValue("")
		m.input.Focus()
		m.pickerCur = 0
		m.buildPicker()
	case "S":
		if it.Lane != "" {
			m.status, m.statusErr = it.ID+" already has a lane: "+it.Lane, true
			return m, nil
		}
		m.status, m.statusErr = "spawning a lane for "+it.Title+"…", false
		return m, m.spawnCmd(it.ID)
	case "e":
		return m, m.editCmd(it)
	case "o":
		return m, m.openCmd(it)
	case "R":
		if !it.Open() {
			m.did(m.v.Reopen(it))
		}
	}
	return m, nil
}

func (m *Model) pageSize() int {
	h := m.bodyHeight() - 2
	if h < 1 {
		return 1
	}
	return h
}

// down moves the focused pane's cursor.
func (m *Model) down(delta int) {
	switch m.focus {
	case paneSidebar:
		n := m.sideCur + delta
		if n < 0 {
			n = 0
		}
		if n >= len(m.side) {
			n = len(m.side) - 1
		}
		if n != m.sideCur {
			m.moveSide(n - m.sideCur)
		}
	case paneList:
		if delta > 1 || delta < -1 {
			step := 1
			if delta < 0 {
				step, delta = -1, -delta
			}
			for i := 0; i < delta; i++ {
				m.moveList(step)
			}
			return
		}
		m.moveList(delta)
	case paneNote:
		if n := m.checklistCount(); n > 0 {
			c := m.checkCur + delta
			if c < -1 {
				c = -1
			}
			if c >= n {
				c = n - 1
			}
			m.checkCur = c
			return
		}
		m.noteOff += delta
		if m.noteOff < 0 {
			m.noteOff = 0
		}
	}
}

// ── the one-line box: add, prompts, filter ───────────────────────────────────

// openPrompt opens the one-line box. A value to EDIT (tags, a title) is
// prefilled; one to REPLACE (when, due) is shown as the placeholder so the
// first keystroke is the answer.
func (m *Model) openPrompt(kind promptKind, current string) {
	m.mode = modePrompt
	m.prompt = kind
	m.input.Placeholder = ""
	switch kind {
	case promptTags, promptRename:
		m.input.SetValue(current)
	default:
		m.input.SetValue("")
		m.input.Placeholder = current
	}
	m.input.Focus()
	m.input.CursorEnd()
}

func (m *Model) closeInput() {
	m.mode = modeNormal
	m.input.Blur()
	m.input.SetValue("")
}

func (m *Model) keyAdd(k tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch k.String() {
	case "esc":
		m.closeInput()
		return m, nil
	case "tab":
		m.addWhen = map[string]string{vault.Now: vault.Later, vault.Later: vault.Someday, vault.Someday: vault.Now}[m.addWhen]
		return m, nil
	case "ctrl+d":
		title := m.input.Value()
		m.openPrompt(promptAddDue, m.addDue)
		m.addTitle = title
		return m, nil
	case "enter":
		title := strings.TrimSpace(m.input.Value())
		if title == "" {
			m.closeInput()
			return m, nil
		}
		m.closeInput()
		m.did(m.v.Add(vault.NewTodo{Title: title, Folder: m.currentFolder(), When: m.addWhen, Due: m.addDue}))
		return m, nil
	}
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(k)
	return m, cmd
}

func (m *Model) keyPrompt(k tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch k.String() {
	case "esc":
		if m.prompt == promptAddDue {
			m.backToAdd()
			return m, nil
		}
		m.closeInput()
		return m, nil
	case "enter":
		val := strings.TrimSpace(m.input.Value())
		it := m.current()
		if m.prompt == promptAddDue {
			d := ""
			if val != "" && val != "none" {
				var err error
				if d, err = vault.ParseDate(val, m.v.Now()); err != nil {
					m.status, m.statusErr = err.Error(), true
					return m, nil
				}
			}
			m.addDue = d
			m.backToAdd()
			return m, nil
		}
		m.closeInput()
		if it == nil {
			return m, nil
		}
		switch m.prompt {
		case promptWhen:
			w, err := vault.ParseWhen(val, m.v.Now())
			if err != nil {
				m.status, m.statusErr = err.Error(), true
				return m, nil
			}
			m.did(m.v.SetWhen(it, w))
		case promptDue:
			d := ""
			if val != "" && val != "none" {
				var err error
				if d, err = vault.ParseDate(val, m.v.Now()); err != nil {
					m.status, m.statusErr = err.Error(), true
					return m, nil
				}
			}
			m.did(m.v.SetDue(it, d))
		case promptTags:
			m.did(m.v.SetTags(it, vault.Tags(val)))
		case promptRename:
			if val != "" && val != it.Title {
				m.did(m.v.Rename(it, val))
			}
		}
		return m, nil
	}
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(k)
	return m, cmd
}

func (m *Model) backToAdd() {
	m.mode = modeAdd
	m.input.SetValue(m.addTitle)
	m.input.Focus()
	m.input.CursorEnd()
}

func (m *Model) keyFilter(k tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch k.String() {
	case "esc":
		m.filter = ""
		m.closeInput()
		m.buildRows()
		m.clampList()
		return m, nil
	case "enter":
		m.filter = strings.TrimSpace(m.input.Value())
		m.closeInput()
		m.focus = paneList
		m.buildRows()
		m.clampList()
		return m, nil
	}
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(k)
	m.filter = m.input.Value()
	m.buildRows()
	m.clampList()
	return m, cmd
}

func (m *Model) keyConfirm(k tea.KeyMsg) (tea.Model, tea.Cmd) {
	m.mode = modeNormal
	if k.String() == "y" || k.String() == "Y" {
		m.did(m.v.Archive(m.idx, 30))
	}
	return m, nil
}

// ── the project picker (m) ───────────────────────────────────────────────────

func (m *Model) buildPicker() {
	q := strings.ToLower(strings.TrimSpace(m.input.Value()))
	m.picker = m.picker[:0]
	type scored struct {
		path  string
		score int
	}
	var all []scored
	if s, ok := fuzzy("inbox", q); ok {
		all = append(all, scored{"inbox", s})
	}
	for _, f := range m.folders {
		if s, ok := fuzzy(f.Path, q); ok {
			all = append(all, scored{f.Path, s})
		}
	}
	for i := 1; i < len(all); i++ {
		for j := i; j > 0 && all[j].score > all[j-1].score; j-- {
			all[j], all[j-1] = all[j-1], all[j]
		}
	}
	for _, s := range all {
		m.picker = append(m.picker, s.path)
	}
	if m.pickerCur >= len(m.picker) {
		m.pickerCur = 0
	}
}

// fuzzy is a subsequence match: every rune of q in order, contiguous runs
// scoring higher, a match at a word start higher still.
func fuzzy(s, q string) (int, bool) {
	if q == "" {
		return 0, true
	}
	ls := strings.ToLower(s)
	score, last := 0, -1
	for _, r := range q {
		i := strings.IndexRune(ls[last+1:], r)
		if i < 0 {
			return 0, false
		}
		i += last + 1
		switch {
		case i == 0 || ls[i-1] == ' ' || ls[i-1] == '/' || ls[i-1] == '-':
			score += 2
		case i == last+1:
			score += 3
		default:
			score++
		}
		last = i
	}
	return score - len(s)/8, true
}

func (m *Model) keyPicker(k tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch k.String() {
	case "esc":
		m.closeInput()
		return m, nil
	case "down", "ctrl+n", "tab":
		if m.pickerCur+1 < len(m.picker) {
			m.pickerCur++
		}
		return m, nil
	case "up", "ctrl+p", "shift+tab":
		if m.pickerCur > 0 {
			m.pickerCur--
		}
		return m, nil
	case "enter":
		it := m.current()
		m.closeInput()
		if it == nil || m.pickerCur >= len(m.picker) {
			return m, nil
		}
		dest := m.picker[m.pickerCur]
		if dest == "inbox" {
			dest = ""
		}
		m.did(m.v.Move(it, dest))
		return m, nil
	}
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(k)
	m.buildPicker()
	return m, cmd
}

var _ = fmt.Sprintf
