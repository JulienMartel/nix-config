#!/usr/bin/env perl
# zellij `copy_command` filter — clean up terminal-grid selections before they
# land on the macOS clipboard.
#
# Terminal selection copies the *visual grid*: Claude Code renders every message
# inside a left gutter and hard-wraps long paragraphs at the pane width, so a
# raw copy carries gutter spaces on every line + a newline at each visual wrap.
# We undo that in three passes:
#
#   1. dedent  — strip the common leading whitespace (the message gutter).
#                Safe for code: only the *shared* prefix goes, relative indent
#                is preserved.
#   2. trim    — drop trailing whitespace, collapse blank-line runs to one.
#   3. reflow  — rejoin hard-wrapped PROSE into paragraphs. Heavily guarded so
#                code / lists / tables / indented blocks are left byte-for-byte:
#                a newline is only removed when the line it ends was "full"
#                (near the wrap width) AND neither side looks structural.
#
# Whatever survives is piped to pbcopy. Wired as `copy_command` in config.kdl.
use strict;
use warnings;

my $text = do { local $/; <STDIN> };
$text = '' unless defined $text;
$text =~ s/\r\n?/\n/g;
my @lines = split /\n/, $text, -1;

# --- 1. dedent: remove the longest common leading-whitespace prefix -----------
my $min_indent;
for my $l (@lines) {
    next if $l =~ /^\s*$/;                       # blank lines don't constrain
    my ($ws) = $l =~ /^(\s*)/;
    my $n = length $ws;
    $min_indent = $n if !defined $min_indent || $n < $min_indent;
}
$min_indent //= 0;

for my $l (@lines) {
    if ($l =~ /^\s*$/) { $l = ''; next; }        # normalize blank lines
    $l =~ s/^\s{0,$min_indent}// if $min_indent;
    $l =~ s/\s+$//;                              # 2. trim trailing whitespace
}

# --- estimate the wrap column from the widest line ---------------------------
my $wrap = 0;
for my $l (@lines) { my $n = length $l; $wrap = $n if $n > $wrap; }
# Too-narrow selections (inline snippets, short code) are never treated as
# wrapped prose — reflow only engages when there's a real wrap column to speak of.
my $reflow_ok = $wrap >= 40;
my $full_at   = $wrap - 12;                      # a line this long "ran out of room"

# A structural line is never joined (as source or target): blank, relatively
# indented (=> code/nested), or a list / quote / heading / table / code-bracket.
sub structural {
    my ($l) = @_;
    return 1 if $l eq '';
    return 1 if $l =~ /^\s/;                     # indented past the dedented base
    return 1 if $l =~ /^(?:[-*+•]\s|\d+[.)]\s|>|#{1,6}\s)/;  # list / quote / heading
    return 1 if $l =~ /\|/;                      # table pipe
    return 1 if $l =~ /[{};]$/;                  # code statement/block ending
    return 1 if $l =~ /^[)}\]]/;                 # closing bracket opens the line
    return 0;
}

# --- 3. reflow: greedily absorb full-wrap continuation lines -----------------
my @out;
my $i = 0;
while ($i <= $#lines) {
    my $cur = $lines[$i];
    if ($reflow_ok && !structural($cur)) {
        while ($i < $#lines) {
            my $tail = $lines[$i];              # most recently absorbed physical line
            my $next = $lines[$i + 1];
            last if structural($next);
            last if length($tail) < $full_at;   # tail wasn't full => intentional break
            $cur .= ' ' . $next;
            $i++;
        }
    }
    push @out, $cur;
    $i++;
}

# collapse blank runs to a single blank; trim leading/trailing blanks
my @final;
my $blank = 0;
for my $l (@out) {
    if ($l eq '') { push @final, '' if $blank++ == 0; }
    else          { $blank = 0; push @final, $l; }
}
shift @final while @final && $final[0] eq '';
pop   @final while @final && $final[-1] eq '';

open(my $pb, '|-', 'pbcopy') or die "copy-clean: cannot exec pbcopy: $!\n";
print $pb join("\n", @final);
close($pb);
