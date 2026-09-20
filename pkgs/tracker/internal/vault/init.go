package vault

import (
	"bytes"
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"

	tracker "github.com/julienmartel/tracker"
)

// ── init: the folders, the base, the property types, the plugin ──────────────

// propertyTypes is what .obsidian/types.json says about our keys, so Bases
// compares a date as a date and `when` — a word or a date — as text.
var propertyTypes = map[string]string{
	"when": "text", "due": "date", "done": "date", "dropped": "date", "created": "date",
	"type": "text", "repo": "text", "lane": "text", "project": "text", "title": "text", "things": "text",
}

// oldPropertyKeys are the Things-shaped keys, and the "" key an early
// experiment left behind; init removes them.
var oldPropertyKeys = []string{"status", "heading", "deadline", "evening", "area", ""}

// Init makes tracker/ and log/, writes tracker.base (force restores it),
// merges the property types, and installs the plugin.
func (v *Vault) Init(force bool) (*Report, error) {
	r := &Report{}
	if v.DryRun {
		r.say("dry run — would init %s", v.Dir)
		r.Path = v.Dir
		return r, nil
	}
	for _, d := range []string{v.Dir, v.LogDir()} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return nil, err
		}
	}
	base := filepath.Join(v.Dir, "tracker.base")
	have, err := os.ReadFile(base)
	switch {
	case err == nil && bytes.Equal(have, tracker.Base):
		r.say("tracker.base is the shipped one")
	case err == nil && !force:
		r.say("tracker.base kept (yours) — tracker init --force restores the shipped one")
	default:
		if err := writeAtomic(base, tracker.Base); err != nil {
			return nil, err
		}
		r.say("wrote tracker/tracker.base")
	}
	if err := v.mergeTypes(r); err != nil {
		return nil, err
	}
	if err := v.installPlugin(r); err != nil {
		return nil, err
	}
	r.say("tracker at %s", v.Dir)
	r.Path = v.Dir
	return r, nil
}

func (v *Vault) obsidianDir() string { return filepath.Join(v.Root, ".obsidian") }

func (v *Vault) mergeTypes(r *Report) error {
	path := filepath.Join(v.obsidianDir(), "types.json")
	doc := map[string]any{}
	if data, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(data, &doc)
	}
	types, _ := doc["types"].(map[string]any)
	if types == nil {
		types = map[string]any{}
	}
	for k, t := range propertyTypes {
		types[k] = t
	}
	for _, k := range oldPropertyKeys {
		delete(types, k)
	}
	doc["types"] = types
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	if err := writeAtomic(path, append(out, '\n')); err != nil {
		return err
	}
	r.say("typed when/due/done/dropped/created in .obsidian/types.json")
	return nil
}

func (v *Vault) installPlugin(r *Report) error {
	dir := filepath.Join(v.obsidianDir(), "plugins", "tracker")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	err := fs.WalkDir(tracker.Plugin, "obsidian-plugin", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		data, err := tracker.Plugin.ReadFile(p)
		if err != nil {
			return err
		}
		return writeAtomic(filepath.Join(dir, filepath.Base(p)), data)
	})
	if err != nil {
		return err
	}
	list := filepath.Join(v.obsidianDir(), "community-plugins.json")
	var plugins []string
	if data, err := os.ReadFile(list); err == nil {
		_ = json.Unmarshal(data, &plugins)
	}
	enabled := contains(plugins, "tracker")
	if !enabled {
		plugins = append(plugins, "tracker")
		out, err := json.MarshalIndent(plugins, "", "  ")
		if err != nil {
			return err
		}
		if err := writeAtomic(list, append(out, '\n')); err != nil {
			return err
		}
	}
	if enabled {
		r.say("installed plugin .obsidian/plugins/tracker (enabled)")
	} else {
		r.say("installed plugin .obsidian/plugins/tracker and enabled it")
	}
	return nil
}
