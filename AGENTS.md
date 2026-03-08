# AGENTS.md

Cross-tool index. Agent definitions are lazy-loaded only when an agent is spawned.

## Loading Model

- Startup loads this index only (names + short descriptions).
- Definitions are behind wrappers in `reference/agents/`.
- Spawn-time include format: `@reference/agents/<source-path>.md`.

## Shared Rules Source

- `CLAUDE.md`
- `reference/operational/`
- Source definitions: `agents/`, `copilot-agents/`

## Agent Index

### Business Operations
- `andrea-customer-success-manager` — Andrea customer success manager
- `anna-executive-assistant` — Anna executive assistant
- `dave-change-management-specialist` — Dave change management specialist
- `davide-project-manager` — Davide project manager
- `enrico-business-process-engineer` — Enrico business process engineer
- `fabio-sales-business-development` — Fabio sales business development
- `luke-program-manager` — Luke program manager
- `marcello-pm` — Marcello pm
- `oliver-pm` — Oliver pm
- `sofia-marketing-strategist` — Sofia marketing strategist
- `steve-executive-communication-strategist` — Steve executive communication strategist

### Compliance & Legal
- `dr-enzo-healthcare-compliance-manager` — Dr enzo healthcare compliance manager
- `elena-legal-compliance-expert` — Elena legal compliance expert
- `guardian-ai-security-validator` — Guardian ai security validator
- `luca-security-expert` — Luca security expert
- `sophia-govaffairs` — Sophia govaffairs

### Copilot Orchestration
- `check` — Session status check — brief recap of git state, acti...
- `execute` — Execute plan tasks with TDD workflow, drift detection...
- `planner` — Create execution plans with waves/tasks from F-xx req...
- `prompt` — Extract structured requirements (F-xx) from user inpu...
- `validate` — Thor quality validation - verify completed tasks/wave...

### Core Utility
- `CommonValuesAndPrinciples` — Inspired by Microsoft's Culture & Values framework, a...
- `CONSTITUTION` — CONSTITUTION agent
- `deep-repo-auditor` — Cross-validated deep repository audit — dual AI model...
- `diana-performance-dashboard` — Diana performance dashboard
- `execution-discipline` — Execution rules and workflow discipline for MyConverg...
- `marcus-context-memory-keeper` — Marcus context memory keeper
- `MICROSOFT_VALUES` — MICROSOFTVALUES agent
- `plan-business-advisor` — Business impact advisor for execution plans. Estimate...
- `plan-post-mortem` — Post-mortem analyzer for completed plans. Extracts st...
- `plan-reviewer` — Independent plan quality reviewer. Fresh context, zer...
- `po-prompt-optimizer` — Po prompt optimizer
- `SECURITY_FRAMEWORK_TEMPLATE` — SECURITYFRAMEWORKTEMPLATE agent
- `sentinel-ecosystem-guardian` — You keep the entire Claude Code ecosystem current, se...
- `socrates-first-principles-reasoning` — Socrates first principles reasoning
- `strategic-planner` — Strategic planner for execution plans with wave-based...
- `strategic-planner-git` — Git worktree workflow for strategic-planner parallel...
- `strategic-planner-templates` — Plan document templates for strategic-planner. Refere...
- `strategic-planner-thor` — Thor validation gates for strategic-planner. Referenc...
- `taskmaster-strategic-task-decomposition-master` — Taskmaster strategic task decomposition master
- `thor-quality-assurance-guardian` — Brutal quality gatekeeper. Zero tolerance for incompl...
- `thor-validation-gates` — Validation gates module for Thor. Reference only.
- `wanda-workflow-orchestrator` — Wanda workflow orchestrator
- `xavier-coordination-patterns` — Xavier coordination patterns

### Design & UX
- `jony-creative-director` — Jony creative director
- `sara-ux-ui-designer` — Sara ux ui designer
- `stefano-design-thinking-facilitator` — Stefano design thinking facilitator

### Leadership Strategy
- `ali-chief-of-staff` — Ali chief of staff
- `amy-cfo` — Amy cfo
- `antonio-strategy-expert` — Antonio strategy expert
- `dan-engineering-gm` — Dan engineering gm
- `domik-mckinsey-strategic-decision-maker` — Domik mckinsey strategic decision maker
- `matteo-strategic-business-architect` — Matteo strategic business architect
- `satya-board-of-directors` — Satya board of directors

### Miscellaneous
- `pr-comment-resolver` — Automated PR review comment resolver - fetch threads,...

### Release Management
- `app-release-manager` — BRUTAL Release Manager ensuring production-ready qual...
- `app-release-manager-execution` — Execution phases (3-5) for app-release-manager. Refer...
- `ecosystem-sync` — Ecosystem sync
- `feature-release-manager` — Feature completion workflow - analyze GitHub issues,...
- `mirrorbuddy-hardening-checks` — Production hardening validation for MirrorBuddy relea...

### Research Report
- `research-report-generator` — Convergio Think Tank - Professional research report g...

### Specialized Experts
- `angela-da` — Angela da
- `ava-analytics-insights-virtuoso` — Ava analytics insights virtuoso
- `behice-cultural-coach` — Behice cultural coach
- `coach-team-coach` — Coach team coach
- `ethan-da` — Ethan da
- `evan-ic6da` — Evan ic6da
- `fiona-market-analyst` — Fiona market analyst
- `giulia-hr-talent-acquisition` — Giulia hr talent acquisition
- `jenny-inclusive-accessibility-champion` — Jenny inclusive accessibility champion
- `michael-vc` — Michael vc
- `riccardo-storyteller` — Riccardo storyteller
- `sam-startupper` — Sam startupper
- `wiz-investor-venture-capital` — Wiz investor venture capital

### Technical Development
- `adversarial-debugger` — Launches 3 parallel Explore agents with competing hyp...
- `baccio-tech-architect` — Baccio tech architect
- `dario-debugger` — Dario debugger
- `marco-devops-engineer` — Marco devops engineer
- `omri-data-scientist` — Omri data scientist
- `otto-performance-optimizer` — Otto performance optimizer
- `paolo-best-practices-enforcer` — Paolo best practices enforcer
- `rex-code-reviewer` — Rex code reviewer
- `task-executor` — Specialized executor for plan tasks. TDD workflow, F-...
- `task-executor-selfheal` — Self-healing module for task-executor. Auto-diagnose,...
- `task-executor-tdd` — TDD workflow module for task-executor. Reference only.

## Lazy Reference Manifests

- `reference/agents/INDEX.md` maps agent names to wrapper includes.
- Wrapper folders mirror source layout for on-demand loading.
