# Makefile for managing Shell project tasks such as running, building, testing, and maintaining dependencies.
.PHONY: run test tree

LOG_DIR  := logs

# ==============================================================================
# Running the main application
# Executes the bash file, useful for development and quick testing
# ==============================================================================
run:
	zsh ./src/shell.sh

# ==============================================================================
# Module support and testing
# Runs tests across all packages in the project, showing code coverage
# ==============================================================================
test:
	chmod +x ./test/*.sh
	@echo "Running all unit tests..."
	@bash ./test/run_tests.sh
	@if [ $$? -eq 0 ]; then \
		echo "All tests passed!"; \
	else \
		echo "Some tests failed."; exit 1; \
	fi

# ==============================================================================
# Generating project file tree
# Creates a text file representing the project's directory structure, excluding certain directories
# ==============================================================================
tree:
	@mkdir -p $(LOG_DIR)
	tree -I ".gradle|.idea|build|logs|.vscode|.git|.github" > ./$(LOG_DIR)/shell_structure.txt
