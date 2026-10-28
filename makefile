include tools.mk

# Every tool runs in its own container: no network, no capabilities, as the caller's user. Checks
# see the repository read-only; only the whitespace and end-of-file fixers may write to it.
SANDBOX := docker run --rm --network none --read-only --tmpfs /tmp --cap-drop ALL \
	--security-opt no-new-privileges --user $(shell id -u):$(shell id -g) --env HOME=/tmp --workdir /src
CHECK := $(SANDBOX) --volume "$(CURDIR):/src:ro"
FIX := $(SANDBOX) --volume "$(CURDIR):/src"

TEXT := $(shell git grep -I --name-only -e '')
YAML := $(filter %.yml %.yaml,$(TEXT))
MARKDOWN := $(filter-out CHANGELOG.md,$(filter %.md,$(TEXT)))
RENOVATE := $(filter renovate.json renovate/%.json,$(TEXT))

.PHONY: lint test hooks files actions secrets renovate markdown

lint: files actions secrets renovate markdown

files:
	$(CHECK) $(PRE_COMMIT_HOOKS) check-merge-conflict $(TEXT)
	$(CHECK) $(PRE_COMMIT_HOOKS) check-yaml $(YAML)
	$(FIX) $(PRE_COMMIT_HOOKS) end-of-file-fixer $(TEXT)
	$(FIX) $(PRE_COMMIT_HOOKS) trailing-whitespace-fixer $(TEXT)

actions:
	$(CHECK) $(ACTIONLINT)
	$(CHECK) $(ZIZMOR) .

secrets:
	$(CHECK) $(GITLEAKS) dir --redact --no-banner .

renovate:
	$(CHECK) $(RENOVATE_CONFIG_VALIDATOR) --strict $(RENOVATE)

markdown:
	$(CHECK) $(MARKDOWNLINT) $(MARKDOWN)

test:
	tests/select-test.sh

# Runs make lint before every push.
hooks:
	git config core.hooksPath .githooks
