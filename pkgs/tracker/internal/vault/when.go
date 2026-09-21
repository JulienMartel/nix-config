package vault

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// ── when: the one field that matters ─────────────────────────────────────────

// The three words `when` can be besides a date.
const (
	Now     = "now"
	Later   = "later"
	Someday = "someday"
)

// Buckets: what a `when` means today. `scheduled` is a date still ahead.
const (
	BucketNow       = "now"
	BucketScheduled = "scheduled"
	BucketLater     = "later"
	BucketSomeday   = "someday"
)

const dateLayout = "2006-01-02"

var (
	dateRE  = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
	plusRE  = regexp.MustCompile(`^\+(\d+)d$`)
	usageRE = "today | tomorrow | +Nd | YYYY-MM-DD"
)

// IsDate reports whether s is a `YYYY-MM-DD` that exists.
func IsDate(s string) bool {
	if !dateRE.MatchString(s) {
		return false
	}
	_, err := time.Parse(dateLayout, s)
	return err == nil
}

// ParseDate turns today | tomorrow | +Nd | YYYY-MM-DD into a date, relative to
// today. A UsageError, because a date that will not parse is a typo, not a
// state of the list.
func ParseDate(s string, today time.Time) (string, error) {
	switch s {
	case "today":
		return today.Format(dateLayout), nil
	case "tomorrow":
		return today.AddDate(0, 0, 1).Format(dateLayout), nil
	}
	if m := plusRE.FindStringSubmatch(s); m != nil {
		n, _ := strconv.Atoi(m[1])
		return today.AddDate(0, 0, n).Format(dateLayout), nil
	}
	if IsDate(s) {
		return s, nil
	}
	return "", UsageError(fmt.Sprintf("%q is not a date — %s", s, usageRE))
}

// ParseWhen turns what a verb was given into what `when:` stores: now | later
// | someday, or a date — which is `now` already if it has arrived.
func ParseWhen(s string, today time.Time) (string, error) {
	switch s {
	case Now, Later, Someday:
		return s, nil
	case "anytime": // the old word for later, kept for old habits
		return Later, nil
	}
	d, err := ParseDate(s, today)
	if err != nil {
		return "", UsageError(fmt.Sprintf("%q is not a when — now | later | someday | %s", s, usageRE))
	}
	return Normalize(d, today), nil
}

// Normalize folds an arrived date into `now`; everything else is itself. An
// empty `when` — a note made by hand in Obsidian — is `later`.
func Normalize(when string, today time.Time) string {
	switch {
	case when == "":
		return Later
	case IsDate(when) && when <= today.Format(dateLayout):
		return Now
	}
	return when
}

// Bucket is where a normalized `when` sits: a word is its own bucket, a date
// still ahead is scheduled, and anything unrecognised reads as later so a
// typo in Obsidian never hides a to-do.
func Bucket(when string) string {
	switch {
	case when == Now:
		return BucketNow
	case when == Someday:
		return BucketSomeday
	case IsDate(when):
		return BucketScheduled
	}
	return BucketLater
}

// bucketRank orders the buckets the way the Project view groups them.
func bucketRank(b string) int {
	switch b {
	case BucketNow:
		return 0
	case BucketScheduled:
		return 1
	case BucketLater:
		return 2
	}
	return 3
}

// ── repeat: the same to-do, again ────────────────────────────────────────────
//
// The grammar is narrow on purpose — it is a parser, not a schema, so it can
// widen without any note changing. `repeat:` is the only property that says
// anything about the future: `done` reads it, writes the next occurrence and
// never touches it again.

var (
	repeatRE    = regexp.MustCompile(`^every (\d+) (day|week|month|year)s?$`)
	repeatWords = map[string]string{"daily": "day", "weekly": "week", "monthly": "month", "yearly": "year"}
	repeatUnit  = map[string]string{"day": "daily", "week": "weekly", "month": "monthly", "year": "yearly"}
	repeatUsage = "daily | weekly | monthly | yearly | every N days"
)

// ParseRepeat canonicalizes what a verb was given into what `repeat:` stores:
// one of the four words, or `every N days`. Empty, `none` and `never` clear
// it — a to-do that no longer comes back.
func ParseRepeat(s string) (string, error) {
	spec := strings.ToLower(strings.Join(strings.Fields(s), " "))
	switch spec {
	case "", "none", "never":
		return "", nil
	}
	n, unit, ok := repeatParts(spec)
	if !ok {
		return "", UsageError(fmt.Sprintf("%q is not a repeat — %s", s, repeatUsage))
	}
	if n == 1 {
		return repeatUnit[unit], nil
	}
	return fmt.Sprintf("every %d %ss", n, unit), nil
}

// IsRepeat reports whether a spec is one this understands — false for the
// `repeat: every other Tuesday` a note can hold, which is a note to a person.
func IsRepeat(spec string) bool { _, _, ok := repeatParts(spec); return ok }

func repeatParts(spec string) (int, string, bool) {
	spec = strings.ToLower(strings.Join(strings.Fields(spec), " "))
	if unit, ok := repeatWords[spec]; ok {
		return 1, unit, true
	}
	if m := repeatRE.FindStringSubmatch(spec); m != nil {
		n, err := strconv.Atoi(m[1])
		if err != nil || n < 1 {
			return 0, "", false
		}
		return n, m[2], true
	}
	return 0, "", false
}

// NextWhen is the `when:` a repeating to-do comes back on, and the days to
// carry a `due:` by so a deadline keeps its lead time.
//
// The count is the note's OWN `when:`, never the day it was completed, so a
// chore done three days late does not drift — and it is advanced until it is
// past today, so the late one lands on its next real slot instead of a
// backlog. A `when` that is a word (now | later | someday) has no grid to
// keep, so it counts from today.
func NextWhen(when, spec string, today time.Time) (string, int, error) {
	n, unit, ok := repeatParts(spec)
	if !ok {
		return "", 0, UsageError(fmt.Sprintf("%q is not a repeat — %s", spec, repeatUsage))
	}
	today = dayOf(today)
	from := today
	if IsDate(when) {
		from, _ = time.Parse(dateLayout, when)
	}
	// At least one step — a to-do done early still comes back a period after
	// the day it was set for, not on it. The cap is a daily to-do whose
	// `when` went a decade stale; past that the grid is not worth keeping and
	// today is the only honest anchor.
	next := advance(from, n, unit)
	for i := 0; i < 4000 && !next.After(today); i++ {
		next = advance(next, n, unit)
	}
	if !next.After(today) {
		from, next = today, advance(today, n, unit)
	}
	return next.Format(dateLayout), int(next.Sub(from).Hours() / 24), nil
}

func advance(d time.Time, n int, unit string) time.Time {
	switch unit {
	case "day":
		return d.AddDate(0, 0, n)
	case "week":
		return d.AddDate(0, 0, 7*n)
	case "month":
		return addMonths(d, n)
	}
	return addMonths(d, 12*n)
}

// addMonths keeps the day of the month, clamped to the length of the month it
// lands in: the 31st monthly is the 30th in April and the 28th in February,
// where Go's own AddDate spills into the month after.
func addMonths(d time.Time, n int) time.Time {
	y, m, day := d.Date()
	first := time.Date(y, m, 1, 0, 0, 0, 0, time.UTC).AddDate(0, n, 0)
	if last := time.Date(first.Year(), first.Month()+1, 0, 0, 0, 0, 0, time.UTC).Day(); day > last {
		day = last
	}
	return time.Date(first.Year(), first.Month(), day, 0, 0, 0, 0, time.UTC)
}

// dayOf drops the clock: every date this file compares is a midnight in UTC.
func dayOf(t time.Time) time.Time {
	y, m, d := t.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}
