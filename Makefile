# =============================================================================
# MyConvergio Agent Management
# =============================================================================
# Version: 2.0.0
# =============================================================================

.PHONY: install install-local upgrade test clean update check-sync version help lint validate

# Directories
AGENTS_SRC := .claude/agents
RULES_SRC := .claude/rules
SKILLS_SRC := .claude/skills
CLAUDE_HOME := $(HOME)/.claude
GLOBAL_AGENTS := $(CLAUDE_HOME)/agents
GLOBAL_RULES := $(CLAUDE_HOME)/rules
GLOBAL_SKILLS := $(CLAUDE_HOME)/skills

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
RED := \033[0;31m
NC := \033[0m

# Default target
.DEFAULT_GOAL := help

help:
	@echo "$(BLUE)MyConvergio Agent Management$(NC)"
	@echo ""
	@echo "$(YELLOW)For New Users:$(NC)"
	@echo "  make install        Install agents, rules, and skills to ~/.claude/"
	@echo ""
	@echo "$(YELLOW)For Existing Users:$(NC)"
	@echo "  make upgrade        Update to latest version (clean + install)"
	@echo ""
	@echo "$(YELLOW)Other Options:$(NC)"
	@echo "  make install-local  Install to current project only (./.claude/)"
	@echo "  make clean          Remove all installed components from ~/.claude/"
	@echo "  make version        Show installed version info"
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@echo "  make test           Run agent tests"
	@echo "  make lint           Lint agent YAML frontmatter"
	@echo "  make validate       Validate Constitution compliance"

install:
	@echo "$(BLUE)Installing MyConvergio to $(CLAUDE_HOME)/...$(NC)"
	@echo ""
	@# Install agents
	@mkdir -p $(GLOBAL_AGENTS)
	@cp -r $(AGENTS_SRC)/* $(GLOBAL_AGENTS)/
	@AGENT_COUNT=$$(find $(GLOBAL_AGENTS) -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' ! -name 'SECURITY_FRAMEWORK_TEMPLATE.md' | wc -l | tr -d ' '); \
	echo "  $(GREEN)✓$(NC) Installed $$AGENT_COUNT agents"
	@# Install rules
	@mkdir -p $(GLOBAL_RULES)
	@cp -r $(RULES_SRC)/* $(GLOBAL_RULES)/
	@RULES_COUNT=$$(find $(GLOBAL_RULES) -name '*.md' | wc -l | tr -d ' '); \
	echo "  $(GREEN)✓$(NC) Installed $$RULES_COUNT rules"
	@# Install skills
	@mkdir -p $(GLOBAL_SKILLS)
	@cp -r $(SKILLS_SRC)/* $(GLOBAL_SKILLS)/
	@SKILLS_COUNT=$$(find $(GLOBAL_SKILLS) -type d -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '); \
	echo "  $(GREEN)✓$(NC) Installed $$SKILLS_COUNT skills"
	@echo ""
	@echo "$(GREEN)✅ Installation complete!$(NC)"
	@echo ""
	@echo "$(YELLOW)Note:$(NC) Your ~/.claude/CLAUDE.md was NOT modified."
	@echo "      Create your own or copy from docs/examples/ if needed."

install-local:
	@echo "$(BLUE)Installing to current project ./.claude/...$(NC)"
	@mkdir -p .claude/agents .claude/rules .claude/skills
	@cp -r $(AGENTS_SRC)/* .claude/agents/
	@cp -r $(RULES_SRC)/* .claude/rules/
	@cp -r $(SKILLS_SRC)/* .claude/skills/
	@echo "$(GREEN)✅ Local installation complete$(NC)"

upgrade:
	@echo "$(BLUE)Upgrading MyConvergio...$(NC)"
	@echo ""
	@# Show current version if exists
	@if [ -f "$(GLOBAL_AGENTS)/core_utility/CONSTITUTION.md" ]; then \
		echo "$(YELLOW)Current installation found. Removing old version...$(NC)"; \
	else \
		echo "$(YELLOW)No previous installation found. Installing fresh...$(NC)"; \
	fi
	@$(MAKE) clean --no-print-directory
	@$(MAKE) install --no-print-directory
	@echo ""
	@echo "$(GREEN)✅ Upgrade complete!$(NC)"

clean:
	@echo "$(BLUE)Removing installed components...$(NC)"
	@rm -rf $(GLOBAL_AGENTS)/* 2>/dev/null || true
	@rm -rf $(GLOBAL_RULES)/* 2>/dev/null || true
	@rm -rf $(GLOBAL_SKILLS)/* 2>/dev/null || true
	@echo "  $(GREEN)✓$(NC) Cleaned ~/.claude/agents/"
	@echo "  $(GREEN)✓$(NC) Cleaned ~/.claude/rules/"
	@echo "  $(GREEN)✓$(NC) Cleaned ~/.claude/skills/"
	@echo ""
	@echo "$(YELLOW)Note:$(NC) ~/.claude/CLAUDE.md was NOT removed (user config)."

version:
	@echo "$(BLUE)MyConvergio Version Info$(NC)"
	@echo ""
	@cat VERSION | head -6
	@echo ""
	@echo "$(BLUE)Installed Components:$(NC)"
	@if [ -d "$(GLOBAL_AGENTS)" ]; then \
		AGENT_COUNT=$$(find $(GLOBAL_AGENTS) -name '*.md' 2>/dev/null | wc -l | tr -d ' '); \
		echo "  Agents: $$AGENT_COUNT"; \
	else \
		echo "  Agents: $(RED)not installed$(NC)"; \
	fi
	@if [ -d "$(GLOBAL_RULES)" ]; then \
		RULES_COUNT=$$(find $(GLOBAL_RULES) -name '*.md' 2>/dev/null | wc -l | tr -d ' '); \
		echo "  Rules:  $$RULES_COUNT"; \
	else \
		echo "  Rules:  $(RED)not installed$(NC)"; \
	fi
	@if [ -d "$(GLOBAL_SKILLS)" ]; then \
		SKILLS_COUNT=$$(find $(GLOBAL_SKILLS) -type d -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' '); \
		echo "  Skills: $$SKILLS_COUNT"; \
	else \
		echo "  Skills: $(RED)not installed$(NC)"; \
	fi

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

# =============================================================================
# Maintainer Commands (not in help - for internal use)
# =============================================================================

update:
	@echo "$(BLUE)Syncing from ConvergioCLI...$(NC)"
	@./scripts/sync-from-convergiocli.sh

check-sync:
	@echo "$(BLUE)Checking for upstream changes in ConvergioCLI...$(NC)"
	@curl -s "https://api.github.com/repos/Roberdan/convergio-cli/commits?path=src/agents/definitions&per_page=1" 2>/dev/null | \
		grep -E '"sha"|"message"|"date"' | head -6 || echo "Could not fetch (check network)"
