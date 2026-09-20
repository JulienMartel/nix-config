// Package theme is the TUI's palette: nebelung's tokens, latte for a light
// terminal and mocha for a dark one, picked by lipgloss from the terminal's
// own background. Roles are the family's (snug): accent, ok, warn, err,
// muted, subject, path, field — and ordinary text is never painted.
//
// Source: ~/code/workshop/nebelung/palette/nebelung.hex.json and
// nebelung-latte.hex.json, read 2026-09-20 from the workshop checkout the
// haus flake pinned that day. A palette change there is a hex change here.
package theme

import "github.com/charmbracelet/lipgloss"

// tone is one token in both themes.
func tone(light, dark string) lipgloss.AdaptiveColor {
	return lipgloss.AdaptiveColor{Light: "#" + light, Dark: "#" + dark}
}

// The tokens, light = latte, dark = mocha.
var (
	Text     = tone("515151", "d7d7d7")
	Subtext1 = tone("616161", "c3c3c3")
	Subtext0 = tone("717171", "aeaeae")
	Overlay1 = tone("909090", "858585")
	Surface1 = tone("c0c0c0", "494949")
	Surface0 = tone("d0d0d0", "343434")
	Base     = tone("f1f1f1", "202020")
	Mauve    = tone("8545e3", "c9a8f1")
	Red      = tone("ca2a40", "ed8fa9")
	Peach    = tone("f66d2d", "f5b58e")
	Yellow   = tone("d99137", "f7e2b5")
	Green    = tone("4a9e3a", "abe1a6")
	Teal     = tone("2f9197", "9be0d5")
	Sapphire = tone("379eb1", "7dc6e7")
	Lavender = tone("7589f3", "b5bff8")
)

// The roles.
var (
	Accent  = lipgloss.NewStyle().Foreground(Mauve)
	OK      = lipgloss.NewStyle().Foreground(Green)
	Warn    = lipgloss.NewStyle().Foreground(Peach)
	Err     = lipgloss.NewStyle().Foreground(Red)
	Muted   = lipgloss.NewStyle().Foreground(Overlay1)
	Subject = lipgloss.NewStyle().Foreground(Sapphire)
	Path    = lipgloss.NewStyle().Foreground(Teal)
	Field   = lipgloss.NewStyle().Foreground(Subtext0)
	Bold    = lipgloss.NewStyle().Bold(true)

	// Selected is the cursor row: the accent on a surface, so it reads in
	// both themes without inverting the text.
	Selected = lipgloss.NewStyle().Background(Surface0).Bold(true)
	// Rule is the box-drawing furniture.
	Rule = lipgloss.NewStyle().Foreground(Surface1)
	// Chip is a small labelled state, like `[later]` in the add box.
	Chip = lipgloss.NewStyle().Foreground(Base).Background(Mauve).Padding(0, 1)
)

// Glyph paints a bucket's glyph in its colour: now is the accent, scheduled
// the warn, later the field, someday muted, done ok, dropped err.
func Glyph(state, glyph string) string {
	switch state {
	case "now":
		return Accent.Render(glyph)
	case "scheduled":
		return Warn.Render(glyph)
	case "later":
		return Field.Render(glyph)
	case "done":
		return OK.Render(glyph)
	case "dropped":
		return Err.Render(glyph)
	}
	return Muted.Render(glyph)
}
