#!/usr/bin/env bash
# Argument validation. --branch was the one flag that accepted anything and then
# quietly did something else: only "beta" was special-cased, so a typo installed
# live into a directory named after the typo.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"

it "--branch rejects a value that is neither channel"
out="$(bash "$INSTALL_SH" --branch stable 2>&1)"; rc=$?
assert_fails "$rc"

it "and names what it will accept"
assert_contains "$out" "Use 'live' or 'beta'"

it "and echoes what it was given, so a typo is obvious"
assert_contains "$out" "stable"

it "--branch live is still accepted"
out="$(bash "$INSTALL_SH" --branch live --help 2>&1)"; rc=$?
assert_ok "$rc"

it "--branch beta is still accepted"
out="$(bash "$INSTALL_SH" --branch beta --help 2>&1)"; rc=$?
assert_ok "$rc"

it "--branch with no value still fails"
out="$(bash "$INSTALL_SH" --branch 2>&1)"; rc=$?
assert_fails "$rc"

# --- the installer's own version ----------------------------------------------
# Distinct from the VRCOSC release it installs, and the first thing to ask for in
# a bug report -- so it has to be reachable without a prefix or a network.

it "--version prints a version and exits cleanly"
out="$(bash "$INSTALL_SH" --version 2>&1)"; rc=$?
assert_ok "$rc"

it "and it looks like a version"
assert_contains "$out" "install.sh "
[[ "$out" =~ [0-9]+\.[0-9]+\.[0-9]+ ]] && _pass "matches x.y.z" || _fail "matches x.y.z" "got: $out"
TESTS_RUN=$((TESTS_RUN + 1))

it "-V is the same thing"
assert_eq "$out" "$(bash "$INSTALL_SH" -V 2>&1)"

it "and --help carries it too"
version="$(bash "$INSTALL_SH" --version 2>&1 | awk '{print $NF}')"
assert_contains "$(bash "$INSTALL_SH" --help 2>&1)" "v$version"

it "the git tag, when there is one, matches the script"
# A tag that does not match what --version reports makes every bug report
# ambiguous about which build is being described.
tag="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
if [ -n "$tag" ]; then
    assert_eq "$version" "${tag#v}"
else
    _pass "no tag yet, nothing to match"
fi

summarise
