.PHONY: install install-minimal install-standard install-full install-help

# MyConvergio install tiers (F-28).
INSTALL_MINIMAL_TOOLS := gh git jq sqlite3 claude-core
INSTALL_STANDARD_TOOLS := $(INSTALL_MINIMAL_TOOLS) node npm
INSTALL_FULL_TOOLS := $(INSTALL_STANDARD_TOOLS) cargo rustc shellcheck shfmt

# optional (not hard dependencies): python runtime for dashboard helpers.
INSTALL_OPTIONAL_TOOLS := python3 pip3

install: install-standard

install-minimal:
	@echo "MyConvergio minimal tools: $(INSTALL_MINIMAL_TOOLS)"
	@echo "Optional tools: $(INSTALL_OPTIONAL_TOOLS)"

install-standard:
	@echo "MyConvergio standard tools: $(INSTALL_STANDARD_TOOLS)"
	@echo "Optional tools: $(INSTALL_OPTIONAL_TOOLS)"

install-full:
	@echo "MyConvergio full tools: $(INSTALL_FULL_TOOLS)"
	@echo "Optional tools: $(INSTALL_OPTIONAL_TOOLS)"

install-help:
	@echo "Targets:"
	@echo "  make install          # standard tier"
	@echo "  make install-minimal  # minimal tier"
	@echo "  make install-standard # standard tier"
	@echo "  make install-full     # full tier"
