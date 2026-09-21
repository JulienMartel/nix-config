package vault

import (
	"os"
	"strings"
	"testing"
	"time"
)

func day(s string) time.Time {
	d, _ := time.Parse(dateLayout, s)
	return d
}

func TestParseRepeat(t *testing.T) {
	ok := map[string]string{
		"daily": "daily", "weekly": "weekly", "monthly": "monthly", "yearly": "yearly",
		"every 1 day": "daily", "every 1 week": "weekly", "every 12 months": "every 12 months",
		"every 3 days": "every 3 days", "EVERY  2   WEEKS": "every 2 weeks",
		"every 2 year": "every 2 years", "": "", "none": "", "never": "",
	}
	for in, want := range ok {
		got, err := ParseRepeat(in)
		if err != nil || got != want {
			t.Errorf("ParseRepeat(%q) = %q, %v — want %q", in, got, err, want)
		}
	}
	for _, in := range []string{"fortnightly", "every other tuesday", "every 0 days", "every -1 days", "weekly-ish", "every day"} {
		if got, err := ParseRepeat(in); err == nil {
			t.Errorf("ParseRepeat(%q) = %q, want a usage error", in, got)
		} else if ExitCode(err) != 2 {
			t.Errorf("ParseRepeat(%q) should be a usage error", in)
		}
	}
}

func TestNextWhen(t *testing.T) {
	today := day("2026-09-20")
	cases := []struct {
		when, spec, next string
		shift            int
	}{
		// The count is the note's own `when`, not today.
		{"2026-09-18", "weekly", "2026-09-25", 7},
		{"2026-09-19", "every 3 days", "2026-09-22", 3},
		{"2026-10-01", "weekly", "2026-10-08", 7}, // done early: still one week on
		// Done late: the grid is kept, the backlog is not.
		{"2026-09-06", "weekly", "2026-09-27", 21},
		{"2026-08-01", "daily", "2026-09-21", 51},
		// A word has no grid, so it counts from today.
		{"now", "daily", "2026-09-21", 1},
		{"later", "monthly", "2026-10-20", 30},
		{"", "weekly", "2026-09-27", 7},
		// The day of the month is kept, clamped to the month it lands in.
		{"2026-10-31", "monthly", "2026-11-30", 30},
		{"2026-12-31", "monthly", "2027-01-31", 31},
		{"2027-01-31", "monthly", "2027-02-28", 28},
		{"2028-02-29", "yearly", "2029-02-28", 365},
		{"2026-09-30", "yearly", "2027-09-30", 365},
		// A decade-stale daily is past the cap: today is the only honest anchor.
		{"1990-01-01", "daily", "2026-09-21", 1},
	}
	for _, c := range cases {
		next, shift, err := NextWhen(c.when, c.spec, today)
		if err != nil || next != c.next || shift != c.shift {
			t.Errorf("NextWhen(%q, %q) = %q +%d, %v — want %q +%d", c.when, c.spec, next, shift, err, c.next, c.shift)
		}
	}
	if _, _, err := NextWhen("2026-09-20", "every other tuesday", today); err == nil {
		t.Error("an unparseable repeat should be a usage error")
	}
}

// repeating adds a weekly to-do dated before today, with a due date, a
// checklist half ticked, and a key nobody here knows about.
func repeating(t *testing.T) (*Vault, *Item) {
	t.Helper()
	v, _ := migrated(t)
	r, err := v.Add(NewTodo{
		Title: "water the plants", Folder: "Personal", When: "2026-09-18", Repeat: "weekly",
		Due: "2026-09-19", Tags: []string{"home"}, Checklist: []string{"kitchen", "hall"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if got := mustRead(t, r.Path); !strings.Contains(got, "when: 2026-09-18\nrepeat: weekly\ndue: 2026-09-19\n") {
		t.Fatalf("add --repeat:\n%s", got)
	}
	idx, err := v.Load()
	if err != nil {
		t.Fatal(err)
	}
	// A date that has arrived is folded into `now` on disk — but not here: the
	// date is the grid the next occurrence counts from.
	if got := mustRead(t, r.Path); !strings.Contains(got, "when: 2026-09-18\n") {
		t.Errorf("a repeating to-do lost its date to normalization:\n%s", got)
	}
	it := idx.Get("Personal/water the plants")
	if it == nil || it.Bucket != BucketNow || it.Repeat != "weekly" {
		t.Fatalf("item = %+v", it)
	}
	if _, err := v.SetBody(it, "- [x] kitchen\n- [ ] hall\n"); err != nil {
		t.Fatal(err)
	}
	return v, it
}

func TestDoneWritesTheNextOccurrence(t *testing.T) {
	v, it := repeating(t)
	r, err := v.Done(it)
	if err != nil {
		t.Fatal(err)
	}
	closed := mustRead(t, v.Path("Personal/water the plants"))
	if !strings.Contains(closed, "done: 2026-09-20\n") || !strings.Contains(closed, "repeat: weekly\n") {
		t.Errorf("the closed note:\n%s", closed)
	}
	if !strings.Contains(strings.Join(r.Lines, "\n"), "↻ Personal/water the plants (2)  → when: 2026-09-25") {
		t.Errorf("report: %q", r.Lines)
	}
	// A fresh note: its own created:, no done:, the checklist back to empty —
	// and the title kept, since the file name had to step aside for the closed
	// one. `tracker done "water the plants"` still finds it by that title.
	next := mustRead(t, v.Path("Personal/water the plants (2)"))
	want := "---\nwhen: 2026-09-25\nrepeat: weekly\ndue: 2026-09-26\ntags:\n  - home\ncreated: 2026-09-20\ntitle: water the plants\n---\n- [ ] kitchen\n- [ ] hall\n"
	if next != want {
		t.Errorf("the next occurrence:\n%s\nwant:\n%s", next, want)
	}
	idx, err := v.Load()
	if err != nil {
		t.Fatal(err)
	}
	// Both the title and the closed note's own id are the occurrence now:
	// `tracker done "water the plants"` is tomorrow's chore, not a refusal.
	for _, q := range []string{"water the plants", "Personal/water the plants"} {
		if it, err := v.Resolve(idx, q, false); err != nil || it.ID != "Personal/water the plants (2)" {
			t.Errorf("Resolve(%q) = %v, %v — want the open occurrence", q, it, err)
		}
	}
	// A closed to-do that is not a series still says so.
	if it, err := v.Resolve(idx, "log/old thing", false); err != nil || it.ID != "log/old thing" {
		t.Errorf("a plain closed id: %v %v", it, err)
	} else if err := requireOpen(it); err == nil || !strings.Contains(err.Error(), "already closed") {
		t.Errorf("want the already-closed refusal, got %v", err)
	}
	// Undo is one gesture: the occurrence goes with the close.
	if err := r.Change.Undo(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(v.Path("Personal/water the plants (2)")); !os.IsNotExist(err) {
		t.Error("undo left the occurrence behind")
	}
	if got := mustRead(t, v.Path("Personal/water the plants")); strings.Contains(got, "done:") {
		t.Error("undo did not reopen the note")
	}
}

func TestDoneOnceOnly(t *testing.T) {
	v, it := repeating(t)
	if _, err := v.Done(it); err != nil {
		t.Fatal(err)
	}
	// reopen says the occurrence is there and leaves it alone.
	idx, _ := v.Load()
	closed, err := v.Resolve(idx, "Personal/water the plants", true)
	if err != nil {
		t.Fatal(err)
	}
	r, err := v.Reopen(closed)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(strings.Join(r.Lines, "\n"), "↻ next: Personal/water the plants (2) is open already") {
		t.Errorf("reopen: %q", r.Lines)
	}
	if _, err := os.Stat(v.Path("Personal/water the plants (2)")); err != nil {
		t.Fatal("reopen took the occurrence back")
	}
	// Closing it again does not write a second one.
	idx, _ = v.Load()
	again := idx.Get("Personal/water the plants")
	r, err = v.Done(again)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(strings.Join(r.Lines, "\n"), "is open already") {
		t.Errorf("second done: %q", r.Lines)
	}
	if _, err := os.Stat(v.Path("Personal/water the plants (3)")); !os.IsNotExist(err) {
		t.Error("done twice wrote two occurrences")
	}
}

func TestRepeatVerbsAndRefusals(t *testing.T) {
	v, it := repeating(t)
	// drop ends the series.
	if _, err := v.Drop(it); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(v.Path("Personal/water the plants (2)")); !os.IsNotExist(err) {
		t.Error("drop repeated the to-do")
	}
	// A repeat this does not parse closes the to-do and says so.
	v2, it2 := repeating(t)
	if _, err := v2.SetKey(it2, "repeat", "every other tuesday"); err != nil {
		t.Fatal(err)
	}
	r, err := v2.Done(it2)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(strings.Join(r.Lines, "\n"), "is not a repeat") {
		t.Errorf("report: %q", r.Lines)
	}
	if got := mustRead(t, v2.Path("Personal/water the plants")); !strings.Contains(got, "done: 2026-09-20\n") {
		t.Error("an unreadable repeat blocked the completion")
	}
	// SetRepeat writes and clears it.
	v3, it3 := repeating(t)
	if _, err := v3.SetRepeat(it3, ""); err != nil {
		t.Fatal(err)
	}
	if got := mustRead(t, v3.Path("Personal/water the plants")); strings.Contains(got, "repeat:") {
		t.Errorf("repeat not cleared:\n%s", got)
	}
	if _, err := v3.Done(it3); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(v3.Path("Personal/water the plants (2)")); !os.IsNotExist(err) {
		t.Error("a cleared repeat still repeated")
	}
}

func TestRepeatDryRunTouchesNothing(t *testing.T) {
	v, it := repeating(t)
	v.DryRun = true
	r, err := v.Done(it)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(strings.Join(r.Lines, "\n"), "would repeat") {
		t.Errorf("report: %q", r.Lines)
	}
	if _, err := os.Stat(v.Path("Personal/water the plants (2)")); !os.IsNotExist(err) {
		t.Error("a dry run wrote the occurrence")
	}
}
