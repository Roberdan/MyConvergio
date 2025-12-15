# =============================================================================
# MyConvergio Agent Management
# =============================================================================
# Version: 1.0.0
# =============================================================================

.PHONY: install install-local test clean update check-sync version help lint validate

# Directories
AGENTS_SRC := .claude/agents
RULES_SRC := .claude/rules
SKILLS_SRC := .claude/skills
GLOBAL_DEST := $(HOME)/.claude/agents
LOCAL_DEST := .claude/agents

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Default target
.DEFAULT_GOAL := help

help:
	@echo "$(BLUE)MyConvergio Agent Management$(NC)"
	@echo ""
	@echo "$(YELLOW)Installation:$(NC)"
	@echo "  make install        Install agents globally (~/.claude/agents/)"
	@echo "  make install-local  Install agents locally (./.claude/agents/)"
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@echo "  make test           Run agent tests"
	@echo "  make lint           Lint agent YAML frontmatter"
	@echo "  make validate       Validate Constitution compliance"
	@echo ""
	@echo "$(YELLOW)Maintenance:$(NC)"
	@echo "  make clean          Remove installed agents"
	@echo "  make update         Sync agents from ConvergioCLI"
	@echo "  make check-sync     Check for upstream changes in ConvergioCLI"
	@echo "  make version        Show version info"

install:
	@echo "$(BLUE)Installing agents to $(GLOBAL_DEST)...$(NC)"
	@mkdir -p $(GLOBAL_DEST)
	@cp -r $(AGENTS_SRC)/* $(GLOBAL_DEST)/
	@echo "$(GREEN)✅ Installed $$(find $(GLOBAL_DEST) -name '*.md' | wc -l | tr -d ' ') agents$(NC)"

install-local:
	@echo "$(BLUE)Installing agents to $(LOCAL_DEST)...$(NC)"
	@mkdir -p $(LOCAL_DEST)
	@cp -r $(AGENTS_SRC)/* $(LOCAL_DEST)/
	@echo "$(GREEN)✅ Installed $$(find $(LOCAL_DEST) -name '*.md' | wc -l | tr -d ' ') agents$(NC)"

test:
	@echo "$(BLUE)Running agent tests...$(NC)"
	@./scripts/test-deployment.sh

lint:
	@echo "$(BLUE)Linting agent YAML frontmatter...$(NC)"
	@for file in $$(find $(AGENTS_SRC) -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' ! -name 'SECURITY_FRAMEWORK_TEMPLATE.md' ! -name 'MICROSOFT_VALUES.md'); do \
		if ! head -1 "$$file" | grep -q '^---$$'; then \
			echo "$(YELLOW)Warning: $$file missing YAML frontmatter$(NC)"; \
		fi; \
	done
	@echo "$(GREEN)✅ Lint complete$(NC)"

validate:
	@echo "$(BLUE)Validating Constitution compliance...$(NC)"
	@CONSTITUTION="$(AGENTS_SRC)/core_utility/CONSTITUTION.md"; \
	if [ ! -f "$$CONSTITUTION" ]; then \
		echo "$(YELLOW)Warning: CONSTITUTION.md not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ Constitution found$(NC)"
	@echo "$(BLUE)Checking agents for security framework...$(NC)"
	@MISSING=0; \
	for file in $$(find $(AGENTS_SRC) -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md'); do \
		if ! grep -q "Security" "$$file" 2>/dev/null; then \
			echo "$(YELLOW)Missing security section: $$file$(NC)"; \
			MISSING=$$((MISSING + 1)); \
		fi; \
	done; \
	if [ $$MISSING -gt 0 ]; then \
		echo "$(YELLOW)⚠️  $$MISSING agents missing security framework$(NC)"; \
	else \
		echo "$(GREEN)✅ All agents have security framework$(NC)"; \
	fi

clean:
	@echo "$(BLUE)Removing global agents...$(NC)"
	@rm -rf $(GLOBAL_DEST)/*
	@echo "$(GREEN)✅ Cleaned$(NC)"

version:
	@echo "$(BLUE)MyConvergio Version:$(NC)"
	@cat VERSION
	@echo ""
	@echo "$(BLUE)Agent count:$(NC) $$(find $(AGENTS_SRC) -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' | wc -l | tr -d ' ')"

update:
	@echo "$(BLUE)Syncing from ConvergioCLI...$(NC)"
	@./scripts/sync-from-convergiocli.sh

check-sync:
	@echo "$(BLUE)Checking for upstream changes in ConvergioCLI...$(NC)"
	@echo ""
	@echo "$(YELLOW)Latest commit in ConvergioCLI agents:$(NC)"
	@curl -s "https://api.github.com/repos/Roberdan/convergio-cli/commits?path=src/agents/definitions&per_page=1" 2>/dev/null | \
		grep -E '"sha"|"message"|"date"' | head -6 || echo "Could not fetch (check network)"
	@echo ""
	@echo "$(YELLOW)To see full diff, run:$(NC)"
	@echo "  ./scripts/sync-from-convergiocli.sh --dry-run"
