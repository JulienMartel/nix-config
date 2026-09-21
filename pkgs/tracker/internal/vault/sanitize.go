package vault

import (
	"regexp"
	"strings"
)

// ── names, tags and YAML scalars: the rules the old script kept ───────────────

var (
	badNameRunes = regexp.MustCompile(`[\\/:*?"<>|^#\[\]]+`)
	spaceRun     = regexp.MustCompile(`[\s]+`)
	badTagRunes  = regexp.MustCompile(`[^A-Za-z0-9_/-]+`)
	yamlBare     = regexp.MustCompile(`^[A-Za-z][A-Za-z0-9_ ./()+-]*$`)
	yamlDate     = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
	yamlWords    = map[string]bool{"true": true, "false": true, "yes": true, "no": true, "null": true, "on": true, "off": true}
)

// MaxName is the longest file name tracker will make. Well under the file
// system's 255 bytes, so a `(2)` suffix and `.md` always fit.
const MaxName = 120

// Sanitize makes an Obsidian-safe file or folder name: none of the characters
// Obsidian refuses in a link, one space between words, nothing leading or
// trailing, no leading dot, and no longer than MaxName. A title this changed
// is kept as `title:` so nothing is lost.
func Sanitize(title string) string {
	s := strings.ReplaceAll(strings.ReplaceAll(title, "\r", ""), "\n", "")
	s = badNameRunes.ReplaceAllString(s, " ")
	s = spaceRun.ReplaceAllString(s, " ")
	s = strings.TrimSpace(s)
	s = strings.TrimLeft(s, ".")
	if len(s) > MaxName {
		// Cut on a rune boundary, then on a word boundary when one is near.
		r := []rune(s)
		for len(string(r)) > MaxName {
			r = r[:len(r)-1]
		}
		s = string(r)
		if i := strings.LastIndex(s, " "); i > MaxName-20 {
			s = s[:i]
		}
		s = strings.TrimSpace(s)
	}
	return s
}

// SanitizeTag makes an Obsidian tag: `#` off, and every run of anything but
// letters, digits, `_`, `-` and `/` becomes `-` (`hausfold.co` → `hausfold-co`).
func SanitizeTag(tag string) string {
	s := strings.TrimPrefix(strings.TrimSpace(tag), "#")
	return badTagRunes.ReplaceAllString(s, "-")
}

// Tags parses `a,b, c` into clean, de-duplicated tags, order kept.
func Tags(spec string) []string {
	var out []string
	seen := map[string]bool{}
	for _, p := range strings.Split(spec, ",") {
		t := SanitizeTag(p)
		if t == "" || t == "-" || seen[t] {
			continue
		}
		seen[t] = true
		out = append(out, t)
	}
	return out
}

// YAMLStr quotes a scalar only when a bare one would be misread: bare when it
// starts with a letter and is made of the characters a title usually is, or
// is a date; double-quoted with `\` and `"` escaped otherwise. The YAML words
// (`yes`, `null`, …) are quoted so they stay strings.
func YAMLStr(s string) string {
	if yamlDate.MatchString(s) {
		return s
	}
	if yamlBare.MatchString(s) && !yamlWords[strings.ToLower(s)] && s == strings.TrimSpace(s) {
		return s
	}
	return `"` + strings.NewReplacer(`\`, `\\`, `"`, `\"`).Replace(s) + `"`
}
