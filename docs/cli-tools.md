# Fast CLI Tools

> Reference: `@docs/cli-tools.md` for Bash operations

When using Bash, PREFER these modern tools:

| Instead of | Use | Why |
|------------|-----|-----|
| `grep` | `rg` | 5-10x faster |
| `find` | `fd` | 5x faster |
| `cat` | `bat` | Syntax highlighting |
| `ls` | `eza` | Git integration |
| `du` | `dust` | Visual tree |
| `sed` | `sd` | Simpler, faster |
| `diff` | `delta` | Syntax-aware |
| `top` | `btm` | Modern monitor |
| `cloc` | `tokei` | 10x faster |
| `time` | `hyperfine` | Accurate bench |

**Note**: Internal tools (Grep, Glob, Read) already use ripgrep.
