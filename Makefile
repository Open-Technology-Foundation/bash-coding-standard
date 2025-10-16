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
	install -d $(SHAREDIR)
	install -m 644 BASH-CODING-STANDARD.md $(SHAREDIR)/
	@echo ""
	@echo "✓ Installed to $(PREFIX)"
	@echo ""
	@echo "Run: bash-coding-standard"
	@echo "Help: bash-coding-standard --help"

uninstall:
	rm -f $(BINDIR)/bash-coding-standard
	rm -rf $(SHAREDIR)
	@echo ""
	@echo "✓ Uninstalled from $(PREFIX)"
