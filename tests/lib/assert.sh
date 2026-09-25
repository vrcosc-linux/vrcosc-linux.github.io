#!/usr/bin/env bash
# Minimal assertion helpers. Deliberately dependency-free: the thing under test
# is a single portable shell script, so the tests stay portable shell too.

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_TEST=""

# Repository root, regardless of where a test is invoked from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT
INSTALL_SH="$REPO_ROOT/install.sh"
export INSTALL_SH
FIXTURES="$REPO_ROOT/tests/fixtures"
export FIXTURES

_pass() { printf '  \033[0;32mPASS\033[0m %s\n' "$1"; }
_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  \033[0;31mFAIL\033[0m %s\n' "$1"
    shift
    local line
    for line in "$@"; do
        printf '         %s\n' "$line"
    done
}

it() {
    CURRENT_TEST="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
}

assert_eq() {
    local expected="$1" actual="$2" what="${3:-$CURRENT_TEST}"
    if [ "$expected" = "$actual" ]; then
        _pass "$what"
    else
        _fail "$what" "expected: [$expected]" "actual:   [$actual]"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" what="${3:-$CURRENT_TEST}"
    if [[ "$haystack" == *"$needle"* ]]; then
        _pass "$what"
    else
        _fail "$what" "expected output to contain: [$needle]" \
                      "got: $(printf '%s' "$haystack" | head -c 400)"
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" what="${3:-$CURRENT_TEST}"
    if [[ "$haystack" != *"$needle"* ]]; then
        _pass "$what"
    else
        _fail "$what" "expected output NOT to contain: [$needle]"
    fi
}

assert_ok() {
    local what="${2:-$CURRENT_TEST}"
    if [ "$1" -eq 0 ]; then _pass "$what"; else _fail "$what" "expected exit 0, got $1"; fi
}

assert_fails() {
    local what="${2:-$CURRENT_TEST}"
    if [ "$1" -ne 0 ]; then _pass "$what"; else _fail "$what" "expected non-zero exit, got 0"; fi
}

assert_file_exists() {
    local path="$1" what="${2:-$CURRENT_TEST}"
    if [ -e "$path" ]; then _pass "$what"; else _fail "$what" "missing path: $path"; fi
}

# Sources install.sh without running main(), so single functions can be called.
load_install_sh() {
    export VRCOSC_INSTALL_SH_SOURCED=1
    # shellcheck source=/dev/null
    source "$INSTALL_SH"
    trap - ERR
    set +e
}

summarise() {
    echo ""
    if [ "$TESTS_FAILED" -eq 0 ]; then
        printf '\033[0;32m%s: %d/%d passed\033[0m\n' "$(basename "$0")" "$TESTS_RUN" "$TESTS_RUN"
        exit 0
    fi
    printf '\033[0;31m%s: %d/%d failed\033[0m\n' "$(basename "$0")" "$TESTS_FAILED" "$TESTS_RUN"
    exit 1
}
