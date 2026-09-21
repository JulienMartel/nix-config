package vault

import (
	"bytes"
	"regexp"
	"strings"
)

// ── frontmatter: the YAML block at the top of a note, without a YAML library ──
//
// Every note's frontmatter is flat `key: value` lines and `key:` + `  - item`
// lists — the whole shape the old awk indexer handled, and the whole shape
// Obsidian's property editor writes. A YAML library would round-trip that
// shape by re-emitting it in ITS style, which is the one thing this must never
// do: a note that tracker did not touch has to come back byte for byte, and a
// note it did touch has to keep every key it did not name, in the form
// Obsidian left it. So each key is kept as the lines it was read from, and
// only a key that is set or removed gets fresh lines.

// keyLine matches the start of a top-level key. Column 0 only: an indented
// `key:` is a list item's text or a nested map, neither of which is ours.
var keyLine = regexp.MustCompile(`^([A-Za-z_][A-Za-z0-9_-]*):(.*)$`)

// listItem matches `  - item` under a key with no inline value.
var listItem = regexp.MustCompile(`^[ \t]*-[ \t]+(.*)$`)

// entry is one key and the lines it was read from. key == "" is a line that
// belongs to no key (a comment, a blank, a nested map) and is carried
// verbatim so nothing a person put there is lost.
type entry struct {
	key    string
	raw    []string
	value  string
	list   []string
	isList bool
}

// Frontmatter is the ordered key set of one note.
type Frontmatter struct {
	entries []entry
	// present is whether the note had a `---` block at all; closeNL whether
	// the closing `---` was followed by a newline (a file can end right on it).
	present bool
	closeNL bool
}

// Parse splits a note into its frontmatter and body. A note with no block, or
// an unclosed one, is all body; the block is then made on the first Set.
func Parse(data []byte) (*Frontmatter, string) {
	fm := &Frontmatter{closeNL: true}
	if !bytes.HasPrefix(data, []byte("---\n")) {
		return fm, string(data)
	}
	rest := data[4:]
	var lines []string
	for {
		nl := bytes.IndexByte(rest, '\n')
		var line string
		if nl < 0 {
			line = string(rest)
		} else {
			line = string(rest[:nl])
		}
		if line == "---" {
			fm.present = true
			if nl < 0 {
				fm.closeNL = false
				rest = nil
			} else {
				rest = rest[nl+1:]
			}
			break
		}
		if nl < 0 {
			// Unclosed: not frontmatter at all.
			return &Frontmatter{closeNL: true}, string(data)
		}
		lines = append(lines, line)
		rest = rest[nl+1:]
	}
	fm.entries = parseLines(lines)
	return fm, string(rest)
}

func parseLines(lines []string) []entry {
	var out []entry
	for i := 0; i < len(lines); i++ {
		line := lines[i]
		m := keyLine.FindStringSubmatch(line)
		if m == nil {
			out = append(out, entry{raw: []string{line}})
			continue
		}
		e := entry{key: m[1], raw: []string{line}}
		val := strings.TrimSpace(m[2])
		switch {
		case val == "":
			// A block list, if the next lines are items; else an empty scalar.
			for i+1 < len(lines) {
				im := listItem.FindStringSubmatch(lines[i+1])
				if im == nil {
					break
				}
				e.isList = true
				e.list = append(e.list, unquote(strings.TrimSpace(im[1])))
				e.raw = append(e.raw, lines[i+1])
				i++
			}
		case strings.HasPrefix(val, "[") && strings.HasSuffix(val, "]"):
			e.isList = true
			for _, item := range splitInline(val[1 : len(val)-1]) {
				if item = strings.TrimSpace(item); item != "" {
					e.list = append(e.list, unquote(item))
				}
			}
		default:
			e.value = unquote(val)
		}
		out = append(out, e)
	}
	return out
}

// splitInline splits `a, "b, c"` on the commas outside quotes.
func splitInline(s string) []string {
	var parts []string
	var cur strings.Builder
	quote := byte(0)
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case quote != 0:
			cur.WriteByte(c)
			if c == quote {
				quote = 0
			}
		case c == '"' || c == '\'':
			quote = c
			cur.WriteByte(c)
		case c == ',':
			parts = append(parts, cur.String())
			cur.Reset()
		default:
			cur.WriteByte(c)
		}
	}
	return append(parts, cur.String())
}

// unquote decodes a scalar the way the old indexer did, plus the two escapes a
// double-quoted title needs. A bare scalar is itself.
func unquote(s string) string {
	if len(s) >= 2 && s[0] == '"' && s[len(s)-1] == '"' {
		inner := s[1 : len(s)-1]
		var b strings.Builder
		for i := 0; i < len(inner); i++ {
			if inner[i] == '\\' && i+1 < len(inner) {
				i++
				switch inner[i] {
				case 'n':
					b.WriteByte('\n')
				case 'r':
					b.WriteByte('\r')
				case 't':
					b.WriteByte('\t')
				default:
					b.WriteByte(inner[i])
				}
				continue
			}
			b.WriteByte(inner[i])
		}
		return b.String()
	}
	if len(s) >= 2 && s[0] == '\'' && s[len(s)-1] == '\'' {
		return strings.ReplaceAll(s[1:len(s)-1], "''", "'")
	}
	return s
}

// Serialize writes the note back: the block (only when it has keys, or had
// one) then the body. An untouched note comes back byte-identical.
func (fm *Frontmatter) Serialize(body string) []byte {
	var b bytes.Buffer
	if fm.present || len(fm.entries) > 0 {
		b.WriteString("---\n")
		for _, e := range fm.entries {
			for _, line := range e.raw {
				b.WriteString(line)
				b.WriteByte('\n')
			}
		}
		b.WriteString("---")
		if fm.closeNL || body != "" {
			b.WriteByte('\n')
		}
	}
	b.WriteString(body)
	return b.Bytes()
}

func (fm *Frontmatter) find(key string) int {
	for i, e := range fm.entries {
		if e.key == key {
			return i
		}
	}
	return -1
}

// Has reports whether the key is there at all, even empty.
func (fm *Frontmatter) Has(key string) bool { return fm.find(key) >= 0 }

// Get is the scalar under key, trimmed; a list comes back comma-joined, the
// way the old TSV index carried tags.
func (fm *Frontmatter) Get(key string) string {
	i := fm.find(key)
	if i < 0 {
		return ""
	}
	if fm.entries[i].isList {
		return strings.Join(fm.entries[i].list, ",")
	}
	return strings.TrimSpace(fm.entries[i].value)
}

// List is the items under key; a scalar with commas is split, so a hand-typed
// `tags: a, b` reads the same as the block Obsidian writes.
func (fm *Frontmatter) List(key string) []string {
	i := fm.find(key)
	if i < 0 {
		return nil
	}
	e := fm.entries[i]
	if e.isList {
		return append([]string(nil), e.list...)
	}
	var out []string
	for _, p := range strings.Split(e.value, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

// Keys is every key, in file order.
func (fm *Frontmatter) Keys() []string {
	var out []string
	for _, e := range fm.entries {
		if e.key != "" {
			out = append(out, e.key)
		}
	}
	return out
}

// canonical is the order a freshly written note lists its keys in. A new key
// slots in before the first existing key that comes after it here; a key not
// on the list goes to the end. Untouched keys never move.
var canonical = []string{"type", "when", "repeat", "due", "done", "dropped", "tags", "created", "title", "repo", "lane", "project"}

func rank(key string) int {
	for i, k := range canonical {
		if k == key {
			return i
		}
	}
	return len(canonical)
}

func (fm *Frontmatter) insert(e entry) {
	fm.present = true
	r := rank(e.key)
	if r < len(canonical) {
		for i, x := range fm.entries {
			if x.key != "" && rank(x.key) > r {
				fm.entries = append(fm.entries[:i], append([]entry{e}, fm.entries[i:]...)...)
				return
			}
		}
	}
	fm.entries = append(fm.entries, e)
}

// Set writes a scalar; an empty value removes the key. Position is kept for a
// key already there.
func (fm *Frontmatter) Set(key, value string) {
	if value == "" {
		fm.Delete(key)
		return
	}
	e := entry{key: key, value: value, raw: []string{key + ": " + YAMLStr(value)}}
	if i := fm.find(key); i >= 0 {
		fm.entries[i] = e
		return
	}
	fm.insert(e)
}

// SetList writes a block list — `tags:` and `  - item` lines, never the inline
// form — and removes the key when the list is empty.
func (fm *Frontmatter) SetList(key string, items []string) {
	if len(items) == 0 {
		fm.Delete(key)
		return
	}
	e := entry{key: key, isList: true, list: append([]string(nil), items...), raw: []string{key + ":"}}
	for _, it := range items {
		e.raw = append(e.raw, "  - "+YAMLStr(it))
	}
	if i := fm.find(key); i >= 0 {
		fm.entries[i] = e
		return
	}
	fm.insert(e)
}

// Delete removes a key and every line that was read as part of it.
func (fm *Frontmatter) Delete(key string) {
	if i := fm.find(key); i >= 0 {
		fm.entries = append(fm.entries[:i], fm.entries[i+1:]...)
	}
}

// Rename moves a key's value under a new name, in place, so `deadline` becomes
// `due` on the line it was on. The value is re-emitted in tracker's form.
func (fm *Frontmatter) Rename(old, new string) {
	i := fm.find(old)
	if i < 0 {
		return
	}
	e := fm.entries[i]
	if j := fm.find(new); j >= 0 {
		// The new key already exists: the old one just goes.
		fm.Delete(old)
		return
	}
	if e.isList {
		ne := entry{key: new, isList: true, list: e.list, raw: []string{new + ":"}}
		for _, it := range e.list {
			ne.raw = append(ne.raw, "  - "+YAMLStr(it))
		}
		fm.entries[i] = ne
		return
	}
	v := strings.TrimSpace(e.value)
	fm.entries[i] = entry{key: new, value: v, raw: []string{new + ": " + YAMLStr(v)}}
}

// Clone is a deep copy: the note a repeating to-do comes back as starts from
// the one it closed, so every key a person added is carried with it.
func (fm *Frontmatter) Clone() *Frontmatter {
	out := &Frontmatter{present: fm.present, closeNL: fm.closeNL, entries: make([]entry, len(fm.entries))}
	for i, e := range fm.entries {
		e.raw = append([]string(nil), e.raw...)
		e.list = append([]string(nil), e.list...)
		out.entries[i] = e
	}
	return out
}

// Empty is a frontmatter with no keys and no block — for a new note.
func Empty() *Frontmatter { return &Frontmatter{closeNL: true} }
