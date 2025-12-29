# Makefile for mdbook documentation management

.PHONY: help build serve install clean summary summary-simple validate

# Default target
help:
	@echo "Available targets:"
	@echo "  build         - Build the mdbook documentation"
	@echo "  serve         - Serve documentation locally (http://localhost:3000)"
	@echo "  install       - Install required tools"
	@echo "  summary       - Generate structured SUMMARY.md"
	@echo "  summary-simple- Generate simple SUMMARY.md"
	@echo "  validate      - Validate markdown links and formatting"
	@echo "  clean         - Clean build artifacts"

# Install required tools
install:
	@echo "Installing mdbook..."
	@if ! command -v mdbook &> /dev/null; then \
		curl -L https://github.com/rust-lang/mdBook/releases/download/v0.4.21/mdbook-v0.4.21-x86_64-apple-darwin.tar.gz | tar xz -C /usr/local/bin; \
	fi
	@echo "Installing mdbook-auto-summary..."
	@if ! command -v mdbook-auto-summary &> /dev/null; then \
		cargo install mdbook-auto-summary; \
	fi
	@echo "Installing markdown-link-check..."
	@if ! command -v markdown-link-check &> /dev/null; then \
		npm install -g markdown-link-check; \
	fi

# Build documentation
build:
	@echo "Building mdbook..."
	mdbook build

# Serve documentation locally
serve:
	@echo "Starting mdbook server on http://localhost:3000..."
	mdbook serve --hostname 0.0.0.0 --port 3000

# Generate structured SUMMARY.md
summary:
	@echo "Generating structured SUMMARY.md..."
	python3 generate_summary.py

# Generate simple SUMMARY.md
summary-simple:
	@echo "Generating simple SUMMARY.md..."
	python3 generate_summary.py

# Validate markdown links and formatting
validate:
	@echo "Validating markdown links..."
	@if command -v markdown-link-check &> /dev/null; then \
		markdown-link-check **/*.md; \
	else \
		echo "markdown-link-check not found. Install with: npm install -g markdown-link-check"; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf book/
	rm -f SUMMARY.md.bak

# Full rebuild workflow
rebuild: clean summary build
	@echo "Documentation rebuilt successfully!"

# Watch for changes and auto-rebuild (requires inotify-tools)
watch:
	@echo "Watching for changes (requires inotify-tools)..."
	@while inotifywait -e modify -r **/*.md; do \
		echo "Changes detected, rebuilding..."; \
		make build; \
	done