include tools.mk

# Every tool runs in its own container: no network, no capabilities, as the caller's user. Checks
# see the repository read-only; only the whitespace and end-of-file fixers may write to it.
SANDBOX := docker run --rm --network none --read-only --tmpfs /tmp --cap-drop ALL \
	--security-opt no-new-privileges --user $(shell id -u):$(shell id -g) --env HOME=/tmp --workdir /src
CHECK := $(SANDBOX) --volume "$(CURDIR):/src:ro"
FIX := $(SANDBOX) --volume "$(CURDIR):/src"

GIT_COMMON_DIR := $(shell git rev-parse --path-format=absolute --git-common-dir)
TEXT := $(shell git grep -I --name-only -e '')
YAML := $(filter %.yml %.yaml,$(TEXT))
MARKDOWN := $(filter-out CHANGELOG.md,$(filter %.md,$(TEXT)))
RENOVATE := $(filter renovate.json renovate/%.json,$(TEXT))
SCRIPTS := $(filter %.sh .githooks/%,$(TEXT))

.PHONY: lint test hooks files actions scripts secrets renovate markdown

lint: files actions scripts secrets renovate markdown

files:
	$(CHECK) --volume "$(GIT_COMMON_DIR):$(GIT_COMMON_DIR):ro" $(PRE_COMMIT_HOOKS) check-merge-conflict $(TEXT)
	$(CHECK) $(PRE_COMMIT_HOOKS) check-yaml $(YAML)
	$(FIX) $(PRE_COMMIT_HOOKS) end-of-file-fixer $(TEXT)
	$(FIX) $(PRE_COMMIT_HOOKS) trailing-whitespace-fixer $(TEXT)

actions:
	$(CHECK) $(ACTIONLINT)
	$(CHECK) $(ZIZMOR) .

# shellcheck ships in the actionlint image.
scripts:
	$(CHECK) --entrypoint /usr/local/bin/shellcheck $(ACTIONLINT) $(SCRIPTS)

secrets:
	$(CHECK) $(GITLEAKS) dir --redact --no-banner .

renovate:
	$(CHECK) $(RENOVATE_CONFIG_VALIDATOR) --strict --no-global $(RENOVATE)

markdown:
	$(CHECK) $(MARKDOWNLINT) $(MARKDOWN)

test:
	set -e; for test in tests/*-test.sh; do $$test; done

# Runs make lint before every push.
hooks:
	git config core.hooksPath .githooks
