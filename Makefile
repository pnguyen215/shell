# Developer tasks. `make` or `make help` lists them.
.DEFAULT_GOAL := help
.PHONY: help check test test-fn test-list lint fmt docs doctor tree clean

# bash is required (the recipes use bash features). Works with GNU make 3.81 (macOS).
SHELL := /bin/bash

# Print an install hint and fail when a tool is missing: $(call need,<tool>,<hint>)
define need
command -v $(1) >/dev/null 2>&1 || { echo "ERROR: '$(1)' is not installed. $(2)" >&2; exit 1; }
endef

help: ## Show this help
	@grep -E '^[a-z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

check: lint test ## Run lint and test (what CI runs)

test: ## Run the tests (all; or narrow: make test T=squash, T=test_git_amend.sh)
	@bash test/run_tests.sh $(T)

test-fn: ## Run only the test files that mention a function: make test-fn F=shell::git::commit::squash
	@test -n "$(F)" || { echo "usage: make test-fn F=<function>" >&2; exit 2; }
	@bash test/run_tests.sh -f "$(F)"

test-list: ## List the test files (same filters: make test-list T=git, F=<function>)
	@bash test/run_tests.sh -l $(if $(F),-f "$(F)") $(T)

lint: ## Naming, shdoc, portability, shellcheck and shfmt checks
	@bash scripts/lint.sh

fmt: ## Format every shell file with shfmt (tabs)
	@$(call need,shfmt,Install it: brew install shfmt  |  sudo apt install shfmt)
	@shfmt -w $$(find src test scripts -name '*.sh') install.sh upgrade.sh uninstall.sh
	@echo "Formatted."

docs: ## Regenerate docs/api from the shdoc comments
	@$(call need,gawk,shdoc needs GNU awk. Install it: brew install gawk  |  sudo apt install gawk)
	@$(call need,shdoc,Install it: brew install shdoc  |  git clone https://github.com/reconquest/shdoc && sudo make -C shdoc install)
	@bash scripts/gen_docs.sh

doctor: ## Report which dependencies are installed
	@bash -c 'SHELL_AUTO_INSTALL_DEPS=0 source src/shell.sh && shell::dependency::doctor'

tree: ## Print the project layout
	@$(call need,tree,Install it: brew install tree  |  sudo apt install tree)
	@tree -a -I '.git|node_modules|logs|.gradle|.idea|build|logs|.vscode|.git|.github|v1' --dirsfirst

clean: ## Remove generated files (docs/api, logs)
	@rm -rf logs
	@echo "Cleaned."
