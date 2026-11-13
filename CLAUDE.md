## Project Overview

Swift Concurrency Reviewer is a Claude Code plugin that reviews Swift code for concurrency issues.

## Git

- Commits: Conventional Commits (feat|fix|refactor|build|ci|chore|docs|style|perf|test).
- Safe by default: `git status/diff/log`. Push only when user asks.
- Branch changes require user consent.
- Don't commit, and push; stop + ask.
- Don’t delete/rename unexpected stuff; stop + ask.
- No amend unless asked.

## Writing Instructions for AI Agents

The skills, commands, agents, and hook messages in this repo are instructions
that an AI agent reads. A sentence with two possible meanings causes a wrong
action.

- **ALWAYS run the `asd-ste100` skill** on each text that you add or change in
  these instructions. Use the strict mode.
- A change can be inside a larger block, such as a numbered rule or a code
  example with its text. Then run the skill on the full block.
- Keep every fact, condition, and hedge. Do not add facts.
- A plugin that writes text for people, such as a commit message, depends on the
  `asd-ste100` plugin from the `asd-ste100-skill` marketplace. It runs the skill
  on that text in the STE-flavored mode. The root `marketplace.json` allows
  that marketplace in `allowCrossMarketplaceDependenciesOn`.

## Skills Name Convention

Pattern: `<gerund>-<object>`. Lowercase letters, numbers, and hyphens only. Use the gerund that best describes the action.

## Plugin CHANGELOG

All plugin history lives in the repo-root `CHANGELOG.md`. When editing a plugin, append an entry tagged with the plugin name:

- **What** changed.
- **Why** — the reason or trigger.
- **Reference** if one exists: URL, doc section, PR, or a quoted user request.

The "what" is in git; the "why" is the changelog's only value.
