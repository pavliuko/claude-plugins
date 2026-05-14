## Project Overview

Swift Concurrency Reviewer is a Claude Code plugin that reviews Swift code for concurrency issues.

## Git

- Commits: Conventional Commits (feat|fix|refactor|build|ci|chore|docs|style|perf|test).
- Safe by default: `git status/diff/log`. Push only when user asks.
- Branch changes require user consent.
- Don't commit, and push; stop + ask.
- Don’t delete/rename unexpected stuff; stop + ask.
- No amend unless asked.

## Skills Name Convention

Pattern: `<gerund>-<object>`. Lowercase letters, numbers, and hyphens only. Use the gerund that best describes the action.

## Plugin CHANGELOG

All plugin history lives in the repo-root `CHANGELOG.md`. When editing a plugin, append an entry tagged with the plugin name:

- **What** changed.
- **Why** — the reason or trigger.
- **Reference** if one exists: URL, doc section, PR, or a quoted user request.

The "what" is in git; the "why" is the changelog's only value.
