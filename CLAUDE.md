## Project Overview

Swift Concurrency Reviewer is a Claude Code plugin that reviews Swift code for concurrency issues.

## Git

- Commits: Conventional Commits (feat|fix|refactor|build|ci|chore|docs|style|perf|test).
- Safe by default: `git status/diff/log`. Push only when user asks.
- Branch changes require user consent.
- Don't commit, and push; stop + ask.
- Don’t delete/rename unexpected stuff; stop + ask.
- No amend unless asked.

## Mindset

- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Write idiomatic, simple, maintainable Markdown for plugin commands and agents. Always ask yourself if this is the most simple intuitive solution to the problem. 

