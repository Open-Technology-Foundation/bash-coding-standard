# Makefile for bash loadable builtins
# Optimized version with automatic header detection

# Compiler and flags
CC := gcc
CFLAGS := -fPIC -Wall -Wextra -O2
LDFLAGS := -shared

# Automatically detect bash headers location
BASH_HEADERS := $(shell \
	if [ -f /usr/lib/bash/loadables.h ]; then \
		echo /usr/lib/bash; \
	elif [ -f /usr/include/bash/loadables.h ]; then \
		echo /usr/include/bash; \
	elif [ -f /usr/local/lib/bash/loadables.h ]; then \
		echo /usr/local/lib/bash; \
	else \
		echo "ERROR: Cannot find loadables.h"; \
	fi \
)

# Include paths for bash headers (both loadables and builtins)
INCLUDES := -I$(BASH_HEADERS) -I/usr/include/bash -I/usr/include/bash/include -I/usr/include/bash/builtins

# Installation paths
PREFIX := /usr/local
BUILTIN_DIR := $(PREFIX)/lib/bash-builtins
PROFILE_DIR := /etc/profile.d
USER_PROFILE_DIR := $(HOME)/.config/bash-builtins

# Source and object files
SRC_DIR := src
SOURCES := $(wildcard $(SRC_DIR)/*.c)
BUILTINS := $(patsubst $(SRC_DIR)/%.c,%.so,$(SOURCES))

# Colors for output
COLOR_RESET := \033[0m
COLOR_GREEN := \033[0;32m
COLOR_YELLOW := \033[0;33m
COLOR_BLUE := \033[0;34m

.PHONY: all check-headers clean install install-system install-user uninstall uninstall-system uninstall-user test help enable-all

# Default target
all: check-headers $(BUILTINS)
	@echo "$(COLOR_GREEN)✓ All builtins compiled successfully$(COLOR_RESET)"
	@echo "$(COLOR_BLUE)Built:$(COLOR_RESET) $(BUILTINS)"
	@echo ""
	@echo "$(COLOR_YELLOW)Next steps:$(COLOR_RESET)"
	@echo "  sudo make install         - Install system-wide"
	@echo "  make install-user         - Install for current user only"
	@echo "  make test                 - Run test suite"

# Check for bash headers
check-headers:
	@if [ "$(BASH_HEADERS)" = "ERROR: Cannot find loadables.h" ]; then \
		echo "$(COLOR_YELLOW)Error: Cannot find bash loadables.h$(COLOR_RESET)"; \
		echo ""; \
		echo "Please install bash-builtins package:"; \
		echo "  Debian/Ubuntu: sudo apt-get install bash-builtins"; \
		echo "  RedHat/Fedora: sudo dnf install bash-devel"; \
		exit 1; \
	fi
	@echo "$(COLOR_GREEN)✓ Found bash headers at: $(BASH_HEADERS)$(COLOR_RESET)"

# Compile .so files from .c files
%.so: $(SRC_DIR)/%.c
	@echo "$(COLOR_BLUE)Compiling $<...$(COLOR_RESET)"
	@$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) -o $@ $<
	@echo "$(COLOR_GREEN)✓ Created $@$(COLOR_RESET)"

# Clean build artifacts
clean:
	@echo "$(COLOR_YELLOW)Cleaning build artifacts...$(COLOR_RESET)"
	@rm -f $(BUILTINS)
	@echo "$(COLOR_GREEN)✓ Clean complete$(COLOR_RESET)"

# System-wide installation (requires root)
install: install-system

install-system: $(BUILTINS)
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "$(COLOR_YELLOW)Error: System-wide installation requires root privileges$(COLOR_RESET)"; \
		echo "Run: sudo make install"; \
		exit 1; \
	fi
	@echo "$(COLOR_BLUE)Installing builtins system-wide...$(COLOR_RESET)"
	install -d $(BUILTIN_DIR)
	install -m 0755 $(BUILTINS) $(BUILTIN_DIR)/
	@echo "$(COLOR_GREEN)✓ Builtins installed to $(BUILTIN_DIR)$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)Installing auto-loader...$(COLOR_RESET)"
	install -d $(PROFILE_DIR)
	install -m 0644 bash-builtins-loader.sh $(PROFILE_DIR)/bash-builtins.sh
	@echo "$(COLOR_GREEN)✓ Auto-loader installed to $(PROFILE_DIR)/bash-builtins.sh$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_GREEN)✓ Installation complete!$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)The builtins will be automatically loaded in new bash sessions.$(COLOR_RESET)"
	@echo "To enable in current session, run:"
	@echo "  source $(PROFILE_DIR)/bash-builtins.sh"
	@echo ""
	@echo "Or use: make enable-all"

# User installation (no root required)
install-user: $(BUILTINS)
	@echo "$(COLOR_BLUE)Installing builtins for current user...$(COLOR_RESET)"
	install -d $(USER_PROFILE_DIR)
	install -m 0755 $(BUILTINS) $(USER_PROFILE_DIR)/
	@echo "$(COLOR_GREEN)✓ Builtins installed to $(USER_PROFILE_DIR)$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)Installing auto-loader...$(COLOR_RESET)"
	@if ! grep -q 'bash-builtins-loader' $(HOME)/.bashrc 2>/dev/null; then \
		echo "" >> $(HOME)/.bashrc; \
		echo "# Load bash loadable builtins" >> $(HOME)/.bashrc; \
		echo "if [ -f $(USER_PROFILE_DIR)/bash-builtins-loader.sh ]; then" >> $(HOME)/.bashrc; \
		echo "    source $(USER_PROFILE_DIR)/bash-builtins-loader.sh $(USER_PROFILE_DIR)" >> $(HOME)/.bashrc; \
		echo "fi" >> $(HOME)/.bashrc; \
		echo "$(COLOR_GREEN)✓ Auto-loader added to ~/.bashrc$(COLOR_RESET)"; \
	else \
		echo "$(COLOR_YELLOW)⚠ Auto-loader already present in ~/.bashrc$(COLOR_RESET)"; \
	fi
	install -m 0644 bash-builtins-loader.sh $(USER_PROFILE_DIR)/
	@echo "$(COLOR_GREEN)✓ Installation complete!$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)The builtins will be automatically loaded in new bash sessions.$(COLOR_RESET)"
	@echo "To enable in current session, run:"
	@echo "  source $(USER_PROFILE_DIR)/bash-builtins-loader.sh $(USER_PROFILE_DIR)"
	@echo ""
	@echo "Or use: make enable-all"

# Uninstall system-wide
uninstall: uninstall-system

uninstall-system:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "$(COLOR_YELLOW)Error: System-wide uninstallation requires root privileges$(COLOR_RESET)"; \
		echo "Run: sudo make uninstall"; \
		exit 1; \
	fi
	@echo "$(COLOR_YELLOW)Uninstalling system-wide builtins...$(COLOR_RESET)"
	@rm -f $(PROFILE_DIR)/bash-builtins.sh
	@rm -rf $(BUILTIN_DIR)
	@echo "$(COLOR_GREEN)✓ System-wide installation removed$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)Note: Currently loaded builtins in active sessions are still enabled.$(COLOR_RESET)"
	@echo "Start a new bash session for changes to take effect."

# Uninstall user installation
uninstall-user:
	@echo "$(COLOR_YELLOW)Uninstalling user builtins...$(COLOR_RESET)"
	@rm -rf $(USER_PROFILE_DIR)
	@if grep -q 'bash-builtins-loader' $(HOME)/.bashrc 2>/dev/null; then \
		sed -i '/# Load bash loadable builtins/,+4d' $(HOME)/.bashrc; \
		echo "$(COLOR_GREEN)✓ Removed auto-loader from ~/.bashrc$(COLOR_RESET)"; \
	fi
	@echo "$(COLOR_GREEN)✓ User installation removed$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_YELLOW)Note: Currently loaded builtins in active sessions are still enabled.$(COLOR_RESET)"
	@echo "Start a new bash session for changes to take effect."

# Enable builtins in current shell
enable-all:
	@echo "$(COLOR_BLUE)Enabling builtins in current shell...$(COLOR_RESET)"
	@if [ -f $(PROFILE_DIR)/bash-builtins.sh ]; then \
		echo "source $(PROFILE_DIR)/bash-builtins.sh"; \
		echo "$(COLOR_GREEN)✓ Run the above command to enable builtins$(COLOR_RESET)"; \
	elif [ -f $(USER_PROFILE_DIR)/bash-builtins-loader.sh ]; then \
		echo "source $(USER_PROFILE_DIR)/bash-builtins-loader.sh $(USER_PROFILE_DIR)"; \
		echo "$(COLOR_GREEN)✓ Run the above command to enable builtins$(COLOR_RESET)"; \
	else \
		echo "$(COLOR_YELLOW)Error: No installation found$(COLOR_RESET)"; \
		echo "Run 'make install' or 'make install-user' first"; \
	fi

# Run test suite
test: $(BUILTINS)
	@echo "$(COLOR_BLUE)Running test suite...$(COLOR_RESET)"
	@bash test/test-builtins.sh
	@echo "$(COLOR_GREEN)✓ All tests passed!$(COLOR_RESET)"

# Help target
help:
	@echo "Bash Loadable Builtins - Makefile targets"
	@echo ""
	@echo "Build targets:"
	@echo "  make               - Compile all builtins"
	@echo "  make clean         - Remove compiled builtins"
	@echo ""
	@echo "Installation targets:"
	@echo "  make install       - Install system-wide (requires sudo)"
	@echo "  make install-user  - Install for current user only"
	@echo ""
	@echo "Uninstallation targets:"
	@echo "  make uninstall       - Uninstall system-wide (requires sudo)"
	@echo "  make uninstall-user  - Uninstall user installation"
	@echo ""
	@echo "Testing:"
	@echo "  make test          - Run test suite"
	@echo "  make enable-all    - Show command to enable in current shell"
	@echo ""
	@echo "Configuration:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  BUILTIN_DIR=$(BUILTIN_DIR)"
	@echo "  BASH_HEADERS=$(BASH_HEADERS)"

# Individual targets for convenience
basename.so: src/basename.c
dirname.so: src/dirname.c
realpath.so: src/realpath.c
head.so: src/head.c
cut.so: src/cut.c
