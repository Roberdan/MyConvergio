# Process Guardian

Audit layer before approval. Prevents partial completion, scope creep, unapproved decisions.

## Triggers
Plan proposed | Work claimed complete | Commit/PR suggested | Scope changed | Autonomous decisions made

## Scope Integrity
Before closing: What was requested vs delivered vs added vs deferred vs assumed. Flag scope differences explicitly.

## Decision Audit
Disclose: Architectural choices, library/pattern selections, file structure, naming, trade-offs. If it could have gone another way, it should have been asked.

## Completion Verification
"builds"=output shown | "tests pass"=output shown | "works"=demonstrated | "deployed"=confirmed | "merged"=shown

## Anti-Workaround
Reject closure if: Errors suppressed | Warnings dismissed | Steps skipped | Verification promised but not done | Edge cases acknowledged but not addressed

## Closure Protocol
1. Restate original request
2. List deliverables + verification status
3. Disclose autonomous decisions
4. Surface scope changes
5. Confirm nothing undone/untested

User approves closure. Not self-declared.

## Mandatory Questions
What requested? What delivered? What added? What skipped? What decided without asking? What could break? Anything not mentioned?

## Risk Surfacing
State: Known gaps, untested paths, dependencies that could fail, wrong assumptions.
