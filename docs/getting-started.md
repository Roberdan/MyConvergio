# Getting Started with MyConvergio

From zero to a working AI organization in one guided command.

## Prerequisites

| Tool | Required | Notes |
| --- | --- | --- |
| `bash` | Yes | macOS/Linux/WSL |
| `git` | Yes | install/update workflow |
| `sqlite3` | Yes | dashboard + plan DB |
| `claude` | Yes | Claude Code / CLI |
| `gh` | Optional | Copilot CLI + PR automation |

**Windows**: use WSL2.

## Installation

### Fastest path

```bash
curl -sSL https://raw.githubusercontent.com/Roberdan/MyConvergio/master/install.sh | bash
myconvergio setup --full --with-workstation
```

### What `myconvergio setup` does

1. detects OS, architecture, package manager, and hardware tier
2. installs missing required dependencies
3. installs MyConvergio assets into `~/.claude/`
4. optionally installs recommended CLI/dev tools (`rg`, `fd`, `fzf`, `gh`, `delta`, `eza`, `starship`, etc.)
5. optionally updates your shell RC with PATH + `shell-aliases.sh`
6. verifies the environment with `myconvergio doctor`

### Common profiles

```bash
myconvergio setup --minimal
myconvergio setup --standard --with-shell --with-devtools
myconvergio setup --full --with-workstation
```

## Your first workflow

```bash
@prompt Add Stripe checkout with subscription management to my Next.js SaaS
@planner Create plan from .copilot-tracking/stripe-prompt.md
@execute 42
```

Thor validates every task before it becomes done.

## Dashboard

```bash
python3 ~/.claude/scripts/dashboard_web/server.py
```

Open `http://localhost:8420` to see:

- plan/wave/task status
- live organization view (agents grouped by node / role)
- live runtime graph (active runs, handoffs, events)
- per-model token/cost attribution

## Useful commands

```bash
myconvergio doctor
myconvergio shell-check
myconvergio init-shell --yes
myconvergio install-tools --profile full --with-prompt
plan-db.sh list-tasks 42
```

[README](../README.md) | [Workflow](workflow.md) | [Hardware](HARDWARE_DETECTION.md)
