LOG_DIR=logs
.PHONY: run test tree

run:
	zsh ./src/shell.sh
test:
	chmod +x ./test/*.sh
	@echo "Running all unit tests..."
	@bash ./test/run_tests.sh
	@if [ $$? -eq 0 ]; then \
		echo "All tests passed!"; \
	else \
		echo "Some tests failed."; exit 1; \
	fi
tree:
	mkdir -p $(LOG_DIR)
	tree -I ".gradle|.idea|build|logs|.vscode|.git|.github" > ./$(LOG_DIR)/shell_source_oss.txt
