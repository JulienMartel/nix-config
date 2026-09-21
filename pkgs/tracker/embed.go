// Package tracker carries what `tracker init` writes into a vault: the base
// file with every view, and the Obsidian plugin. Embedded so the binary is the
// whole install — nothing to fetch, nothing to keep beside it. The directives
// live at the module root because go:embed cannot reach a parent directory and
// obsidian-plugin/ is edited as its own thing, beside the Go code, not under it.
package tracker

import "embed"

// Base is assets/tracker.base, byte for byte. `tracker init --force` restores it.
//
//go:embed assets/tracker.base
var Base []byte

// Plugin is the obsidian-plugin/ directory: main.js and manifest.json, plain
// JS with no build step, installed into .obsidian/plugins/tracker/.
//
//go:embed obsidian-plugin/*
var Plugin embed.FS
