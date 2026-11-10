# SPDX-License-Identifier: GPL-3.0-or-later
# Makefile - Install BCS (Bash Coding Standard)
# BCS1212 compliant

PREFIX   ?= /usr/local
BINDIR   ?= $(PREFIX)/bin
MANDIR   ?= $(PREFIX)/share/man/man1
SHAREDIR ?= $(PREFIX)/share/yatti/BCS
SKILLDIR ?= /etc/claude-code/.claude/skills
CMDDIR   ?= /etc/claude-code/.claude/commands
DESTDIR  ?=

# Completions go to the system directory only for a system PREFIX. Any other
# PREFIX (a sandbox, ~/.local) keeps them under itself, where bash-completion
# also looks, so that install and uninstall can never touch the host's /etc.
ifeq ($(filter /usr /usr/local,$(PREFIX)),)
COMPDIR  ?= $(PREFIX)/share/bash-completion/completions
else
COMPDIR  ?= /etc/bash_completion.d
endif

# Directory of this Makefile (trailing slash). Used to anchor all source
# paths so 'make install' works regardless of the invoking CWD and never
# picks up a like-named file from a parent directory.
srcdir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: all install uninstall check test test-fast test-full help \
        install-claude uninstall-claude check-claude

all: help

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(srcdir)bcs $(DESTDIR)$(BINDIR)/bcs
	install -m 755 $(srcdir)bcscheck $(DESTDIR)$(BINDIR)/bcscheck
	install -m 755 $(srcdir)bcsdisplay $(DESTDIR)$(BINDIR)/bcsdisplay
	install -m 755 $(srcdir)bcstemplate $(DESTDIR)$(BINDIR)/bcstemplate
	install -m 755 $(srcdir)bcscodes $(DESTDIR)$(BINDIR)/bcscodes
	install -m 755 $(srcdir)bcsgenerate $(DESTDIR)$(BINDIR)/bcsgenerate
	install -d $(DESTDIR)$(SHAREDIR)
	install -m 644 $(srcdir)LICENSE $(DESTDIR)$(SHAREDIR)/LICENSE
	install -m 644 $(srcdir)COPYING $(DESTDIR)$(SHAREDIR)/COPYING
	install -d $(DESTDIR)$(SHAREDIR)/data
	install -m 644 $(srcdir)data/LICENSE $(DESTDIR)$(SHAREDIR)/data/LICENSE
	install -m 644 $(srcdir)data/BASH-CODING-STANDARD.md $(DESTDIR)$(SHAREDIR)/data/
	# Ship the canonical section files but never a developer's local, gitignored
	# 98-user.md (the reserved user-rules namespace must not leak system-wide).
	find $(srcdir)data -maxdepth 1 -name '[0-9]*.md' ! -name '98-user.md' \
	  -exec install -m 644 {} $(DESTDIR)$(SHAREDIR)/data/ \;
	install -d $(DESTDIR)$(SHAREDIR)/examples/templates
	install -m 644 $(srcdir)examples/templates/*.sh.template $(DESTDIR)$(SHAREDIR)/examples/templates/
	install -d $(DESTDIR)$(SHAREDIR)/docs
	cp -a $(srcdir)docs/. $(DESTDIR)$(SHAREDIR)/docs/
	rm -f $(DESTDIR)$(SHAREDIR)/docs/CLAUDE.md
	rm -rf $(DESTDIR)$(SHAREDIR)/docs/.claude
	rm -rf $(DESTDIR)$(SHAREDIR)/docs/BCS-Bash-Ref/.audit
	rm -f $(DESTDIR)$(SHAREDIR)/docs/BCS-Bash-Ref/CLAUDE.md
	rm -rf $(DESTDIR)$(SHAREDIR)/docs/BCS-Bash-Ref/.claude
	install -d $(DESTDIR)$(SHAREDIR)/benchmarks
	cp -a $(srcdir)benchmarks/. $(DESTDIR)$(SHAREDIR)/benchmarks/
	install -d $(DESTDIR)$(SHAREDIR)/examples
	find $(srcdir)examples/ -maxdepth 1 -type f -exec install -m 755 {} $(DESTDIR)$(SHAREDIR)/examples/ \;
	install -d $(DESTDIR)$(SHAREDIR)/examples/lib
	cd $(srcdir) && tar --exclude='mk-index*' --exclude='BASH-CODING-STANDARD.md' -cf - examples/lib | tar -xf - -C $(DESTDIR)$(SHAREDIR)/
	install -d $(DESTDIR)$(MANDIR)
	install -m 644 $(srcdir)bcs.1 $(DESTDIR)$(MANDIR)/bcs.1
	install -m 644 $(srcdir)docs/BCS-bash.1 $(DESTDIR)$(MANDIR)/BCS-bash.1
	ln -sfn BCS-bash.1 $(DESTDIR)$(MANDIR)/bcs-bash.1
	@# A COMPDIR under PREFIX is ours to create; a system one is only used if present.
	@case "$(COMPDIR)" in "$(PREFIX)"/*) install -d $(DESTDIR)$(COMPDIR) ;; esac
	@if [ -d $(DESTDIR)$(COMPDIR) ]; then \
	  install -m 644 $(srcdir)bcs.bash_completion $(DESTDIR)$(COMPDIR)/bcs; \
	  ln -sfn bcs $(DESTDIR)$(COMPDIR)/bcscheck; \
	  ln -sfn bcs $(DESTDIR)$(COMPDIR)/bcsdisplay; \
	  ln -sfn bcs $(DESTDIR)$(COMPDIR)/bcstemplate; \
	  ln -sfn bcs $(DESTDIR)$(COMPDIR)/bcscodes; \
	  ln -sfn bcs $(DESTDIR)$(COMPDIR)/bcsgenerate; \
	fi
	@if [ -d $(DESTDIR)$(PREFIX)/share/yatti/bash-coding-standard ] \
	    && [ ! -L $(DESTDIR)$(PREFIX)/share/yatti/bash-coding-standard ]; then \
	  rm -rf $(DESTDIR)$(PREFIX)/share/yatti/bash-coding-standard; \
	fi
	@ln -sfn BCS $(DESTDIR)$(PREFIX)/share/yatti/bash-coding-standard 2>/dev/null || true
	@if [ -z "$(DESTDIR)" ]; then $(MAKE) --no-print-directory check; fi

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/bcs
	rm -f $(DESTDIR)$(BINDIR)/bcscheck
	rm -f $(DESTDIR)$(BINDIR)/bcsdisplay
	rm -f $(DESTDIR)$(BINDIR)/bcstemplate
	rm -f $(DESTDIR)$(BINDIR)/bcscodes
	rm -f $(DESTDIR)$(BINDIR)/bcsgenerate
	rm -f $(DESTDIR)$(MANDIR)/bcs.1
	rm -f $(DESTDIR)$(MANDIR)/BCS-bash.1
	rm -f $(DESTDIR)$(MANDIR)/bcs-bash.1
	rm -f $(DESTDIR)$(COMPDIR)/bcs
	rm -f $(DESTDIR)$(COMPDIR)/bcscheck
	rm -f $(DESTDIR)$(COMPDIR)/bcsdisplay
	rm -f $(DESTDIR)$(COMPDIR)/bcstemplate
	rm -f $(DESTDIR)$(COMPDIR)/bcscodes
	rm -f $(DESTDIR)$(COMPDIR)/bcsgenerate
	rm -rf $(DESTDIR)$(SHAREDIR)
	rm -f $(DESTDIR)$(PREFIX)/share/yatti/bash-coding-standard

# Enterprise install set, as source:destination pairs (one entry point per
# function). Single source of truth for install-claude/check-claude.
CLAUDE_FILES = \
  skills/bcscheck/SKILL.md:$(SKILLDIR)/bcscheck/SKILL.md \
  ai-agents/commands/audit-bash.md:$(CMDDIR)/audit-bash.md

install-claude:
	@for pair in $(CLAUDE_FILES); do \
	  src=$(srcdir)$${pair%%:*}; dst=$(DESTDIR)$${pair#*:}; \
	  install -d "$${dst%/*}" && install -m 644 "$$src" "$$dst" || exit 1; \
	done
	@echo 'Installed Claude skill (bcscheck) and command (audit-bash)'

# Compare the repo with the deployed copies. A deployed file that differs was
# edited in place: install-claude would silently revert that edit, so port it
# into the repo first. An absent file is reported but is not drift --
# installing it reverts nothing.
check-claude:
	@rc=0; \
	for pair in $(CLAUDE_FILES); do \
	  src=$(srcdir)$${pair%%:*}; dst=$(DESTDIR)$${pair#*:}; \
	  if [ ! -f "$$dst" ]; then echo "$$dst: not installed"; \
	  elif diff -q "$$src" "$$dst" >/dev/null; then echo "$$dst: OK"; \
	  else echo "$$dst: DIFFERS from $$src"; rc=1; fi; \
	done; \
	exit $$rc

# bcs-audit is no longer shipped; releases up to 2.0.9 installed it, so it is
# still removed here.
uninstall-claude:
	rm -rf $(DESTDIR)$(SKILLDIR)/bcscheck $(DESTDIR)$(SKILLDIR)/bcs-audit
	rm -f $(DESTDIR)$(CMDDIR)/bcs-audit.md $(DESTDIR)$(CMDDIR)/audit-bash.md
	@echo 'Removed Claude skills and commands'

check:
	@command -v bcs >/dev/null 2>&1 \
	  && echo 'bcs: OK' \
	  || echo 'bcs: NOT FOUND (check PATH)'
	@command -v bcscheck >/dev/null 2>&1 \
	  && echo 'bcscheck: OK' \
	  || echo 'bcscheck: NOT FOUND (check PATH)'
	@command -v bcsdisplay >/dev/null 2>&1 \
	  && echo 'bcsdisplay: OK' \
	  || echo 'bcsdisplay: NOT FOUND (check PATH)'
	@command -v bcstemplate >/dev/null 2>&1 \
	  && echo 'bcstemplate: OK' \
	  || echo 'bcstemplate: NOT FOUND (check PATH)'
	@command -v bcscodes >/dev/null 2>&1 \
	  && echo 'bcscodes: OK' \
	  || echo 'bcscodes: NOT FOUND (check PATH)'
	@command -v bcsgenerate >/dev/null 2>&1 \
	  && echo 'bcsgenerate: OK' \
	  || echo 'bcsgenerate: NOT FOUND (check PATH)'

# `make test` is the fast, deterministic suite: no LLM, no API keys, a few
# seconds. It is what CI runs on every push.
test: test-fast

test-fast:
	BCS_SKIP_FIXTURES=1 $(srcdir)tests/run-all-tests.sh

# `make test-full` adds the LLM fixture gate (tests/test-check-fixtures.sh).
# It needs a reachable backend and FAILS, rather than skips, without one or
# when any fixture is inconclusive. A few minutes on an API backend; about
# 47 s per fixture on the CLI backend. BCS_SKIP_FIXTURES=0 overrides a skip
# flag exported in the caller's environment.
test-full:
	BCS_SKIP_FIXTURES=0 BCS_FIXTURES_REQUIRE_BACKEND=1 $(srcdir)tests/run-all-tests.sh

help:
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@echo '  install          Install to $(PREFIX)'
	@echo '  install-claude   Install Claude skills+commands to /etc/claude-code'
	@echo '  uninstall-claude Remove installed Claude skills+commands'
	@echo '  check-claude     Diff repo skills+commands against the deployed copies'
	@echo '  uninstall        Remove installed files'
	@echo '  check            Verify installation'
	@echo '  test             Run the fast deterministic suite (alias of test-fast)'
	@echo '  test-fast        Structural + unit suites; no LLM, no API keys (seconds)'
	@echo '  test-full        test-fast + LLM fixture gate (needs a backend; minutes)'
	@echo '  help             Show this message'
	@echo ''
	@echo 'Install from GitHub:'
	@echo '  git clone https://github.com/Open-Technology-Foundation/bash-coding-standard.git'
	@echo '  cd BCS && sudo make install'
