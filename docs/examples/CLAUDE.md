# Example CLAUDE.md Configuration

This is an example configuration file for projects using MyConvergio agents.

## How to Use

Copy this file to your project root as `CLAUDE.md` and customize as needed.

---

# Project CLAUDE.md

## MyConvergio Integration

This project uses MyConvergio agents. To install:

```bash
# Clone MyConvergio (if not already done)
git clone https://github.com/roberdan/MyConvergio.git

# Install agents globally
cd MyConvergio && make install

# Or install specific tier
make install-tier TIER=standard VARIANT=lean RULES=consolidated
```

## Available Agents

Invoke agents using `@agent-name` syntax:

```
@ali-chief-of-staff      # Master orchestrator for complex tasks
@baccio-tech-architect   # System design and architecture
@dario-debugger          # Root cause analysis and debugging
@rex-code-reviewer       # Code review and quality
@thor-quality-assurance  # Quality validation
```

## Framework Documents

MyConvergio agents operate under these foundational documents:

| Document | Purpose |
|----------|---------|
| CONSTITUTION.md | Security, Ethics, Identity (SUPREME) |
| EXECUTION_DISCIPLINE.md | How Work Gets Done |
| CommonValuesAndPrinciples.md | Organizational Values |

## Project-Specific Guidelines

Add your project-specific guidelines below:

### Code Style
- [Define your code style preferences]

### Testing Requirements
- [Define your testing requirements]

### Security Standards
- [Define your security requirements]

### Documentation
- [Define your documentation standards]

---

## References

- [MyConvergio Repository](https://github.com/roberdan/MyConvergio)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [ISE Engineering Fundamentals](https://microsoft.github.io/code-with-engineering-playbook/)
