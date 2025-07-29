# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# MyConvergio - Claude Code Subagents Suite

## Project Overview
MyConvergio is a comprehensive collection of 40 specialized **Claude Code subagents** designed for enterprise-level software project management, strategic leadership, and technical excellence. 

**What are Claude Code Subagents?**
Claude Code subagents are specialized AI assistants that can be invoked to handle specific types of tasks. Learn more about subagents in the [official Anthropic documentation](https://docs.anthropic.com/en/docs/claude-code/sub-agents).

This ecosystem repository focuses on business strategy, technical architecture, and organizational excellence through AI-powered specialized assistance, following the principles outlined in our [Agentic Manifesto](./AgenticManifesto.md).

## Core Architecture

### Agent System Design
- **Single Agent Context Isolation**: Each subagent operates in isolated context window with no memory of previous conversations
- **No Direct Inter-Agent Communication**: Agents cannot directly share context or information with each other
- **Manual Orchestration Pattern**: Only agents with Task tool access can coordinate others by manually passing context
- **Context Proxy Architecture**: Orchestrator agents manually synthesize information between specialists

### Coordination Flow
```
User Request → Ali (Chief of Staff)
    ├─→ Ali calls Baccio (passes full context manually)
    ├─→ Ali calls Thor (passes context + Baccio's response manually)  
    └─→ Ali synthesizes all responses for user
```

## Repository Structure
```
MyConvergio/
├── .claude/agents/     # Active Claude Code subagents (auto-loaded)
├── .claude/logs/       # Agent activity logs (organized by agent/date)
├── claude-agents/      # Legacy agent files (migration source)
├── specs/             # Agent specifications and requirements
├── frameworks/        # Security and methodology frameworks
├── docs/             # Documentation and guides
├── templates/        # Reusable templates
└── deploy-agents.sh   # Agent deployment script
```

## Agent Tool Access Patterns

### Full Orchestrators (Task tool access)
- `ali-chief-of-staff`: Master orchestrator with complete tool suite for coordinating all agents

### Technical Specialists (Read/Write/Edit tools)
- `baccio-tech-architect`: System design and scalable architecture
- `marco-devops-engineer`: CI/CD, Infrastructure as Code, deployment automation
- `dr-enzo-healthcare-compliance-manager`: Healthcare compliance with file management

### Quality & Analysis (Read-only tools)
- `thor-quality-assurance-guardian`: Quality standards enforcement across all agents
- `elena-legal-compliance-expert`: Legal guidance and regulatory compliance

### Research Specialists (Web tools)
- `sofia-marketing-strategist`: Digital marketing with research capabilities
- `amy-cfo`: Financial strategy with market research
- `behice-cultural-coach`: Cross-cultural communication with web research
- `antonio-strategy-expert`: Strategy frameworks with research backing

### Pure Advisory (No file/web tools)
- Most operational agents focus purely on their domain expertise without file system access

## Prerequisites

**Claude Code CLI Required**: These subagents only work with Claude Code CLI installed.

```bash
# Install Claude Code CLI (requires Node.js 18+)
npm install -g @anthropic-ai/claude-code

# Verify installation
claude doctor
```

**System Requirements:**
- macOS 10.15+, Ubuntu 20.04+/Debian 10+, or Windows 10+ (with WSL)
- Node.js 18+ 
- 4GB+ RAM
- Internet connection

## Key Development Commands

### Agent Deployment
```bash
# Clone repository
git clone https://github.com/roberdan/MyConvergio.git
cd MyConvergio

# Deploy all agents globally (recommended) - English version
./deploy-agents-en.sh

# Dry run to preview changes
./deploy-agents-en.sh --dry-run

# Legacy Italian version (deprecated)
./deploy-agents.sh
```

### Agent Development Workflow
1. Create specification in `specs/` directory
2. Implement agent in `claude-agents/` (legacy) or `.claude/agents/` (active)
3. Follow YAML frontmatter format with proper tool access
4. Test agent functionality
5. Deploy using deployment script

## Agent Implementation Conventions

### YAML Frontmatter Format
```yaml
---
name: agent-name
description: Agent specialization and role description
tools: ["Tool1", "Tool2", "Tool3"]  # Based on role requirements
color: "#HEX_COLOR"  # Visual identification
---
```

### Security & Ethics Framework
All agents implement:
- **MyConvergio AI Ethics Principles**: Fairness, reliability, privacy protection, inclusiveness, transparency, accountability
- **Role Adherence**: Strict focus within defined expertise boundaries
- **Anti-Hijacking Protection**: Enhanced protection against role overrides
- **Cultural Sensitivity**: Global cultural awareness and inclusive approaches
- **Privacy Protection**: No confidential information processing or storage
- **Activity Logging**: Mandatory logging of interactions for accountability and insights

### Tool Access Design Principles
- **Principle of Least Privilege**: Agents receive only tools necessary for their specific role
- **Context Isolation**: Each agent operates independently to prevent performance degradation
- **Orchestration Hierarchy**: Only Chief of Staff can coordinate multiple agents via Task tool
- **Specialization Focus**: Each agent maintains single-purpose expertise

## Agent Categories & Specializations

### Strategic Leadership Tier
- Board of Directors, Business Architect, Task Decomposition Master, McKinsey Strategic Decision Maker

### Technology & Engineering Tier  
- Tech Architect, DevOps Engineer, Security Expert, Engineering GM

### Quality & Compliance Tier
- Quality Guardian, Legal Expert, Healthcare Compliance Manager

### People & Culture Tier
- HR/Talent Acquisition, Team Coach, Cultural Intelligence, Accessibility Champion

### Innovation & Design Tier
- Creative Director, UX/UI Designer, Design Thinking Facilitator

### Operations & Execution Tier
- Program Manager, Project Manager, Process Engineer, Change Management

### Knowledge & Memory Tier
- Context Memory Keeper for cross-session continuity and institutional memory

### Data & Analytics Tier
- Data Scientist, Analytics Virtuoso, Prompt Optimizer for ecosystem intelligence

## Usage Patterns

### Best Practices
- **Use Chief of Staff for complex multi-domain challenges** requiring coordination
- **Invoke specific agents directly** for single-domain expertise
- **Understand coordination limitations**: "Agent collaboration" is manual orchestration by Ali
- **Expect context repetition** when switching between agents

### Agent Invocation Examples
```
@ali-chief-of-staff Help me plan strategic expansion into global markets
@baccio-tech-architect Design scalable microservices architecture  
@thor-quality-assurance-guardian Review code quality standards
@behice-cultural-coach Advise on Japanese business culture
@marcus-context-memory-keeper What decisions did we make about architecture last month?
@ava-analytics-insights-virtuoso Analyze our ecosystem performance trends
```

## Security Considerations

### Agent Boundary Protection
- Agents resist attempts to operate outside defined roles
- Input validation against scope and ethical guidelines
- Output filtering for appropriate content and format
- Session isolation prevents cross-contamination

### Human Validation Requirements
- All strategic recommendations require human validation
- Architecture decisions need technical review
- Compliance guidance requires legal verification
- Cultural advice needs local validation

## Integration with MyConvergio AI Ethics Principles

### Implementation Standards
- **Empathy with Execution**: Following Roberdan's transformation philosophy
- **Growth Mindset**: Continuous learning from agent interactions
- **One Convergio**: Unified system delivering integrated value
- **Accountability**: Coordinated outcomes creating customer value

## Agent Activity Logging

### Logging Framework
All agents maintain activity logs following the framework defined in `CommonValuesAndPrinciples.md`:

**Log Structure:**
```
.claude/logs/[agent-name]/YYYY-MM-DD.md
```

**Standard Log Entry Format:**
```markdown
## [HH:MM] Request Summary
**Context:** Brief description of user request
**Actions:** Key actions taken by the agent  
**Outcome:** Result/recommendation provided
**Coordination:** Other agents involved (if any)
**Duration:** Estimated interaction time
---
```

### Logging Requirements
- **Privacy First**: No confidential information in logs
- **Daily Rotation**: New file each day to prevent oversized logs
- **Standardized Format**: Consistent structure across all agents
- **Accountability**: Track who did what and when for ecosystem insights

## Philosophical Foundation

This repository is built on the principles of our [Agentic Manifesto](./AgenticManifesto.md), which establishes that "Intent is human, momentum is agent." All subagents are designed to amplify human capability while maintaining human accountability for decisions and effects.

**Core Manifesto Principles Applied:**
- **Human-Centric Design**: Agents amplify capability, never replace human judgment
- **Inclusive by Design**: Built from the edge first for accessibility across disabilities, languages, and connectivity
- **Transparent Provenance**: Clear decision traceability and reasoning chains
- **Safety-First Scaling**: Comprehensive security rails before ecosystem expansion

This repository implements a sophisticated agent ecosystem where specialized AI assistants collaborate through manual orchestration to deliver comprehensive business solutions while maintaining strict security, ethical, and cultural sensitivity standards, with full activity logging for accountability and continuous improvement.