#!/usr/bin/env bash
# Three flags shipped documented in --help and the README but absent from
# index.html, which is the page people actually land on. The flag list is the
# one piece of documentation that must not drift, so check it mechanically:
# every long option --help advertises has to appear in both documents.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"

# The long option out of each option line, so "-u, --uninstall" yields
# --uninstall and a --runtime value list below it yields nothing.
flags="$(bash "$INSTALL_SH" --help 2>/dev/null \
    | grep -oE '^[[:space:]]+(-[a-zA-Z], )?[-][-][a-z-]+' \
    | grep -oE '[-][-][a-z-]+' | sort -u)"

# Guards the extraction itself: a regex that quietly stopped matching would
# otherwise make the checks below pass by finding nothing to check.
it "--help advertises a plausible number of options"
assert_ge "$(wc -l <<< "$flags")" 10

for doc in README.md index.html; do
    missing=""
    while IFS= read -r flag; do
        [ -n "$flag" ] || continue
        grep -qF -- "$flag" "$REPO_ROOT/$doc" || missing="$missing $flag"
    done <<< "$flags"

    it "every --help flag is documented in $doc"
    assert_eq "" "$missing"
done

summarise
