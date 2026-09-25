#!/usr/bin/env bash
# Tier 1: offline tests against fakes. No network, no Steam, no wine, no root.
# Safe to run anywhere, including CI. Usage: tests/run-unit.sh [name-filter]
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
filter="${1:-}"

failed=0
total=0

if command -v shellcheck &>/dev/null; then
    echo "== shellcheck"
    # SC2155 is pervasive pre-existing style in install.sh; SC1091 is the
    # dynamic source of the script under test.
    if shellcheck -S warning -e SC2155,SC1091,SC2034 \
        install.sh tests/lib/*.sh tests/unit/*.sh tests/fixtures/*.sh \
        tests/fixtures/fake-protontricks tests/*.sh; then
        echo "  OK"
    else
        failed=$((failed + 1))
    fi
    total=$((total + 1))
else
    echo "== shellcheck not installed; skipping lint"
fi

for t in tests/unit/test-*.sh; do
    [ -n "$filter" ] && [[ "$t" != *"$filter"* ]] && continue
    echo ""
    echo "== $(basename "$t")"
    total=$((total + 1))
    bash "$t" || failed=$((failed + 1))
done

echo ""
if [ "$failed" -eq 0 ]; then
    printf '\033[0;32mAll %d suites passed\033[0m\n' "$total"
    exit 0
fi
printf '\033[0;31m%d of %d suites failed\033[0m\n' "$failed" "$total"
exit 1
