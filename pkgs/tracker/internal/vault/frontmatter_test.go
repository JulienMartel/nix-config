package vault

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseSerializeRoundTripsShapes(t *testing.T) {
	cases := []string{
		"",
		"just a body\n",
		"---\nwhen: now\n---\n",
		"---\nwhen: now\n---",
		"---\nwhen: now\n---\nbody\n",
		"---\ntitle: \"Miles and mom: Tell her\"\ntags:\n  - a\n  - b\n---\n",
		"---\ntags: [a, b]\nx: 'it''s'\n\n# comment\nnested:\n  key: v\n---\nbody",
		"---\nunclosed: yes\nbody without end",
		"---\ntitle: record perch video \n---\n",
	}
	for _, c := range cases {
		fm, body := Parse([]byte(c))
		if got := string(fm.Serialize(body)); got != c {
			t.Errorf("round trip changed %q → %q", c, got)
		}
	}
}

func TestParseReadsValues(t *testing.T) {
	fm, body := Parse([]byte("---\ntitle: \"a \\\"quoted\\\" \\\\ title\"\ntags:\n  - fable\n  - 'haus'\ninline: [x, \"y, z\"]\nwhen: 2026-09-20\nempty:\ntrail: record perch video \n---\nthe body\n"))
	if body != "the body\n" {
		t.Errorf("body %q", body)
	}
	if got := fm.Get("title"); got != `a "quoted" \ title` {
		t.Errorf("title %q", got)
	}
	if got := strings.Join(fm.List("tags"), ","); got != "fable,haus" {
		t.Errorf("tags %q", got)
	}
	if got := strings.Join(fm.List("inline"), "|"); got != "x|y, z" {
		t.Errorf("inline %q", got)
	}
	if got := fm.Get("trail"); got != "record perch video" {
		t.Errorf("trailing space kept: %q", got)
	}
	if !fm.Has("empty") || fm.Get("empty") != "" {
		t.Error("empty key")
	}
}

func TestSetKeepsUntouchedLinesAndOrders(t *testing.T) {
	src := "---\ntype: todo\nstatus: open\ntitle: 'odd'\ncreated: 2026-01-01\nthings: X\n---\nbody\n"
	fm, body := Parse([]byte(src))
	fm.Delete("type")
	fm.Rename("status", "when")
	fm.Set("when", "later")
	fm.Set("due", "2026-12-01")
	fm.SetList("tags", []string{"a", "b"})
	fm.Set("done", "2026-09-20")
	want := "---\nwhen: later\ndue: 2026-12-01\ndone: 2026-09-20\ntags:\n  - a\n  - b\ntitle: 'odd'\ncreated: 2026-01-01\nthings: X\n---\nbody\n"
	if got := string(fm.Serialize(body)); got != want {
		t.Errorf("got\n%s\nwant\n%s", got, want)
	}
	fm.Set("done", "")
	fm.SetList("tags", nil)
	if fm.Has("done") || fm.Has("tags") {
		t.Error("empty value should remove the key")
	}
}

func TestEmptyFrontmatterGetsABlock(t *testing.T) {
	fm, body := Parse([]byte("hand-written body\n"))
	fm.Set("when", "later")
	if got := string(fm.Serialize(body)); got != "---\nwhen: later\n---\nhand-written body\n" {
		t.Errorf("got %q", got)
	}
}

func TestYAMLStr(t *testing.T) {
	cases := map[string]string{
		"buy cat food":   "buy cat food",
		"2026-09-20":     "2026-09-20",
		"yes":            `"yes"`,
		"True":           `"True"`,
		"a: b":           `"a: b"`,
		`say "hi" \ now`: `"say \"hi\" \\ now"`,
		"~/code/x":       `"~/code/x"`,
		"#tag":           `"#tag"`,
		"trail ":         `"trail "`,
		"hausfold/ci":    "hausfold/ci",
		"two\nlines":     `"two\nlines"`,
		"a\tb\r":         `"a\tb\r"`,
	}
	for in, want := range cases {
		if got := YAMLStr(in); got != want {
			t.Errorf("YAMLStr(%q) = %q, want %q", in, got, want)
		}
	}
}

// A value with a line break in it used to end the line and take the rest of
// the frontmatter with it: `tracker add $'two\nlines'` wrote a note nothing
// could parse. Whatever goes in has to come back out, and the block has to
// still be a block.
func TestFrontmatterSurvivesLineBreaks(t *testing.T) {
	for _, v := range []string{"two\nlines", "a\tb", "carriage\rreturn", "---\nwhen: now", `quote " and \ back`} {
		fm := Empty()
		fm.Set("title", v)
		fm.Set("when", Now)
		data := fm.Serialize("the body\n")
		back, body := Parse(data)
		switch {
		case body != "the body\n":
			t.Errorf("%q: body = %q", v, body)
		case back.Get("title") != v:
			t.Errorf("%q: title came back %q\n%s", v, back.Get("title"), data)
		case back.Get("when") != Now:
			t.Errorf("%q: when came back %q — the block was cut short\n%s", v, back.Get("when"), data)
		}
	}
}

func TestSanitize(t *testing.T) {
	cases := map[string]string{
		"a: b/c*d?e\"f<g>h|i#j^k[l]m":       "a b c d e f g h i j k l m",
		"  many   spaces  ":                 "many spaces",
		"...dotted":                         "dotted",
		"line\nbreak":                       "linebreak",
		strings.Repeat("word ", 40) + "end": strings.TrimSpace(strings.Repeat("word ", 24)),
	}
	for in, want := range cases {
		if got := Sanitize(in); got != want {
			t.Errorf("Sanitize(%q) = %q, want %q", in, got, want)
		}
	}
	if got := SanitizeTag("#hausfold.co"); got != "hausfold-co" {
		t.Errorf("tag %q", got)
	}
	if got := strings.Join(Tags("a, #b,, a, c d"), "|"); got != "a|b|c-d" {
		t.Errorf("tags %q", got)
	}
}

// TestRoundTripVaultCopy walks a real vault and proves every note comes back
// byte for byte. TRACKER_TEST_VAULT names it — a copy is fine, and so is the
// vault itself, since this only parses; the test skips without one.
func TestRoundTripVaultCopy(t *testing.T) {
	root := os.Getenv("TRACKER_TEST_VAULT")
	if root == "" {
		t.Skip("TRACKER_TEST_VAULT unset")
	}
	dir := filepath.Join(root, "tracker")
	if st, err := os.Stat(dir); err != nil || !st.IsDir() {
		t.Skip("no vault copy at " + dir)
	}
	n := 0
	err := filepath.WalkDir(dir, func(p string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(p, ".md") {
			return nil
		}
		data, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		fm, body := Parse(data)
		if got := fm.Serialize(body); string(got) != string(data) {
			t.Errorf("%s: round trip changed the bytes", p)
		}
		n++
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if n < 10 {
		t.Errorf("only %d notes round-tripped", n)
	}
	t.Logf("%d notes round-tripped byte for byte", n)
}

func TestRoundTripFixture(t *testing.T) {
	v := fixture(t)
	v.NoNormalize = true
	idx, err := v.Load()
	if err != nil {
		t.Fatal(err)
	}
	for _, it := range idx.Items {
		if it.Note.Changed() {
			t.Errorf("%s: parse/serialize is not the identity", it.ID)
		}
	}
}
