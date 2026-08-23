# A pi TUI theme, rendered from a Nebelung palette.
#
# pi is not a nebelung port — nebelung renders ghostty/helix/opencode/… from
# templates in its own repo, and pi is on trial here, not shipped by the layer.
# So this file is the port, kept in the shape the real ones use: take a
# `name -> "#hex"` palette plus the accent NAME, return the theme. Both poles
# (dark + latte) come from the same function, which is why nothing below may
# assume a dark background — every background is mixed against `base`, so a
# palette whose base is light produces light tints without a second mapping.
#
# The token list is pi's, and it is exhaustive on purpose: pi requires all 51
# colors and fails the theme if one is missing, so a pi bump that adds a token
# shows up as a startup error rather than a silently wrong color. See
# https://pi.dev/docs/latest/themes.
{
  lib,
  # Theme name as pi will list it in `/settings`; also the filename stem.
  name,
  # nebelung.palettes.<variant> — a `name -> "#rrggbb"` attrset.
  palette,
  # A palette KEY (haus.theme.accent), not a hex — "pink", "mauve", …
  accent,
}:

let
  p = palette;
  acc = p.${accent};

  # ---- hex arithmetic ----
  # pi's background tokens want tints that no palette member provides: a green
  # wash for a succeeded tool box, a red one for a failed box, an accent wash
  # behind my own messages. Catppuccin-family palettes have no such colors, so
  # they get mixed here. Nix has no hex parser, hence the two conversions.
  digitOf =
    c:
    let
      n = lib.strings.charToInt c;
    in
    if n >= 48 && n <= 57 then n - 48 else n - 87; # '0'-'9' | 'a'-'f'

  byteAt = s: i: (digitOf (lib.substring i 1 s)) * 16 + digitOf (lib.substring (i + 1) 1 s);

  rgbOf =
    h:
    let
      s = lib.toLower (lib.removePrefix "#" h);
    in
    {
      r = byteAt s 0;
      g = byteAt s 2;
      b = byteAt s 4;
    };

  hexByte =
    n:
    let
      d = i: lib.substring i 1 "0123456789abcdef";
    in
    "${d (n / 16)}${d (lib.mod n 16)}";

  # `pct` percent of `fg` over `bg`. Integer division truncates, which is a
  # sub-one-step error on a 0-255 channel and invisible at these percentages.
  mix =
    fg: bg: pct:
    let
      a = rgbOf fg;
      b = rgbOf bg;
      chan = x: y: (x * pct + y * (100 - pct)) / 100;
    in
    "#${hexByte (chan a.r b.r)}${hexByte (chan a.g b.g)}${hexByte (chan a.b b.b)}";

  wash = c: pct: mix c p.base pct;
in

{
  "$schema" =
    "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
  inherit name;

  colors = {
    # ---- core UI ----
    # `border` is the ordinary box outline; the EDITOR's border is the thinking
    # ramp at the bottom of this list, so these two never fight for the eye.
    accent = acc;
    border = p.surface2;
    borderAccent = acc;
    borderMuted = p.surface0;
    success = p.green;
    error = p.red;
    warning = p.yellow;
    muted = p.subtext0;
    dim = p.overlay0;
    text = p.text;
    thinkingText = p.overlay1;

    # ---- backgrounds ----
    # Tool boxes read by wash, not by border: pending stays neutral so only the
    # two outcomes carry hue, which is what makes a failed call findable in a
    # long scrollback.
    selectedBg = p.surface0;
    scrollbarThumb = p.surface2;
    searchMatchBg = wash p.yellow 22;
    searchMatchText = p.text;
    userMessageBg = wash acc 14;
    userMessageText = p.text;
    customMessageBg = wash p.mauve 14;
    customMessageText = p.text;
    customMessageLabel = p.mauve;
    toolPendingBg = wash p.overlay0 12;
    toolSuccessBg = wash p.green 12;
    toolErrorBg = wash p.red 12;
    toolTitle = p.sapphire;
    toolOutput = p.subtext0;

    # ---- markdown ----
    mdHeading = acc;
    mdLink = p.blue;
    mdLinkUrl = p.overlay1;
    mdCode = p.peach;
    mdCodeBlock = p.text;
    mdCodeBlockBorder = p.surface1;
    mdQuote = p.subtext0;
    mdQuoteBorder = p.surface2;
    mdHr = p.surface1;
    mdListBullet = acc;

    # ---- diffs ----
    toolDiffAdded = p.green;
    toolDiffRemoved = p.red;
    toolDiffContext = p.overlay1;

    # ---- syntax ----
    # Catppuccin's own style guide, which is what nebelung's helix/bat ports
    # follow — so a diff pi prints and the same file open in `hx` agree.
    syntaxComment = p.overlay1;
    syntaxKeyword = p.mauve;
    syntaxFunction = p.blue;
    syntaxVariable = p.text;
    syntaxString = p.green;
    syntaxNumber = p.peach;
    syntaxType = p.yellow;
    syntaxOperator = p.sky;
    syntaxPunctuation = p.overlay2;

    # ---- thinking level (the editor's own border) ----
    # A deliberate ramp — grey, then cool, then warm, then alarm — so the
    # current reasoning level is readable without looking at the status line.
    # With `haus.theme.accent = "pink"` the accent lands on xhigh by itself; no
    # special-casing, because the ramp is the palette's, not the accent's.
    thinkingOff = p.surface2;
    thinkingMinimal = p.overlay1;
    thinkingLow = p.blue;
    thinkingMedium = p.lavender;
    thinkingHigh = p.mauve;
    thinkingXhigh = p.pink;
    thinkingMax = p.red;

    # `!`-prefixed bash mode. Peach because it is the one palette entry no other
    # token above claims, so "the editor turned orange" means exactly one thing.
    bashMode = p.peach;
  };

  # `/export`'s standalone HTML. Left out, pi derives these from userMessageBg
  # and the page ends up accent-tinted rather than neutral.
  export = {
    pageBg = p.crust;
    cardBg = p.mantle;
    infoBg = wash p.yellow 18;
  };
}
