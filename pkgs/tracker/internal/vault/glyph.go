package vault

// Glyph is the one-character state of a to-do, the same in the CLI, the TUI
// and the README: ● now · ◔ scheduled · ○ later · ◌ someday · ✓ done · ✗ dropped.
func Glyph(bucket string) string {
	switch bucket {
	case BucketNow:
		return "●"
	case BucketScheduled:
		return "◔"
	case BucketSomeday:
		return "◌"
	case "done":
		return "✓"
	case "dropped":
		return "✗"
	}
	return "○"
}

// State is the glyph's key for an item: its bucket while open, else how it
// closed.
func State(it *Item) string {
	switch {
	case it.Done != "":
		return "done"
	case it.Dropped != "":
		return "dropped"
	}
	return it.Bucket
}
