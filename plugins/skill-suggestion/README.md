# skill-suggestion

`UserPromptSubmit` hook that scores every skill in your `rules.json` against the submitted prompt and prints a ranked suggestion banner so Claude sees it alongside the user's message.

## Scoring

```
score = keywords*KW + intentPatterns*IW + pathPatterns*PW
```

A skill is suggested when `score >= confidenceThreshold` and no `excludePatterns` substring matches the prompt. Weights, thresholds and confidence cut-offs come from `rules.json` → `.config.scoring`.

## Project layout

The hook reads and writes everything under one directory in your project:

```
$CLAUDE_PROJECT_DIR/.claude/skill-suggestion/
├── rules.json              # you create this — skills + scoring config
└── skill-suggestion.log    # per-prompt scoring trace, created on first run
```

If `rules.json` is missing the hook silently no-ops, so installing the plugin is harmless until you opt in.

## rules.json shape

```jsonc
{
  "skills": {
    "managing-commits": {
      "description": "Commits changes following project conventions.",
      "promptTriggers": {
        "keywords": ["commit"],
        "intentPatterns": ["(create|make|write).*(commit)"],
        "pathPatterns": [],
        "excludePatterns": []
      }
    },
    "managing-prs": {
      "plugin": "managing-prs@pavliuko",
      "description": "Creates or edits a GitHub Pull Request.",
      "promptTriggers": {
        "keywords": ["pull request", "PR"],
        "intentPatterns": ["(create|open).*(pr|pull request)"],
        "pathPatterns": [],
        "excludePatterns": []
      }
    },
    "developing-swift-style": {
      "description": "Swift/iOS coding convention router. Use when working with .swift files.",
      "promptTriggers": {
        "keywords": ["swift", "swiftui", "code style"],
        "intentPatterns": ["(refactor|rename|format).*(struct|class|protocol|view|test)"],
        "pathPatterns": ["*.swift", "**/*.swift"],
        "excludePatterns": []
      }
    }
  },
  "config": {
    "maxSkillsPerPrompt": 3,
    "scoring": {
      "keywordWeight": 2,
      "intentWeight": 3,
      "pathWeight": 2,
      "confidenceThreshold": 3,
      "highConfidenceScore": 6,
      "mediumConfidenceScore": 4
    }
  }
}
```

If a skill entry has a `plugin` field, the hook only considers it when that plugin is enabled in any of `~/.claude/settings.json`, `$CLAUDE_PROJECT_DIR/.claude/settings.json`, or `$CLAUDE_PROJECT_DIR/.claude/settings.local.json`.

## Requirements

- `jq`
- `bash` 3.2+ (works on stock macOS bash)

## Install

```sh
/plugin marketplace add pavliuko/claude-plugins
/plugin install skill-suggestion@pavliuko
```

Then create `$CLAUDE_PROJECT_DIR/.claude/skill-suggestion/rules.json` for the project.

## Notes

- The hook always exits 0; it never blocks the prompt.
- Logs are append-only — rotate or delete `skill-suggestion.log` yourself if it grows.
- Path matching uses bash globs with `globstar`/`extglob`/`nocaseglob`, so `**/*.swift` works.
