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
| [`cmp`](plugins/cmp/commands/cmp.md) | Shorthand slash command for "commit and push" — commits pending changes and pushes to the remote. |

### Install

```
/plugin install swift-concurrency-reviewer@pavliuko
/plugin install skill-suggestion@pavliuko
/plugin install building-skills@pavliuko
/plugin install reviewing@pavliuko
/plugin install explaining@pavliuko
/plugin install cmp@pavliuko
```

See each plugin's README for prerequisites, configuration, and usage.

## Standalone

Not everything Claude Code can be configured with fits the plugin format.

| Directory | What it is |
| --- | --- |
| [`statusline/`](statusline/README.md) | Two-line status line: model, effort, directory, git, clickable PR, context bar, rate-limit window, account. Installed by copying the script — a plugin's `settings.json` can't carry the `statusLine` key. |

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
│   ├── explaining/
│   └── cmp/
├── statusline/              # standalone status line script (not a plugin)
└── CLAUDE.md                # repo-wide guidance (naming, git rules)
```

## License

MIT
