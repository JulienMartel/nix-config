#!/usr/bin/env perl
# zellij `copy_command` filter — clean up terminal-grid selections before they
# land on the macOS clipboard.
#
# Terminal selection copies the *visual grid*: Claude Code renders every message
# inside a ~2-space left gutter and hard-wraps long paragraphs at the pane width,
# so a raw copy carries gutter spaces on most lines + a newline at each wrap. The
# first line of a message often sits at column 0 (the bullet ate its gutter),
# which is why a naive "strip the common prefix" strips nothing.
#
# Strategy: split the selection into blocks (separated by blank lines), classify
# each, and clean it accordingly:
#   • prose  — rejoin the wrapped lines into one paragraph
#   • list   — rejoin each item's wrapped continuation, keep items separate
#   • code / table — leave byte-for-byte (only the shared gutter is dedented)
#
# This is deliberately PROSE-FIRST: normal writing must always paste cleanly.
# The one discriminator that keeps code from being flattened is LINE FULLNESS —
# prose lines wrap because they *ran out of room* (near the pane width), while
# code lines end at logical boundaries (short), so a code block fails the
# "all lines full" test and falls through to verbatim. We deliberately do NOT
# guard on semicolons / punctuation / symbol density: prose uses those too, and
# such guards only cause prose to stay wrongly wrapped. (Copy code with an
# explicit pbcopy/echo if you need it byte-for-byte.) Set COPY_CLEAN_STDOUT=1 to
# print to stdout instead of piping to pbcopy (for testing).
use strict;
use warnings;

my $text = do { local $/; <STDIN> };
$text = '' unless defined $text;
$text =~ s/\r\n?/\n/g;
my @lines = split /\n/, $text, -1;
s/\s+$// for @lines;                              # drop trailing whitespace

# wrap column ≈ the widest line in the selection; a line is "full" (i.e. wrapped
# rather than deliberately broken) when it reaches ~2/3 of that width.
my $wrap = 0;
for my $l (@lines) { my $n = length $l; $wrap = $n if $n > $wrap; }
my $reflow_ok = $wrap >= 40;
my $full_at   = int($wrap * 0.6);

# --- split into blocks separated by blank lines ------------------------------
my (@blocks, @cur);
for my $l (@lines) {
    if ($l eq '') { push @blocks, [@cur] if @cur; @cur = (); }
    else          { push @cur, $l; }
}
push @blocks, [@cur] if @cur;

sub leading { my ($w) = $_[0] =~ /^(\s*)/; return length $w; }
sub is_marker { return $_[0] =~ /^\s*(?:[-*+•]\s|\d+[.)]\s)/; }

# dedent a block by its own common leading whitespace (preserves relative indent)
sub dedent {
    my ($blk) = @_;
    my $min;
    for my $l (@$blk) {
        my $n = leading($l);
        $min = $n if !defined $min || $n < $min;
    }
    $min //= 0;
    return map { my $x = $_; $x =~ s/^\s{0,$min}// if $min; $x } @$blk;
}

# Only tables and brace-delimited code stay verbatim. Tables must keep their
# rows; a line ending in { or } is real code (prose never does). Everything else
# is left to the fullness gate below — that alone keeps short code lines from
# being joined, without ever mis-guarding prose punctuation.
sub is_verbatim {
    my ($blk) = @_;
    for my $l (@$blk) {
        return 1 if $l =~ /\|/;              # table row
        return 1 if $l =~ /[{}]\s*$/;        # brace-delimited code line
    }
    return 0;
}

# prose: every line but the last is "full" (was wrapped, not hard-broken)
sub is_prose {
    my ($blk) = @_;
    return 0 unless $reflow_ok;
    return 0 if @$blk < 2;
    for my $i (0 .. $#$blk - 1) {
        return 0 if length($blk->[$i]) < $full_at;
    }
    return 1;
}

sub strip { my $x = $_[0]; $x =~ s/^\s+//; $x =~ s/\s+$//; return $x; }

my @out;
for my $blk (@blocks) {
    if (is_verbatim($blk)) {
        push @out, join("\n", dedent($blk));
    }
    elsif (grep { is_marker($_) } @$blk) {
        # list: start a new item at each marker line, fold wrapped
        # continuation lines into the item they belong to.
        my @ded = dedent($blk);
        my @items;
        for my $l (@ded) {
            if (is_marker($l)) { push @items, $l; }
            elsif (@items)     { $items[-1] .= ' ' . strip($l); }
            else               { push @items, strip($l); }
        }
        push @out, join("\n", @items);
    }
    elsif (is_prose($blk)) {
        push @out, join(' ', map { strip($_) } @$blk);
    }
    else {
        push @out, join("\n", dedent($blk));
    }
}

my $result = join("\n\n", @out);

if ($ENV{COPY_CLEAN_STDOUT}) {
    print $result;
} else {
    open(my $pb, '|-', 'pbcopy') or die "copy-clean: cannot exec pbcopy: $!\n";
    print $pb $result;
    close($pb);
}
