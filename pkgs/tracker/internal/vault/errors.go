package vault

import (
	"fmt"
	"strings"
)

// ── the three exits: 0 ok · 1 nothing matched / refused · 2 usage ────────────

// UsageError is argv the caller got wrong: exit 2.
type UsageError string

func (e UsageError) Error() string { return string(e) }

// RefusedError is a request the list cannot honour as asked — nothing
// matched, already closed, a project that is not there: exit 1.
type RefusedError string

func (e RefusedError) Error() string { return string(e) }

// AmbiguousError is a substring that matched more than one item. The
// candidates are the message: show them, never pick one.
type AmbiguousError struct {
	Query      string
	Candidates []string
}

func (e *AmbiguousError) Error() string {
	return fmt.Sprintf("%q is ambiguous:\n%s", e.Query, strings.Join(e.Candidates, "\n"))
}

// ExitCode maps an error to the process exit the README promises.
func ExitCode(err error) int {
	switch err.(type) {
	case nil:
		return 0
	case UsageError:
		return 2
	}
	return 1
}
