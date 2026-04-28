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

Use **gerund form** (verb + -ing) for skill names. Lowercase letters, numbers, and hyphens only.

Stable categories:

- **`managing-`** — Project management: commits, PRs, issues, time tracking, branching, docs.
- **`developing-`** — Writing and understanding code: explanation, generation, debugging, refactoring.

Examples: `managing-prs`, `developing-code-explain`.
