# MyConvergio Context Optimization Guide

**Version**: 3.7.0
**Last Updated**: 2025-01-02

---

## Overview

MyConvergio provides multiple installation profiles and optimization strategies to minimize Claude Code context usage while maintaining full functionality. This guide helps you choose the right configuration for your hardware and workflow.

## Quick Reference

| Profile | Agents | Rules | Context Usage | Best For |
|---------|--------|-------|---------------|----------|
| **Minimal** | 9 core | Consolidated (1 file) | ~50KB | 8GB RAM, essential agents only |
| **Standard** | ~25 agents | Consolidated (1 file) | ~200KB | 16GB RAM, common workflows |
| **Full** | 57 agents | Detailed (6 files) | ~800KB | 32GB+ RAM, complete ecosystem |
| **Lean** | 57 agents | Consolidated (1 file) | ~600KB | All agents, 20% smaller footprint |

---

## Installation Profiles

### Minimal Profile (~50KB Context)

**Recommended for**: Laptops with 8GB RAM, tight context budgets

**Includes**:
- \`ali-chief-of-staff\` - Master orchestrator
- \`thor-quality-assurance-guardian\` - Quality gatekeeper
- \`strategic-planner\` - Execution planning
- \`baccio-tech-architect\` - System design
- \`rex-code-reviewer\` - Code quality
- \`dario-debugger\` - Bug hunting
- \`otto-performance-optimizer\` - Performance tuning
- \`app-release-manager\` - Release engineering
- \`feature-release-manager\` - Feature tracking

**Installation**:
\`\`\`bash
npm install -g myconvergio
# or
myconvergio install --minimal
\`\`\`

**Context savings**: 94% reduction vs full install

---

### Standard Profile (~200KB Context)

**Recommended for**: Most developers with 16GB RAM

**Includes all categories**:
- Leadership & Strategy (7 agents)
- Technical Development (7 agents)
- Release Management (2 agents)
- Compliance & Legal (5 agents)
- Core Utility (9 agents)

**Installation**:
\`\`\`bash
MYCONVERGIO_PROFILE=standard npm install -g myconvergio
# or
myconvergio install --standard
\`\`\`

**Context savings**: 75% reduction vs full install

---

### Full Profile (~800KB Context)

**Recommended for**: High-spec machines with 32GB+ RAM

**Includes**:
- All 57 agents across 7 categories
- All 6 detailed rule files (~52KB)
- Complete skills library

**Installation**:
\`\`\`bash
MYCONVERGIO_PROFILE=full npm install -g myconvergio
# or
myconvergio install --full
\`\`\`

---

### Lean Profile (~600KB Context)

**Recommended for**: Need all agents but want 20% context reduction

**What makes it lean**:
- Strips Security & Ethics Framework sections (~30-50 lines per agent)
- Removes copyright notices
- Uses consolidated rules (1 file instead of 6)
- Keeps all functionality intact

**Installation**:
\`\`\`bash
MYCONVERGIO_PROFILE=lean npm install -g myconvergio
# or
myconvergio install --lean
\`\`\`

**Context savings**: 20% reduction vs full (756KB → 601KB)

---

## Hardware-Specific Settings

MyConvergio includes 3 settings templates optimized for different hardware specs.

### Auto-Detection
\`\`\`bash
myconvergio settings
\`\`\`

### Settings Templates

Templates available in \`.claude/settings-templates/\`:
- \`low-spec.json\` - 8GB RAM, 4 cores
- \`mid-spec.json\` - 16GB RAM, 8 cores  
- \`high-spec.json\` - 32GB+ RAM, 10+ cores

Apply recommended settings:
\`\`\`bash
myconvergio settings
# Follow the instructions to copy the recommended template
\`\`\`

---

## Summary: Recommended Configurations

### Conservative (8GB RAM)
\`\`\`bash
myconvergio install --minimal
myconvergio settings  # Apply low-spec
\`\`\`
**Result**: ~50KB context, 9 essential agents

### Balanced (16GB RAM)
\`\`\`bash
myconvergio install --lean
myconvergio settings  # Apply mid-spec
\`\`\`
**Result**: ~600KB context, all 57 agents, 20% savings

### Maximum (32GB+ RAM)
\`\`\`bash
myconvergio install --full
myconvergio settings  # Apply high-spec
\`\`\`
**Result**: ~800KB context, complete ecosystem

---

## Additional Resources

- [CLAUDE.md](../CLAUDE.md) - Project development guidelines
- [MyConvergio README](../README.md) - Full documentation
- [ISE Engineering Fundamentals](https://microsoft.github.io/code-with-engineering-playbook/)
- [Claude Code Documentation](https://code.claude.com/docs)

---

**Generated**: MyConvergio v3.7.0 Context Optimization System
**License**: CC BY-NC-SA 4.0
