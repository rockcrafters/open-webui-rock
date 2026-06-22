ROCKS_TEMPLATE_REMOTE ?= https://github.com/canonical/rocks-template

.PHONY: sync-with-template check-setup test-all

## sync-with-template: Pull latest rocks-template changes and merge (ours strategy)
sync-with-template:
	@if ! git diff --quiet || ! git diff --cached --quiet; then \
		echo "ERROR: Working tree is not clean. Commit or stash changes first."; \
		exit 1; \
	fi
	@git remote get-url rocks-template 2>/dev/null || \
		git remote add rocks-template $(ROCKS_TEMPLATE_REMOTE)
	git fetch rocks-template
	git merge --strategy=ours --no-edit rocks-template/main \
		-m "chore: sync with rocks-template"

## check-setup: Verify that rockcraft and lxd are installed
check-setup:
	@command -v rockcraft >/dev/null 2>&1 || \
		{ echo "ERROR: rockcraft not found. Run: sudo snap install rockcraft --classic"; exit 1; }
	@command -v lxd >/dev/null 2>&1 || \
		{ echo "ERROR: lxd not found. Run: sudo snap install lxd"; exit 1; }
	@echo "Setup OK: rockcraft and lxd are available."

## test-all: Run all Spread test suites found in the repo
test-all:
	@set -e; \
	find . -name 'spread.yaml' -not -path './.git/*' | while read -r spread_file; do \
		dir=$$(dirname "$$spread_file"); \
		echo "==> Running spread tests in: $$dir"; \
		( cd "$$dir" && rockcraft test ); \
	done
	@find . -maxdepth 3 -name '.craft-spread*' -exec rm -rf {} + 2>/dev/null || true
	@find . -maxdepth 3 -name '.spread-reuse*' -exec rm -rf {} + 2>/dev/null || true
	@echo "All spread test suites passed."
