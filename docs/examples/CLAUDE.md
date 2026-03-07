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
git clone https://github.com/Roberdan/MyConvergio.git

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

| Document                     | Purpose                              |
| ---------------------------- | ------------------------------------ |
| CONSTITUTION.md              | Security, Ethics, Identity (SUPREME) |
| EXECUTION_DISCIPLINE.md      | How Work Gets Done                   |
| CommonValuesAndPrinciples.md | Organizational Values                |

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

## Recommended Workflow Mapping

| Step | Claude Code | Copilot CLI |
| --- | --- | --- |
| Capture goal | `/prompt "<goal>"` | `@prompt "<goal>"` |
| Create plan | `/planner` | `@planner` or `cplanner "<goal>"` |
| Execute | `/execute {id}` | `@execute {id}` |
| Validate | Thor / project validator | `@validate {plan_id or task}` |

Do not use Copilot CLI `/plan` if you want MyConvergio plan-db + Thor discipline. Business, design, and strategy objectives use the same workflow and close on validated deliverables when no repo merge is needed.

---

## References

- [MyConvergio Repository](https://github.com/Roberdan/MyConvergio)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [ISE Engineering Fundamentals](https://microsoft.github.io/code-with-engineering-playbook/)
