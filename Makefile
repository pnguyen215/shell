.PHONY: run test

# ==============================================================================
# Start Main
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
