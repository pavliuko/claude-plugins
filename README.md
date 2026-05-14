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
| [`managing-skills`](plugins/managing-skills/SKILL.md) | Authoring guide for creating and editing project-level Claude Code skills and slash commands. |

### Install

```
/plugin install swift-concurrency-reviewer@pavliuko
/plugin install skill-suggestion@pavliuko
/plugin install managing-skills@pavliuko
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
│   └── managing-skills/
└── CLAUDE.md                # repo-wide guidance (naming, git rules)
```

## License

MIT
