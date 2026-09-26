# Builds install.sh from the Amber sources under src/, the test fixtures under
# tests/fixtures/, and runs the test suite. Requires the Amber compiler:
# https://amber-lang.com (the version this project is built with is below).
#
#   make            build install.sh and the fixtures
#   make test       everything above, then the Tier 1 suite
#   make check      fail if install.sh is not what the sources compile to
#   make matrix     Tier 2: the suite inside throwaway containers (see tests/README.md)

AMBER ?= amber
AMBER_VERSION := 0.6.0-alpha

# The optimizer in this Amber release drops a function's assignments to a global
# when the same global is later assigned unconditionally at top level (it reads
# the function body as a dead redeclaration). tests/README.md has the two-line
# reproduction. Every build here runs with it off, which costs a few redundant
# temporaries in the output and nothing else.
export AMBER_NO_OPTIMIZE := 1

SRC := $(wildcard src/*.ab)
FIXTURE_SRC := $(wildcard tests/fixtures/*.ab)
FIXTURE_BIN := $(patsubst tests/fixtures/%.ab,tests/fixtures/bin/%,$(FIXTURE_SRC))
TEST_SRC := $(wildcard tests/unit/*.ab tests/lib/*.ab)

.PHONY: all build fixtures test check matrix clean amber-version

all: build fixtures

build: install.sh

install.sh: $(SRC)
	$(AMBER) build src/main.ab install.sh

fixtures: $(FIXTURE_BIN)

tests/fixtures/bin/%: tests/fixtures/%.ab $(SRC)
	@mkdir -p tests/fixtures/bin
	$(AMBER) build $< $@

# Tier 1: offline, against fakes. Run from the repository root, which is where
# the tests look for src/, install.sh and tests/fixtures/bin/.
test: build fixtures
	$(AMBER) test tests/unit $(if $(TEST_CASE),--test-case "$(TEST_CASE)")

# The committed install.sh is what people download, so it has to be exactly what
# the sources say. Rebuilds to a scratch file and compares.
check: fixtures
	@tmp="$$(mktemp)"; \
	$(AMBER) build src/main.ab "$$tmp" && \
	if cmp -s "$$tmp" install.sh; then \
	    echo "install.sh is up to date"; rm -f "$$tmp"; \
	else \
	    echo "install.sh is out of date: run 'make' and commit the result" >&2; \
	    diff -u install.sh "$$tmp" | head -n 40 >&2; rm -f "$$tmp"; exit 1; \
	fi
	@for t in $(TEST_SRC) $(FIXTURE_SRC); do $(AMBER) check "$$t" >/dev/null || exit 1; done
	@echo "all Amber sources type-check"

matrix: fixtures
	$(AMBER) run tests/matrix.ab -- $(MATRIX_ARGS)

amber-version:
	@echo $(AMBER_VERSION)

clean:
	rm -rf tests/fixtures/bin
