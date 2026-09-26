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

summarise
