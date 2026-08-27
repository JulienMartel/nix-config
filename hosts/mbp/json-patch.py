#!/usr/bin/env python3
"""Patch a JSON file this machine does not own, without disturbing the rest.

Four activation steps in `default.nix` need the same shape: a config file that
another program owns and rewrites (trill's `github.json` and `rules.json`,
Claude Code's `settings.json`) has to carry a handful of keys nix declares,
while every key nix did *not* declare survives untouched. Owning the file with
`home.file` would clobber those; hand-editing it would be reverted the moment
the owning program next writes.

The rules this enforces, in every mode:

  * **Atomic.** Write a sibling temp file, compare, `os.replace` only if the
    content actually changed. A rebuild that changes nothing leaves the mtime
    alone, so file watchers (trill watches `rules.json` live) don't churn.
  * **Never blank a file on failure.** Unreadable, unparseable, or a mode that
    raises: leave the original exactly as it is and exit 0. Activation must not
    be the thing that eats a config.
  * **Secrets never touch argv.** `set-env` reads the value from the
    environment, because `ps` shows arguments to every user on the box.

Modes:

  merge FILE JSON        Deep-merge a JSON object. Dicts recurse; every other
                         value (scalars, arrays) replaces wholesale.
  union FILE PATH JSON   Union a JSON array into the array at a dotted PATH,
                         de-duplicated and sorted. Creates the path if absent.
  set-env FILE KEY VAR   Set top-level KEY to the string in environment VAR.
                         No-op if VAR is unset or empty.
  rules FILE VAR         trill's rules merge: the JSON array in environment VAR
                         replaces any existing rule matching the same
                         `.match.source` (case-insensitively) and is appended at
                         the end, so a hand-written rule keeps its priority over
                         the ones declared here.

Exit status is 0 in all of these, including "nothing to do" and "couldn't" —
activation should not fail a rebuild over a config file that will be re-patched
on the next one.
"""

import json
import os
import sys


def deep_merge(base, patch):
    """Recurse into dicts; anything else in `patch` wins outright."""
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], value)
        else:
            base[key] = value
    return base


def mode_merge(doc, args):
    return deep_merge(doc, json.loads(args[0]))


def mode_union(doc, args):
    path, addition = args[0].split("."), json.loads(args[1])
    node = doc
    for part in path[:-1]:
        node = node.setdefault(part, {})
    existing = node.get(path[-1]) or []
    # sorted() over a str-keyed set: these are permission strings, and a stable
    # order keeps the file from churning between rebuilds.
    node[path[-1]] = sorted({*existing, *addition})
    return doc


def mode_set_env(doc, args):
    key, value = args[0], os.environ.get(args[1], "")
    if not value:
        raise ValueError(f"${args[1]} is unset or empty")
    doc[key] = value
    return doc


def mode_rules(doc, args):
    mine = json.loads(os.environ.get(args[0], "[]"))
    names = {(r.get("match", {}).get("source") or "").lower() for r in mine}
    kept = [
        r
        for r in (doc.get("rules") or [])
        if (r.get("match", {}).get("source") or "").lower() not in names
    ]
    doc["rules"] = kept + mine
    return doc


MODES = {
    "merge": mode_merge,
    "union": mode_union,
    "set-env": mode_set_env,
    "rules": mode_rules,
}


def main(argv):
    if len(argv) < 3 or argv[1] not in MODES:
        print(f"usage: {argv[0]} {{{'|'.join(MODES)}}} FILE ...", file=sys.stderr)
        return 2

    mode, path, args = argv[1], argv[2], argv[3:]

    try:
        with open(path) as handle:
            doc = json.load(handle)
        mode_bits = os.stat(path).st_mode & 0o777
    except FileNotFoundError:
        # A file that doesn't exist yet is fine to create — an empty rules file
        # is valid and trill picks it up live. Except for `set-env`: the file it
        # patches (trill's github.json) carries `login` and `port` that only
        # trill writes, so a fresh one holding just the secret would be a
        # half-config that looks whole.
        if mode == "set-env":
            print(f"json-patch: {path} does not exist — nothing to patch",
                  file=sys.stderr)
            return 0
        doc, mode_bits = {}, 0o600 if mode == "set-env" else 0o644
    except (OSError, ValueError) as err:
        print(f"json-patch: leaving {path} alone — {err}", file=sys.stderr)
        return 0

    if not isinstance(doc, dict):
        print(f"json-patch: leaving {path} alone — top level is not an object",
              file=sys.stderr)
        return 0

    try:
        doc = MODES[mode](doc, args)
    except (ValueError, KeyError, IndexError, TypeError) as err:
        print(f"json-patch: leaving {path} alone — {err}", file=sys.stderr)
        return 0

    rendered = json.dumps(doc, indent=2) + "\n"
    try:
        with open(path) as handle:
            if handle.read() == rendered:
                return 0
    except OSError:
        pass

    tmp = f"{path}.hm-seed"
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    try:
        # The temp file is born 0600 so a secret is never briefly world-readable,
        # then takes the original's mode — os.replace keeps the source's, so a
        # patch must not be the thing that silently loosens or tightens a file.
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as handle:
            handle.write(rendered)
        os.chmod(tmp, mode_bits)
        os.replace(tmp, path)
    except OSError as err:
        print(f"json-patch: could not write {path} — {err}", file=sys.stderr)
        try:
            os.unlink(tmp)
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
