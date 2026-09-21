package vault

import (
	"path/filepath"
	"strings"
)

// ── links: the file:// line a pane makes clickable, and the app's own ────────

// uriEscape percent-encodes the way jq's @uri does: everything but the
// unreserved set, so a space is %20 and a `#` in a name never becomes a
// fragment.
func uriEscape(s string) string {
	const hex = "0123456789ABCDEF"
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-' || c == '_' || c == '.' || c == '~' {
			b.WriteByte(c)
			continue
		}
		b.WriteByte('%')
		b.WriteByte(hex[c>>4])
		b.WriteByte(hex[c&15])
	}
	return b.String()
}

// FileURL is file:///…, every path segment encoded.
func FileURL(path string) string {
	parts := strings.Split(filepath.ToSlash(path), "/")
	for i, p := range parts {
		parts[i] = uriEscape(p)
	}
	return "file://" + strings.Join(parts, "/")
}

// VaultName is what obsidian:// calls this vault: its folder name.
func (v *Vault) VaultName() string { return filepath.Base(v.Root) }

// VaultRel is a note's path relative to the vault, as obsidian:// wants it.
func (v *Vault) VaultRel(path string) string {
	if rel, err := filepath.Rel(v.Root, path); err == nil && !strings.HasPrefix(rel, "..") {
		return filepath.ToSlash(rel)
	}
	return "tracker/" + v.ID(path) + ".md"
}

// ObsidianURL opens the note in the app. Never run from the CLI — it is the
// user's screen — only printed, and run by the TUI's `o`.
func (v *Vault) ObsidianURL(path string) string {
	return "obsidian://open?vault=" + uriEscape(v.VaultName()) + "&file=" + uriEscape(v.VaultRel(path))
}
