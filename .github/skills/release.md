# Release

Run pre-release quality validation through the release manager workflow.

## Usage

`@release` or `@release {version}` (also `/release`)

## Protocol

1. Launch release validation through the `app-release-manager` flow.
2. Validate build quality, tests, security checks, code quality, and documentation.
3. Apply allowed auto-fixes, then re-run impacted checks.
4. Block on any failing gate (tests, lint, vulnerabilities, secrets, TODO/FIXME, debug prints).
5. If approved, proceed with versioning/tagging/changelog steps; otherwise fix and re-run.

Full specification: `commands/release.md`
