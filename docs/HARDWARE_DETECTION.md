# Hardware Detection & Optimization

MyConvergio detects your hardware and lets you scale setup accordingly.

## Recommended profiles

| Machine profile | Command |
| --- | --- |
| Low-spec laptop | `myconvergio setup --minimal` |
| Daily dev machine | `myconvergio setup --standard --with-shell --with-devtools` |
| Power workstation | `myconvergio setup --full --with-workstation` |

## What changes by profile

### Minimal

- core agents, rules, hooks, scripts
- required dependencies only
- no extra workstation tooling unless requested

### Standard

- adds dashboard, plan scripts, mesh-ready config
- recommended CLI tools: `rg`, `fd`, `fzf`, `gh`, `jq`, `yq`
- ideal for most laptops

### Full workstation

- standard install plus optional shell bootstrap, prompt, tmux, Tailscale, and platform-specific terminal extras
- intended to replicate the maintainer workflow while staying opt-in

## Shell + PATH verification

```bash
myconvergio shell-check
myconvergio init-shell --yes
```

## Devtools bootstrap

```bash
myconvergio install-tools --profile full --with-prompt
```

## Dashboard / runtime verification

```bash
myconvergio doctor
python3 ~/.claude/scripts/dashboard_web/server.py
```
