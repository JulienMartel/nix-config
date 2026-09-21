package vault

import (
	"fmt"
	"regexp"
	"strconv"
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
