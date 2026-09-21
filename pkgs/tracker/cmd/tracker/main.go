// tracker — the to-do list from a shell. With no arguments on a terminal it
// opens the TUI; anywhere else it is the CLI, and `tracker` alone is `today`.
package main

import (
	"os"

	"github.com/julienmartel/tracker/internal/cli"
	"github.com/julienmartel/tracker/internal/tui"
	"github.com/julienmartel/tracker/internal/vault"
	"golang.org/x/term"
)

var version = "dev"

func main() {
	cli.Version = version
	args := os.Args[1:]
	if len(args) == 0 && term.IsTerminal(int(os.Stdin.Fd())) && term.IsTerminal(int(os.Stdout.Fd())) {
		os.Exit(tui.Run(vault.Open()))
	}
	os.Exit(cli.Main(args, os.Stdout, os.Stderr))
}
