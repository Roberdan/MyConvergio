# 🚀 MyConvergio Agent Installation Guide

## ⚡ EASIEST WAY (Just run this!)

```bash
./deploy-agents.sh
```

**The script asks 2 simple questions:**

### Domanda 1: Dove li installo?

**OPZIONE 1 = INSTALLA PER TUTTI I TUOI PROGETTI** ← *Consigliato*
- Gli agenti funzionano in OGNI progetto Claude Code
- Li installi una volta, li usi ovunque
- Si installano in ~/.claude/agents/

**OPZIONE 2 = INSTALLA SOLO PER QUESTO PROGETTO**
- Gli agenti funzionano SOLO in questa cartella
- Se cambi progetto, non li hai più
- Si installano in .claude/agents/

### Domanda 2: Quali agenti installo?

**OPZIONE 1 = INSTALLA TUTTI I 16 AGENTI** ← *Consigliato*
- Suite MyConvergio completa (30 secondi)
- Chief of Staff + tutti i 15 specialisti
- Pronti per qualsiasi sfida di business

**OPZIONE 2 = INSTALLA SOLO ALCUNI SPECIFICI**
- Tu scegli esattamente quali installare
- Installazione più leggera
- Puoi aggiungerne altri dopo

### That's it! The script does everything else! 🎉

## 🎯 Quick Commands (For Advanced Users)

```bash
# All agents globally (skip questions)
./deploy-agents.sh --global

# All agents for this project only  
./deploy-agents.sh --local

# Just the Chief of Staff
./deploy-agents.sh --global --agent chief-of-staff

# Multiple specific agents
./deploy-agents.sh --local --agent chief-of-staff,board-of-directors,okr-strategy-expert

# See all available agents
./deploy-agents.sh --list
```

## Manual Installation (Alternative)

### Option 1: User-Level Installation
```bash
mkdir -p ~/.claude/agents
cp MyConvergio/claude-agents/* ~/.claude/agents/
```

### Option 2: Project-Level Installation
```bash
mkdir -p .claude/agents
cp MyConvergio/claude-agents/* .claude/agents/
```

## Available Agents

### Master Orchestrator
- ✅ **chief-of-staff**: Single point of contact orchestrating all agents for integrated solutions

### Strategic Leadership Tier
- ✅ **board-of-directors**: System-thinking with Roberdan's empathy-driven transformation approach
- ✅ **strategic-business-architect**: Business planning and market analysis
- ✅ **strategic-task-decomposition-master**: Complex problem breakdown, OKR management

### Operational Excellence Tier
- ✅ **program-management-excellence-coach**: Multi-project orchestration
- ✅ **process-optimization-consultant**: Lean Six Sigma methodologies
- ✅ **financial-roi-analyst**: Project economics and business cases

### Innovation & Culture Tier
- ✅ **creative-director**: Breakthrough creativity and innovative thinking
- ✅ **design-thinking-facilitator**: Innovation and user-centered design
- ✅ **team-dynamics-cross-cultural-expert**: International team building

### Technical & Quality Tier
- ✅ **technology-architecture-advisor**: Technical strategy and architecture
- ✅ **quality-assurance-guardian**: Standards enforcement and excellence monitoring
- ✅ **executive-communication-strategist**: C-suite communication excellence

## Usage Examples

## 🎮 How to Use Your Agents

### 🎯 Start with the Chief of Staff (Your Main Interface)
```
@chief-of-staff
I need to plan our global expansion into Japan and Saudi Arabia. Help me create a comprehensive strategy.
```

**The Chief of Staff automatically coordinates all relevant specialists:**
- 🌍 Global Culture Intelligence Expert (cultural insights)  
- 📊 Strategic Business Architect (market analysis)
- 🎯 OKR Strategy Expert (goals framework)
- 💼 Executive Communication Strategist (stakeholder messaging)
- 🔄 Change Management Specialist (transformation planning)

### 🔧 Direct Agent Access (When You Need Specialists)
```
@board-of-directors
Help me design a system for scaling empathy in leadership

@creative-director  
I need breakthrough naming ideas for our AI platform

@okr-strategy-expert
Create Q4 OKRs aligned with our strategic vision
```

## Verification

After installation, verify agents are available:

1. Open Claude Code
2. Type `@` and you should see your installed agents in the autocomplete
3. Try using one of the agents with a simple request

## Security Features

All MyConvergio agents include:
- ✅ Role adherence and anti-hijacking protection
- ✅ Microsoft AI principles integration
- ✅ Cultural sensitivity and inclusiveness
- ✅ Privacy protection (no confidential data storage)
- ✅ Human validation requirements for strategic decisions

## Troubleshooting

### Agent Not Appearing
- Check file location: `~/.claude/agents/` or `.claude/agents/`
- Verify YAML frontmatter format is correct
- Restart Claude Code

### Agent Not Responding Correctly
- Verify the agent file contains the complete prompt
- Check for YAML formatting errors
- Ensure the `name` in frontmatter matches filename (without .md)

## Next Steps

1. Install the core 3 agents
2. Test with sample requests
3. Check back for additional agents as they're completed
4. Provide feedback for continuous improvement

## Support

For issues or suggestions:
- Review agent specifications in `/specs/` directory
- Check security framework in `/frameworks/`
- Modify agents as needed for your specific requirements