# pavliuko's Claude Code Plugins

A personal marketplace of [Claude Code](https://docs.claude.com/en/docs/claude-code) plugins.

## Add the Marketplace

```
/plugin marketplace add pavliuko/claude-plugins
```

Once added, install any plugin below with `/plugin install <name>@pavliuko`.

## Plugins

| Plugin | What it does |
| --- | --- |
| [`swift-concurrency-reviewer`](plugins/swift-concurrency-reviewer/README.md) | Reviews Swift PRs for concurrency issues. Has `learn` and `concise` output modes. |
| [`skill-suggestion`](plugins/skill-suggestion/README.md) | `UserPromptSubmit` hook that scores your prompt against project-defined skill triggers and injects a ranked suggestion banner into Claude's context. |
| [`building-skills`](plugins/building-skills/SKILL.md) | Authoring guide for creating and editing project-level Claude Code skills and slash commands. |
| [`reviewing`](plugins/reviewing/skills/reviewing/SKILL.md) | Scope-aware code and document review. Asks for scope, applies confidence-rated findings, and loads project rules from `.claude/reviewing-instructions/`. |
| [`explaining`](plugins/explaining/skills/explaining/SKILL.md) | Explains anything — code, concepts, systems, processes — with an ASCII diagram, a step-by-step walkthrough, and a gotcha. |

### Install

```
/plugin install swift-concurrency-reviewer@pavliuko
/plugin install skill-suggestion@pavliuko
/plugin install building-skills@pavliuko
/plugin install reviewing@pavliuko
/plugin install explaining@pavliuko
```

See each plugin's README for prerequisites, configuration, and usage.

## Repo Layout

```
.
├── .claude-plugin/
│   └── marketplace.json     # marketplace manifest consumed by /plugin
├── plugins/
│   ├── swift-concurrency-reviewer/
│   ├── skill-suggestion/
│   ├── building-skills/
│   ├── reviewing/
│   └── explaining/
└── CLAUDE.md                # repo-wide guidance (naming, git rules)
```

## License

MIT
