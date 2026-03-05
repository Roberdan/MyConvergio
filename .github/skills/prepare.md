# Prepare

Bootstrap a project for workflow usage: detect stack, create/update setup docs, and register project metadata.

## Usage

`@prepare` or `/prepare`

## Protocol

1. Detect project type from manifest files (`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`).
2. Analyze repository structure and detect an icon candidate.
3. Create or update `CLAUDE.md` and `.claudeignore` using detected conventions.
4. Register the project in `~/.claude/plans/registry.json` including icon path metadata.
5. Respect command flags (`--check`, `--force`, `--minimal`) when provided.

Full specification: `commands/prepare.md`
