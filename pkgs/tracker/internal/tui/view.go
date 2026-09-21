package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"

	"github.com/julienmartel/tracker/internal/theme"
	"github.com/julienmartel/tracker/internal/vault"
)

// ── drawing ──────────────────────────────────────────────────────────────────
//
// Every line is cut to width-1 cells and padded to exactly that, so nothing
// ever reaches the terminal's last column (where a terminal wraps) and a
// repaint never leaves a stale cell behind. Three layouts by width: three
// columns from 100, the note under the list from 70, and a tab strip for the
// sidebar below that.

const (
	wideAt   = 100
	mediumAt = 70
	sidebarW = 22
	headerH  = 2
	footerH  = 3
	minNoteW = 28
	maxNoteW = 60
)

// fit cuts s to w cells with … and pads it to exactly w.
func fit(s string, w int) string {
	if w <= 0 {
		return ""
	}
	s = strings.ReplaceAll(s, "\t", "  ")
	if ansi.StringWidth(s) > w {
		s = ansi.Truncate(s, w, "…")
	}
	if pad := w - ansi.StringWidth(s); pad > 0 {
		s += strings.Repeat(" ", pad)
	}
	return s
}

// column pads or cuts lines to exactly h rows of w cells.
func column(lines []string, w, h int) []string {
	out := make([]string, 0, h)
	for i := 0; i < h; i++ {
		if i < len(lines) {
			out = append(out, fit(lines[i], w))
		} else {
			out = append(out, strings.Repeat(" ", w))
		}
	}
	return out
}

func (m *Model) usable() int { return m.width - 1 }

func (m *Model) bodyHeight() int {
	h := m.height - headerH - footerH
	if m.usable() < mediumAt {
		h-- // the tab strip
	}
	return h
}

func (m *Model) View() string {
	if m.quit {
		return ""
	}
	w := m.usable()
	if w < 20 || m.height < 8 {
		return fit("tracker: the window is too small", w)
	}
	var lines []string
	lines = append(lines, m.header()...)
	if m.mode == modeHelp {
		lines = append(lines, column(m.help(), w, m.bodyHeight())...)
	} else {
		lines = append(lines, m.body()...)
	}
	lines = append(lines, m.footer()...)
	if len(lines) > m.height {
		lines = lines[:m.height]
	}
	return strings.Join(lines, "\n")
}

func (m *Model) header() []string {
	w := m.usable()
	var b strings.Builder
	b.WriteString(theme.Accent.Bold(true).Render("tracker"))
	b.WriteString("  ")
	m.tabHits = m.tabHits[:0]
	col := lipgloss.Width("tracker") + 2
	cur := m.viewIndex()
	for i, vw := range views {
		label := fmt.Sprintf("%s %d", vw.name, m.counts[i])
		if vw.name == "Done" {
			label = vw.name
		}
		// The digit is the key that jumps here (update.go), dim so the tab
		// still reads as its name.
		num := fmt.Sprintf("%d", i+1)
		b.WriteString(theme.Rule.Render(num) + " ")
		if cur == i {
			b.WriteString(theme.Bold.Render(label))
		} else {
			b.WriteString(theme.Field.Render(label))
		}
		b.WriteString("  ")
		wide := lipgloss.Width(num) + 1 + lipgloss.Width(label)
		m.tabHits = append(m.tabHits, span{x0: col, x1: col + wide, i: i})
		col += wide + 2
	}
	if m.lanes > 0 {
		b.WriteString(theme.Rule.Render("│ ") + theme.Accent.Render(fmt.Sprintf("⚡ %d", m.lanes)))
	}
	if m.filter != "" {
		b.WriteString("  " + theme.Subject.Render("/"+m.filter))
	}
	return []string{fit(b.String(), w), theme.Rule.Render(strings.Repeat("─", w))}
}

func (m *Model) body() []string {
	w, h := m.usable(), m.bodyHeight()
	if h < 1 {
		return nil
	}
	m.boxes = m.boxes[:0]
	// The pane renderers fill m.sideHits / m.listHits as they draw, so the box
	// is recorded AFTER the column that owns it has run.
	at := func(which pane, y0, rows, x0, x1 int, hits []int) {
		h := append([]int(nil), hits...)
		m.boxes = append(m.boxes, box{which: which, y0: y0, y1: y0 + rows, x0: x0, x1: x1, hits: h})
	}
	sep := theme.Rule.Render("│")
	rule := func(n int) string { return theme.Rule.Render(strings.Repeat("─", n)) }
	join := func(cols ...[]string) []string {
		out := make([]string, h)
		for i := range out {
			parts := make([]string, len(cols))
			for j, c := range cols {
				parts[j] = c[i]
			}
			out[i] = strings.Join(parts, sep)
		}
		return out
	}
	switch {
	case w >= wideAt:
		noteW := w * 36 / 100
		if noteW < minNoteW {
			noteW = minNoteW
		}
		if noteW > maxNoteW {
			noteW = maxNoteW
		}
		listW := w - sidebarW - noteW - 2
		side := column(m.sidebar(sidebarW, h), sidebarW, h)
		at(paneSidebar, headerH, h, 0, sidebarW, m.sideHits)
		list := column(m.list(listW, h), listW, h)
		at(paneList, headerH, h, sidebarW+1, sidebarW+1+listW, m.listHits)
		note := column(m.note(noteW, h), noteW, h)
		at(paneNote, headerH, h, sidebarW+listW+2, w, nil)
		return join(side, list, note)
	case w >= mediumAt:
		sideW := 18
		rightW := w - sideW - 1
		listH := h * 55 / 100
		noteH := h - listH - 1
		right := append(column(m.list(rightW, listH), rightW, listH), rule(rightW))
		at(paneList, headerH, listH, sideW+1, w, m.listHits)
		right = append(right, column(m.note(rightW, noteH), rightW, noteH)...)
		at(paneNote, headerH+listH+1, noteH, sideW+1, w, nil)
		side := column(m.sidebar(sideW, h), sideW, h)
		at(paneSidebar, headerH, h, 0, sideW, m.sideHits)
		return join(side, right)
	}
	listH := h * 55 / 100
	noteH := h - listH - 1
	out := []string{fit(m.tabs(w), w)}
	out = append(out, column(m.list(w, listH), w, listH)...)
	at(paneList, headerH+1, listH, 0, w, m.listHits)
	out = append(out, rule(w))
	out = append(out, column(m.note(w, noteH), w, noteH)...)
	at(paneNote, headerH+listH+2, noteH, 0, w, nil)
	return out
}

// ── sidebar ──────────────────────────────────────────────────────────────────

func (m *Model) sidebar(w, h int) []string {
	var lines []string
	m.sideHits = m.sideHits[:0]
	hit := func(i int) { m.sideHits = append(m.sideHits, i) }
	for i, s := range m.side {
		var line string
		if s.view >= 0 {
			vw := views[s.view]
			line = " " + theme.Glyph(glyphState(vw.name), vw.glyph) + " " + vw.name
		} else {
			f := s.folder
			name := strings.Repeat("  ", f.Depth) + f.Name
			count := fmt.Sprintf("%d", f.Open)
			room := w - 2 - len(count) - 1
			line = " " + fit(name, room) + " " + theme.Field.Render(count)
		}
		if i == len(views) {
			lines = append(lines, " "+theme.Rule.Render(strings.Repeat("─", w-2)))
			hit(-1)
		}
		if i == m.sideCur {
			style := theme.Selected
			if m.focus != paneSidebar {
				style = theme.Bold
			}
			line = style.Render(fit(line, w))
		}
		lines = append(lines, line)
		hit(i)
	}
	// Keep the cursor visible.
	cur := m.sideCur
	if cur >= len(views) {
		cur++ // the rule line
	}
	if cur < m.sideOff {
		m.sideOff = cur
	}
	if cur >= m.sideOff+h {
		m.sideOff = cur - h + 1
	}
	if m.sideOff < 0 {
		m.sideOff = 0
	}
	if m.sideOff < len(lines) {
		lines = lines[m.sideOff:]
		m.sideHits = m.sideHits[m.sideOff:]
	}
	return lines
}

func glyphState(view string) string {
	switch view {
	case "Today":
		return "now"
	case "Later":
		return "later"
	case "Someday":
		return "someday"
	case "Upcoming":
		return "scheduled"
	case "Due":
		return "dropped"
	case "Done":
		return "done"
	}
	return ""
}

// tabs is the sidebar as one line, for a narrow window.
func (m *Model) tabs(w int) string {
	var parts []string
	start := 0
	for i, s := range m.side {
		label := ""
		if s.view >= 0 {
			label = views[s.view].glyph + " " + views[s.view].name
		} else {
			label = fmt.Sprintf("%s %d", s.folder.Name, s.folder.Open)
		}
		if i == m.sideCur {
			style := theme.Selected
			if m.focus != paneSidebar {
				style = theme.Bold
			}
			label = style.Render(" " + label + " ")
			start = len(parts)
		} else {
			label = " " + theme.Field.Render(label) + " "
		}
		parts = append(parts, label)
	}
	// Scroll the strip so the active tab is on screen.
	for {
		line := strings.Join(parts, "")
		if ansi.StringWidth(line) <= w || start == 0 {
			return line
		}
		parts = parts[1:]
		start--
	}
}

// ── the list ─────────────────────────────────────────────────────────────────

func (m *Model) list(w, h int) []string {
	if m.mode == modePicker {
		return m.pickerLines(w, h)
	}
	if m.loadErr != nil {
		return []string{" " + theme.Err.Render(m.loadErr.Error())}
	}
	if len(m.rows) == 0 {
		msg := "nothing here"
		if m.filter != "" {
			msg = "nothing matches /" + m.filter
		}
		return []string{"", " " + theme.Muted.Render(msg)}
	}
	if m.listCur < m.listOff {
		m.listOff = m.listCur
	}
	if m.listCur >= m.listOff+h {
		m.listOff = m.listCur - h + 1
	}
	if m.listOff < 0 {
		m.listOff = 0
	}
	folder := m.currentFolder()
	var lines []string
	m.listHits = m.listHits[:0]
	for i := m.listOff; i < len(m.rows) && len(lines) < h; i++ {
		r := m.rows[i]
		if r.item == nil {
			lines = append(lines, " "+theme.Subject.Render(r.header))
			m.listHits = append(m.listHits, -1)
			continue
		}
		line := m.rowLine(r.item, w, folder)
		if i == m.listCur {
			style := theme.Selected
			if m.focus != paneList {
				style = theme.Bold
			}
			line = style.Render(fit(line, w))
		}
		lines = append(lines, line)
		m.listHits = append(m.listHits, i)
	}
	return lines
}

// rowLine is ` ● title  #tags        due 9/30`: the due date right-aligned,
// the tags muted, the title cut to what is left.
func (m *Model) rowLine(it *vault.Item, w int, folder string) string {
	glyph := theme.Glyph(vault.State(it), vault.Glyph(vault.State(it)))
	right := ""
	switch {
	case it.Due != "":
		right = "due " + shortDate(it.Due)
		if it.Due < m.v.Today() && it.Open() {
			right = theme.Err.Render(right)
		} else {
			right = theme.Warn.Render(right)
		}
	case it.Bucket == vault.BucketScheduled && it.Open():
		right = theme.Field.Render(shortDate(it.When))
	case !it.Open():
		right = theme.Muted.Render(shortDate(it.Closed()))
	}
	tags := ""
	if len(it.Tags) > 0 {
		tags = theme.Muted.Render("#" + strings.Join(it.Tags, " #"))
	}
	lane := ""
	if it.Lane != "" {
		lane = theme.Accent.Render("⚡")
	}
	title := it.Title
	if folder != "" && it.Folder != folder && strings.HasPrefix(it.Folder, folder+"/") {
		title = theme.Muted.Render(strings.TrimPrefix(it.Folder, folder+"/")+"/") + title
	}
	// Budget: " " glyph " " title … tags " " right " "
	rightW := ansi.StringWidth(right)
	tagW := ansi.StringWidth(tags)
	laneW := ansi.StringWidth(lane)
	fixed := 3 + laneW + boolInt(laneW > 0) + 1
	titleW := w - fixed - rightW - boolInt(rightW > 0) - tagW - boolInt(tagW > 0)
	if titleW < 8 {
		// Drop the tags before the title.
		titleW += tagW + boolInt(tagW > 0)
		tags, tagW = "", 0
	}
	if titleW < 4 {
		titleW = 4
	}
	titleS := fit(title, titleW)
	var b strings.Builder
	b.WriteString(" " + glyph + " " + titleS)
	if tagW > 0 {
		b.WriteString(" " + tags)
	}
	if laneW > 0 {
		b.WriteString(" " + lane)
	}
	if rightW > 0 {
		b.WriteString(" " + right)
	}
	b.WriteString(" ")
	return b.String()
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// shortDate is 9/30 for this year, 2027-01-05 otherwise.
func shortDate(d string) string {
	if len(d) != 10 {
		return d
	}
	if d[:4] != fmt.Sprint(currentYear()) {
		return d
	}
	mo, day := strings.TrimLeft(d[5:7], "0"), strings.TrimLeft(d[8:10], "0")
	return mo + "/" + day
}

var currentYear = func() int { return yearNow() }

func (m *Model) pickerLines(w, h int) []string {
	lines := []string{" " + theme.Accent.Render("move to ›") + " " + m.input.View(), ""}
	for i, p := range m.picker {
		if len(lines) >= h {
			break
		}
		line := "   " + p
		if i == m.pickerCur {
			line = theme.Selected.Render(fit(" ▸ "+p, w))
		}
		lines = append(lines, line)
	}
	if len(m.picker) == 0 {
		lines = append(lines, "   "+theme.Muted.Render("no project matches"))
	}
	return lines
}

// ── the note ─────────────────────────────────────────────────────────────────

func (m *Model) note(w, h int) []string {
	it := m.current()
	if it == nil {
		return nil
	}
	inner := w - 2
	var lines []string
	for _, l := range strings.Split(ansi.Wordwrap(it.Title, inner, ""), "\n") {
		lines = append(lines, " "+theme.Bold.Render(l))
	}
	var meta []string
	switch {
	case !it.Open():
		meta = append(meta, theme.Glyph(vault.State(it), vault.Glyph(vault.State(it)))+" "+vault.State(it)+" "+it.Closed())
	case it.Bucket == vault.BucketScheduled:
		meta = append(meta, theme.Glyph(it.Bucket, vault.Glyph(it.Bucket))+" "+it.When)
	default:
		meta = append(meta, theme.Glyph(it.Bucket, vault.Glyph(it.Bucket))+" "+it.Bucket)
	}
	if it.Due != "" {
		meta = append(meta, theme.Warn.Render("due "+it.Due))
	}
	if it.Repeat != "" {
		meta = append(meta, theme.Muted.Render("↻ "+it.Repeat))
	}
	if len(it.Tags) > 0 {
		meta = append(meta, theme.Muted.Render("#"+strings.Join(it.Tags, " #")))
	}
	if it.Lane != "" {
		meta = append(meta, theme.Accent.Render("⚡ "+it.Lane))
	}
	where := it.Folder
	if where == "" {
		where = "unfiled"
	}
	meta = append(meta, theme.Path.Render(where))
	lines = append(lines, " "+strings.Join(meta, theme.Rule.Render(" · ")))
	lines = append(lines, " "+theme.Rule.Render(strings.Repeat("─", inner)))
	body := renderBody(it.Body(), inner, m.checkCur, m.focus == paneNote)
	lines = append(lines, body...)
	if m.noteOff > 0 && m.checklistCount() == 0 {
		max := len(lines) - h
		if max < 0 {
			max = 0
		}
		if m.noteOff > max {
			m.noteOff = max
		}
		lines = lines[m.noteOff:]
	} else if m.checkCur >= 0 {
		// Scroll so the checklist cursor is visible.
		for i, l := range lines {
			if strings.Contains(l, "\x00cur\x00") {
				lines[i] = strings.ReplaceAll(l, "\x00cur\x00", "")
				if i >= h {
					lines = lines[i-h+1:]
				}
				break
			}
		}
	}
	return lines
}

// renderBody is the light markdown the notes use: headings, bullets, the
// checklist as ☐ / ☑ (with a cursor), embeds and links marked, code muted.
func renderBody(body string, w int, checkCur int, focused bool) []string {
	var out []string
	inCode := false
	k := 0
	for _, src := range strings.Split(strings.TrimRight(body, "\n"), "\n") {
		if strings.HasPrefix(strings.TrimSpace(src), "```") {
			inCode = !inCode
			out = append(out, " "+theme.Muted.Render(fit(src, w)))
			continue
		}
		if inCode {
			out = append(out, " "+theme.Muted.Render(fit(src, w)))
			continue
		}
		line := src
		style := lipgloss.NewStyle()
		marker := ""
		if box, ok := checkbox(src); ok {
			indent := src[:len(src)-len(strings.TrimLeft(src, " \t"))]
			text := strings.TrimLeft(src, " \t")[5:]
			text = strings.TrimLeft(text, " ")
			glyph := "☐"
			if box != " " {
				glyph = theme.OK.Render("☑")
				style = theme.Muted
			}
			line = indent + glyph + " " + text
			if k == checkCur {
				style = theme.Selected
				if !focused {
					style = theme.Bold
				}
				marker = "\x00cur\x00"
			}
			k++
		} else if strings.HasPrefix(line, "#") {
			style = theme.Accent.Bold(true)
			line = strings.TrimLeft(line, "# ")
		} else if strings.HasPrefix(strings.TrimSpace(line), "> ") {
			style = theme.Muted
		}
		line = markLinks(line)
		wrapped := ansi.Wordwrap(line, w, "")
		if wrapped == "" {
			out = append(out, "")
			continue
		}
		for i, l := range strings.Split(wrapped, "\n") {
			if i == 0 {
				out = append(out, " "+style.Render(fit(l, w))+marker)
			} else {
				out = append(out, " "+style.Render(fit(l, w)))
			}
		}
	}
	return out
}

// markLinks paints `![[embed]]` and `[[link]]` in the path colour.
func markLinks(line string) string {
	for {
		i := strings.Index(line, "[[")
		j := strings.Index(line, "]]")
		if i < 0 || j < i {
			return line
		}
		open := i
		if open > 0 && line[open-1] == '!' {
			open--
		}
		line = line[:open] + theme.Path.Render(line[open:j+2]) + "\x01" + line[j+2:]
		// \x01 keeps the scan moving past what was painted.
		if k := strings.Index(line, "\x01"); k >= 0 {
			rest := line[k+1:]
			head := line[:k]
			if !strings.Contains(rest, "[[") {
				return head + rest
			}
			return head + markLinks(rest)
		}
	}
}

// ── footer: keys, then the status or the input line ──────────────────────────

func (m *Model) footer() []string {
	w := m.usable()
	if m.mode == modeHelp {
		return []string{theme.Rule.Render(strings.Repeat("─", w)), "", fit(" "+theme.Muted.Render("any key closes this"), w)}
	}
	keys := "⇥ view  1-7 jump  ←→ pane  jk move  ⏎ open  a add  x done  n/l/s now/later/someday  w when  d due  m project  t tags  r rename  S spawn  e edit  o obsidian  u undo  / filter  A archive  ? help  q quit"
	if m.focus == paneNote {
		keys = "jk checklist  space tick  e edit  o obsidian  ←→ pane  esc back  ⇥ view  ? help  q quit"
	}
	if m.focus == paneSidebar {
		keys = "jk pick  ⏎ show it  ⇥ view  1-7 jump  →  back to the list  / filter  ? help  q quit"
	}
	var last string
	switch m.mode {
	case modeAdd:
		chip := theme.Chip.Render(m.addWhen)
		hint := theme.Muted.Render("⇥ now/later/someday · ⌃d due · ⏎ add · esc")
		due := ""
		if m.addDue != "" {
			due = " " + theme.Warn.Render("due "+shortDate(m.addDue))
		}
		where := m.currentFolder()
		if where == "" {
			where = "unfiled"
		}
		last = " " + theme.Accent.Render("add ›") + " " + chip + due + " " + theme.Path.Render(where) + " " + m.input.View() + "  " + hint
	case modePrompt:
		label := map[promptKind]string{promptWhen: "when › now | later | someday | date", promptDue: "due › date | none", promptTags: "tags › a, b", promptRename: "rename ›", promptAddDue: "due › date | none"}[m.prompt]
		last = " " + theme.Accent.Render(label) + " " + m.input.View()
	case modeFilter:
		last = " " + theme.Accent.Render("filter ›") + " " + m.input.View()
	case modePicker:
		last = " " + theme.Muted.Render("↑↓ pick · ⏎ move · esc")
	case modeConfirm:
		last = " " + theme.Warn.Render("archive closed notes older than 30 days into log/? y/n")
	default:
		st := m.status
		if m.statusErr {
			st = theme.Err.Render(st)
		} else {
			st = theme.Field.Render(st)
		}
		last = " " + st
	}
	return []string{theme.Rule.Render(strings.Repeat("─", w)), fit(" "+theme.Muted.Render(keys), w), fit(last, w)}
}

func (m *Model) help() []string {
	return []string{
		"",
		"  " + theme.Accent.Bold(true).Render("get around"),
		"",
		"  ⇥ ⇧⇥  [ ]   the view tabs along the top: Today · Later · Someday · Upcoming · Due · Inbox · Done",
		"  1 … 7       jump straight to one of them",
		"  ← →         the three panes: the sidebar, the list, the note",
		"  ⏎           into the next pane right      esc   back to the list (or clear the filter)",
		"  j k ↑ ↓     move            g G   top / bottom      ⌃d ⌃u   page",
		"  click       a tab, a sidebar row, a list row       wheel   scrolls the pane under the pointer",
		"  " + theme.Muted.Render("  (the sidebar's lower half is your projects — ← to it, j k, ⏎)"),
		"",
		"  " + theme.Accent.Bold(true).Render("do something to the selected to-do"),
		"",
		"  a           add — ⇥ cycles now/later/someday, ⌃d sets due, ⏎ adds into the selected project",
		"  x space     done            X     drop              R       reopen",
		"  n l s       now / later / someday",
		"  w           when (a date)   d     due               t       tags        r   rename",
		"  m           move it to another project (fuzzy picker)",
		"  S           spawn an agent lane for it",
		"  e           $EDITOR         o     open in Obsidian",
		"  u           undo the last write",
		"",
		"  " + theme.Accent.Bold(true).Render("the rest"),
		"",
		"  /           filter the list      A   archive closed notes older than 30 days into log/",
		"  space       in the note pane: tick the checklist line under the cursor",
		"  ?           this                q   quit",
	}
}
