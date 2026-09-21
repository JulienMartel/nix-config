package cli

import (
	"fmt"
	"os"
	"sort"
	"strconv"
	"strings"

	"github.com/julienmartel/tracker/internal/vault"
)

// ── reads ────────────────────────────────────────────────────────────────────

func (a *App) view(name string, args []string) error {
	idx, err := a.load()
	if err != nil {
		return err
	}
	today := a.V.Today()
	arg := func(def int) (int, error) {
		if len(args) == 0 {
			return def, nil
		}
		n, err := strconv.Atoi(args[0])
		if err != nil || n < 0 {
			return 0, vault.UsageError("usage: tracker " + name + " [n]")
		}
		return n, nil
	}
	var items []*vault.Item
	group := ""
	switch name {
	case "today":
		items = filter(idx.Open(), func(it *vault.Item) bool { return it.Bucket == vault.BucketNow })
		sortBy(items, byDue, byID)
	case "later":
		items = filter(idx.Open(), func(it *vault.Item) bool { return it.Bucket == vault.BucketLater })
		sortBy(items, byFolder, byCreatedDesc, byID)
		group = "folder"
	case "someday":
		items = filter(idx.Open(), func(it *vault.Item) bool { return it.Bucket == vault.BucketSomeday })
		sortBy(items, byFolder, byID)
		group = "folder"
	case "upcoming":
		days, err := arg(14)
		if err != nil {
			return err
		}
		until := a.V.Now().AddDate(0, 0, days).Format("2006-01-02")
		items = filter(idx.Open(), func(it *vault.Item) bool { return it.Bucket == vault.BucketScheduled && it.When <= until })
		sortBy(items, byWhen, byID)
	case "due":
		days, err := arg(30)
		if err != nil {
			return err
		}
		until := a.V.Now().AddDate(0, 0, days).Format("2006-01-02")
		items = filter(idx.Open(), func(it *vault.Item) bool { return it.Due != "" && it.Due <= until })
		sortBy(items, byDue, byID)
	case "inbox":
		items = filter(idx.Open(), func(it *vault.Item) bool { return it.Folder == "" && it.Bucket == vault.BucketLater })
		sortBy(items, byCreatedDesc, byID)
	case "done-list":
		n, err := arg(20)
		if err != nil {
			return err
		}
		items = idx.Closed()
		sortBy(items, byClosedDesc, byID)
		if n > 0 && len(items) > n {
			items = items[:n]
		}
	case "index":
		items = idx.Items
	}
	_ = today
	return a.rows(items, group)
}

func (a *App) list(args []string) error {
	if len(args) == 0 {
		return vault.UsageError("usage: tracker list <project>")
	}
	idx, err := a.load()
	if err != nil {
		return err
	}
	folder, err := a.V.ResolveFolder(idx, strings.Join(args, " "))
	if err != nil {
		return err
	}
	items := filter(idx.Open(), func(it *vault.Item) bool {
		return it.Folder == folder || strings.HasPrefix(it.Folder, folder+"/")
	})
	sortBy(items, byBucket, byWhen, byDue, byID)
	return a.rows(items, "bucket")
}

func (a *App) search(args []string) error {
	if len(args) == 0 {
		return vault.UsageError("usage: tracker search <text>")
	}
	idx, err := a.load()
	if err != nil {
		return err
	}
	q := strings.ToLower(strings.Join(args, " "))
	items := filter(idx.Todos(), func(it *vault.Item) bool {
		return strings.Contains(strings.ToLower(it.Title), q) ||
			strings.Contains(strings.ToLower(it.ID), q) ||
			strings.Contains(strings.ToLower(it.Body()), q)
	})
	sortBy(items, byFolder, byID)
	return a.rows(items, "folder")
}

// projectRow is `projects --json`: not a to-do, so its own shape.
type projectRow struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Depth int    `json:"depth"`
	Open  int    `json:"open"`
	Repo  string `json:"repo"`
	Path  string `json:"path"`
}

func (a *App) projects() error {
	idx, err := a.load()
	if err != nil {
		return err
	}
	folders := a.V.Folders(idx)
	unfiled := len(filter(idx.Open(), func(it *vault.Item) bool { return it.Folder == "" }))
	if a.JSON {
		rows := []projectRow{{ID: "", Name: "inbox", Open: unfiled, Path: a.V.Dir}}
		for _, f := range folders {
			rows = append(rows, projectRow{ID: f.Path, Name: f.Name, Depth: f.Depth, Open: f.Open, Repo: f.Repo, Path: a.V.Path(f.Path + "/" + f.Name)})
		}
		return a.printJSON(rows)
	}
	fmt.Fprintf(a.Out, "%-44s %4d open\n", "(unfiled)", unfiled)
	for _, f := range folders {
		name := strings.Repeat("  ", f.Depth) + f.Name
		line := fmt.Sprintf("%-44s %4d open", name, f.Open)
		if f.Repo != "" {
			line += "  " + f.Repo
		}
		fmt.Fprintln(a.Out, line)
	}
	return nil
}

func (a *App) show(args []string) error {
	if len(args) == 0 {
		return vault.UsageError("usage: tracker show <id>")
	}
	idx, err := a.load()
	if err != nil {
		return err
	}
	it, err := a.resolve(idx, strings.Join(args, " "), false)
	if err != nil {
		// `show` is a read: a closed note by exact id is fine too.
		if it2, err2 := a.resolve(idx, strings.Join(args, " "), true); err2 == nil {
			it, err = it2, nil
		} else {
			return err
		}
	}
	if a.JSON {
		type withBody struct {
			*vault.Item
			Body string `json:"body"`
			File string `json:"file"`
		}
		return a.printJSON(withBody{it, it.Body(), vault.FileURL(it.Path)})
	}
	fmt.Fprintf(a.Out, "id:    %s\n", it.ID)
	if it.Title != it.Note.Name() {
		fmt.Fprintf(a.Out, "title: %s\n", it.Title)
	}
	fmt.Fprintln(a.Out, vault.FileURL(it.Path))
	fmt.Fprintln(a.Out, a.V.ObsidianURL(it.Path))
	fmt.Fprintln(a.Out)
	data, err := os.ReadFile(it.Path)
	if err != nil {
		return err
	}
	a.Out.Write(data)
	if len(data) > 0 && data[len(data)-1] != '\n' {
		fmt.Fprintln(a.Out)
	}
	return nil
}

func (a *App) link(args []string) error {
	if len(args) == 0 {
		return vault.UsageError("usage: tracker link <id>")
	}
	idx, err := a.load()
	if err != nil {
		return err
	}
	it, err := a.resolve(idx, strings.Join(args, " "), false)
	if err != nil {
		if it2, err2 := a.resolve(idx, strings.Join(args, " "), true); err2 == nil {
			it, err = it2, nil
		} else {
			return err
		}
	}
	if a.JSON {
		return a.printJSON(map[string]string{"id": it.ID, "file": vault.FileURL(it.Path), "obsidian": a.V.ObsidianURL(it.Path)})
	}
	fmt.Fprintln(a.Out, vault.FileURL(it.Path))
	fmt.Fprintln(a.Out, a.V.ObsidianURL(it.Path))
	return nil
}

// rows prints items as text (grouped when asked) or JSON.
func (a *App) rows(items []*vault.Item, group string) error {
	if a.JSON {
		if items == nil {
			items = []*vault.Item{}
		}
		return a.printJSON(items)
	}
	if len(items) == 0 {
		fmt.Fprintln(a.Out, "(nothing)")
		return nil
	}
	prev := "\x00"
	for _, it := range items {
		if group != "" {
			key := it.Folder
			if group == "bucket" {
				key = it.Bucket
			}
			if key != prev {
				if prev != "\x00" {
					fmt.Fprintln(a.Out)
				}
				label := key
				if label == "" {
					label = "(unfiled)"
				}
				fmt.Fprintf(a.Out, "── %s ──\n", label)
				prev = key
			}
		}
		fmt.Fprintln(a.Out, Row(it))
	}
	fmt.Fprintf(a.Out, "\n%d item(s)\n", len(items))
	return nil
}

// Row is one to-do as a line: state, due, tags, id — the id last so it can
// be as long as it likes.
func Row(it *vault.Item) string {
	state := vault.Glyph(vault.State(it)) + " " + StateLabel(it)
	due := ""
	if it.Due != "" {
		due = "due " + it.Due
	}
	tags := ""
	if len(it.Tags) > 0 {
		tags = "#" + strings.Join(it.Tags, " #")
	}
	if it.IsProject {
		state = "▸ project"
	}
	return fmt.Sprintf("%-13s %-14s %-16s %s", state, due, tags, it.ID)
}

// StateLabel is the word after the glyph: the bucket, a date, or how it closed.
func StateLabel(it *vault.Item) string {
	switch {
	case it.IsProject:
		return "project"
	case it.Done != "":
		return it.Done
	case it.Dropped != "":
		return it.Dropped
	case it.Bucket == vault.BucketScheduled:
		return it.When
	}
	return it.Bucket
}

// ── sorting ──────────────────────────────────────────────────────────────────

type less func(a, b *vault.Item) int

func filter(items []*vault.Item, keep func(*vault.Item) bool) []*vault.Item {
	var out []*vault.Item
	for _, it := range items {
		if keep(it) {
			out = append(out, it)
		}
	}
	return out
}

func sortBy(items []*vault.Item, keys ...less) {
	sort.SliceStable(items, func(i, j int) bool {
		for _, k := range keys {
			if c := k(items[i], items[j]); c != 0 {
				return c < 0
			}
		}
		return false
	})
}

func cmp(a, b string) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	}
	return 0
}

// An empty date sorts last: a to-do with no deadline is not the most urgent.
func cmpDate(a, b string) int {
	switch {
	case a == b:
		return 0
	case a == "":
		return 1
	case b == "":
		return -1
	}
	return cmp(a, b)
}

var (
	byID          less = func(a, b *vault.Item) int { return cmp(strings.ToLower(a.ID), strings.ToLower(b.ID)) }
	byDue         less = func(a, b *vault.Item) int { return cmpDate(a.Due, b.Due) }
	byWhen        less = func(a, b *vault.Item) int { return cmpDate(a.When, b.When) }
	byFolder      less = func(a, b *vault.Item) int { return cmp(strings.ToLower(a.Folder), strings.ToLower(b.Folder)) }
	byCreatedDesc less = func(a, b *vault.Item) int { return -cmpDate(a.Created, b.Created) }
	byClosedDesc  less = func(a, b *vault.Item) int { return -cmp(a.Closed(), b.Closed()) }
	byBucket      less = func(a, b *vault.Item) int { return cmp(bucketOrder(a.Bucket), bucketOrder(b.Bucket)) }
)

func bucketOrder(b string) string {
	switch b {
	case vault.BucketNow:
		return "1"
	case vault.BucketScheduled:
		return "2"
	case vault.BucketLater:
		return "3"
	}
	return "4"
}
