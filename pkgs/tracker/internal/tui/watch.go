package tui

import (
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/fsnotify/fsnotify"
)

// ── the watcher: a change from Obsidian or the phone repaints within a second ─
//
// fsnotify is not recursive, so every folder under tracker/ is added, and a
// folder that appears later is added when its create event arrives. Events
// are debounced: iCloud and Obsidian both write in bursts, and one reload
// per burst is plenty for an index that loads in milliseconds.

const debounce = 250 * time.Millisecond

type watcher struct {
	w    *fsnotify.Watcher
	done chan struct{}
}

func newWatcher(dir string, out chan<- struct{}) (*watcher, error) {
	w, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, err
	}
	addAll := func(root string) {
		_ = filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			if d.IsDir() {
				if strings.HasPrefix(d.Name(), ".") && p != root {
					return filepath.SkipDir
				}
				_ = w.Add(p)
			}
			return nil
		})
	}
	addAll(dir)
	ww := &watcher{w: w, done: make(chan struct{})}
	go func() {
		var timer *time.Timer
		var fire <-chan time.Time
		for {
			select {
			case <-ww.done:
				return
			case ev, ok := <-w.Events:
				if !ok {
					return
				}
				// A temp file is our own half-written note; the rename that
				// follows is the event that matters.
				if strings.Contains(ev.Name, ".tmp.") && !ev.Has(fsnotify.Rename) {
					continue
				}
				if ev.Has(fsnotify.Create) {
					if st, err := os.Stat(ev.Name); err == nil && st.IsDir() {
						addAll(ev.Name)
					}
				}
				if timer == nil {
					timer = time.NewTimer(debounce)
				} else {
					timer.Reset(debounce)
				}
				fire = timer.C
			case <-fire:
				fire = nil
				select {
				case out <- struct{}{}:
				default:
				}
			case <-w.Errors:
			}
		}
	}()
	return ww, nil
}

func (ww *watcher) close() {
	close(ww.done)
	ww.w.Close()
}
