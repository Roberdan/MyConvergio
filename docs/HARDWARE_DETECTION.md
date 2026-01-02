# Hardware Detection & Optimization

MyConvergio automatically detects your system specs, but you can optimize further.

## Automatic Detection

During installation, MyConvergio detects:
- **Total RAM**: For Node.js memory limits
- **CPU Cores**: For parallel execution tuning
- **Platform**: macOS, Linux, Windows (WSL)

## Manual Optimization

Copy and edit the optimized settings template:

```bash
cp docs/templates/settings-optimized.jsonc ~/.claude/settings.json
```

Then adjust these values based on your hardware:

### Memory Settings

| Your RAM | NODE_OPTIONS | Reasoning |
|----------|--------------|-----------|
| 4GB | `--max-old-space-size=2048` | 50% of RAM |
| 8GB | `--max-old-space-size=4096` | 50% of RAM |
| 16GB | `--max-old-space-size=8192` | 50% of RAM |
| 32GB+ | `--max-old-space-size=16384` | 50% of RAM |

### CPU Settings

| Your CPU | UV_THREADPOOL_SIZE | Cores |
|----------|-------------------|-------|
| M1/M2 | `8` | 8 cores |
| M2 Pro | `10` | 10 cores |
| M3 Max | `12` | 12 cores |
| Intel i5 | `4` | 4 cores |
| Intel i7 | `6-8` | 6-8 cores |

### Context Settings

| Your RAM | MAX_OUTPUT_TOKENS | MAX_THINKING_TOKENS |
|----------|-------------------|---------------------|
| 4GB | `8000` | `8000` |
| 8GB | `16000` | `16000` |
| 16GB+ | `32000` | `31999` |
| 32GB+ | `64000` | `31999` |

## Installation Profiles by Hardware

### 4-8GB RAM
```bash
# Minimal install + consolidated rules
MYCONVERGIO_PROFILE=minimal npm install -g myconvergio
cp .claude/rules/consolidated/engineering-standards.md ~/.claude/rules/
```

**Expected context usage**: ~50KB (8 agents + consolidated rules)

### 8-16GB RAM
```bash
# Standard install + consolidated rules
MYCONVERGIO_PROFILE=standard npm install -g myconvergio
cp .claude/rules/consolidated/engineering-standards.md ~/.claude/rules/
```

**Expected context usage**: ~200KB (20 agents + consolidated rules)

### 16-32GB RAM
```bash
# Full install + detailed rules
MYCONVERGIO_PROFILE=full npm install -g myconvergio
# Uses detailed rules by default (6 files)
```

**Expected context usage**: ~800KB (57 agents + detailed rules)

### 32GB+ RAM (Power Users)
```bash
# Lean install for maximum agents with minimal overhead
MYCONVERGIO_PROFILE=lean npm install -g myconvergio
```

**Expected context usage**: ~400KB (57 agents, stripped frameworks)

## Real-World Examples

### Developer Laptop (MacBook Pro M1, 16GB)
```json
{
  "env": {
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "32000",
    "MAX_THINKING_TOKENS": "31999",
    "NODE_OPTIONS": "--max-old-space-size=8192",
    "UV_THREADPOOL_SIZE": "8"
  }
}
```

Installation: `MYCONVERGIO_PROFILE=standard npm install -g myconvergio`

### Workstation (M3 Max, 36GB)
```json
{
  "env": {
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "64000",
    "MAX_THINKING_TOKENS": "31999",
    "NODE_OPTIONS": "--max-old-space-size=16384",
    "UV_THREADPOOL_SIZE": "12"
  }
}
```

Installation: `MYCONVERGIO_PROFILE=full npm install -g myconvergio`

### Budget Laptop (Intel i5, 8GB)
```json
{
  "env": {
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "16000",
    "MAX_THINKING_TOKENS": "16000",
    "NODE_OPTIONS": "--max-old-space-size=4096",
    "UV_THREADPOOL_SIZE": "4"
  }
}
```

Installation: `MYCONVERGIO_PROFILE=minimal npm install -g myconvergio`

## Monitoring Performance

Check your Claude Code performance:

```bash
# View current settings
cat ~/.claude/settings.json

# Check installed agent count
myconvergio agents | tail -1

# Check memory usage during Claude Code session
top -pid $(pgrep -f claude)
```

## Troubleshooting

### "Out of Memory" Errors
1. Reduce `NODE_OPTIONS` max-old-space-size
2. Switch to minimal profile: `myconvergio install --minimal`
3. Use consolidated rules instead of detailed

### Slow Performance
1. Increase `UV_THREADPOOL_SIZE` to match CPU cores
2. Enable `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`
3. Consider lean profile: `myconvergio install --lean`

### Context Window Overflow
1. Reduce agent count (minimal profile)
2. Use consolidated rules
3. Lower `MAX_OUTPUT_TOKENS` and `MAX_THINKING_TOKENS`
