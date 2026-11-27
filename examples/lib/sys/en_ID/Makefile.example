# Makefile - Install en_ID locale
# Follows BCS1212, except that 'all' compiles to build/ (it never touches the system)

PREFIX    ?= /usr
LOCALEDIR ?= $(PREFIX)/share/i18n/locales
CHARMAP   ?= UTF-8
DESTDIR   ?=

# Directory of this Makefile (trailing slash). Anchors source paths so that
# make behaves the same from any working directory.
srcdir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: all install install-persistent uninstall check test test-installed compile clean info help

all: compile

install:
	install -d $(DESTDIR)$(LOCALEDIR)
	install -m 644 $(srcdir)localedata/en_ID $(DESTDIR)$(LOCALEDIR)/en_ID
	@if [ -z "$(DESTDIR)" ]; then \
	  localedef --charmap=$(CHARMAP) --inputfile=$(LOCALEDIR)/en_ID en_ID.$(CHARMAP); \
	  $(MAKE) --no-print-directory -f $(srcdir)Makefile check; \
	fi

# Regeneration after package updates reads sources from the system directory
# only, so refuse any other LOCALEDIR before installing anything.
install-persistent:
	@[ '$(LOCALEDIR)' = /usr/share/i18n/locales ] || { echo 'install-persistent needs LOCALEDIR=/usr/share/i18n/locales' >&2; exit 22; }
	@$(MAKE) --no-print-directory -f $(srcdir)Makefile install
	@$(srcdir)ensure-persistence.sh

uninstall:
	rm -f $(DESTDIR)$(LOCALEDIR)/en_ID
	@if [ -z "$(DESTDIR)" ]; then $(srcdir)uninstall.sh; fi

check:
	@if locale -a 2>/dev/null | grep -q en_ID; then \
	  echo 'en_ID: OK'; \
	else \
	  echo 'en_ID: NOT FOUND (run "locale -a" to verify)' >&2; \
	  exit 1; \
	fi

test: compile
	$(srcdir)tests/test_en_ID.sh
	$(srcdir)tests/test_scripts.sh

test-installed:
	EN_ID_TEST_INSTALLED=1 $(srcdir)tests/test_en_ID.sh

compile:
	mkdir -p $(srcdir)build
	localedef -f $(CHARMAP) -i $(srcdir)localedata/en_ID $(srcdir)build/en_ID.$(CHARMAP)

clean:
	rm -rf $(srcdir)build

info:
	@echo 'en_ID locale information:'
	@grep -E '^(title|language|territory|revision|date)[[:space:]]' $(srcdir)localedata/en_ID
	@echo 'charmap: $(CHARMAP)'

help:
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@echo '  (default)            Compile locale to build directory'
	@echo '  compile              Compile locale to build directory'
	@echo '  install              Install locale system-wide'
	@echo '  install-persistent   Install + persistence across system updates'
	@echo '  uninstall            Remove the locale and revert the system default'
	@echo '  check                Verify locale is available'
	@echo '  test                 Test the build, then the scripts'
	@echo '  test-installed       Test the locale installed on this system'
	@echo '  info                 Display locale information'
	@echo '  clean                Remove build artifacts'
	@echo '  help                 Show this message'
	@echo ''
	@echo 'Install from GitHub:'
	@echo '  git clone https://github.com/Open-Technology-Foundation/en_ID.git'
	@echo '  cd en_ID && sudo make install'
