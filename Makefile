# Makefile for bash-coding-standard installation
# Usage:
#   sudo make install                  # Install to /usr/local
#   sudo make PREFIX=/usr install      # Install to /usr (system-wide)
#   sudo make uninstall                # Uninstall from /usr/local

PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share/yatti/bash-coding-standard

.PHONY: install uninstall help

help:
	@echo "bash-coding-standard Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  install     Install to $(PREFIX)"
	@echo "  uninstall   Uninstall from $(PREFIX)"
	@echo "  help        Show this help message"
	@echo ""
	@echo "Usage:"
	@echo "  sudo make install                  # Install to /usr/local"
	@echo "  sudo make PREFIX=/usr install      # Install to /usr"
	@echo "  sudo make uninstall                # Uninstall"

install:
	install -d $(BINDIR)
	install -m 755 bash-coding-standard $(BINDIR)/
	ln -sf bash-coding-standard $(BINDIR)/bcs
	install -d $(SHAREDIR)
	install -m 644 BASH-CODING-STANDARD.complete.md $(SHAREDIR)/
	install -m 644 BASH-CODING-STANDARD.summary.md $(SHAREDIR)/
	install -m 644 BASH-CODING-STANDARD.abstract.md $(SHAREDIR)/
	ln -sf BASH-CODING-STANDARD.abstract.md $(SHAREDIR)/BASH-CODING-STANDARD.md
	cp -r data $(SHAREDIR)/
	@if [ -d BCS ]; then \
		cp -r BCS $(SHAREDIR)/ && \
		echo "  - BCS index installed"; \
	else \
		echo "  - BCS index not found (run 'bcs generate --canonical' to create)"; \
	fi
	@echo ""
	@echo "✓ Installed to $(PREFIX)"
	@echo ""
	@echo "Installed files:"
	@echo "  - Executable: $(BINDIR)/bash-coding-standard (and bcs symlink)"
	@echo "  - Standard docs (3 tiers): $(SHAREDIR)/BASH-CODING-STANDARD.*.md"
	@echo "  - Data directory: $(SHAREDIR)/data/ (300+ rule files + templates)"
	@echo "  - BCS index: $(SHAREDIR)/BCS/ (convenience symlinks, if available)"
	@echo ""
	@echo "Run: bash-coding-standard"
	@echo "Help: bash-coding-standard --help"

uninstall:
	rm -f $(BINDIR)/bash-coding-standard
	rm -f $(BINDIR)/bcs
	rm -rf $(SHAREDIR)
	@echo ""
	@echo "✓ Uninstalled from $(PREFIX)"
