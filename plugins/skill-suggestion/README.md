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

## Skill sources

A skill in `rules.json` is just a name plus triggers — the hook itself doesn't load skill content. Where Claude actually finds the skill depends on whether the entry has a `plugin` field.

### Project skill (no `plugin` field)

The skill lives in your project at `.claude/skills/<name>/SKILL.md`. The banner renders the path so Claude can read it directly:

```
📚 managing-commits
   Description: Commits changes following project conventions.
   Confidence: 🟡 MEDIUM (score: 5)
   Path: .claude/skills/managing-commits/SKILL.md
```

You manage it like any other file in the repo. No marketplace, no install step — just create `.claude/skills/managing-commits/SKILL.md` and reference the name in `rules.json`.

### Plugin skill (`plugin: "<name>@<marketplace>"`)

The skill is shipped by an installed plugin and invoked by name through the `Skill` tool. The banner makes that explicit:

```
📚 managing-prs
   Description: Creates or edits a GitHub Pull Request.
   Confidence: 🟢 HIGH (score: 7)
   Plugin: managing-prs@pavliuko
   Invoke: managing-prs
```

The hook only considers a plugin-backed skill when that plugin is listed under `enabledPlugins` in any of `~/.claude/settings.json`, `$CLAUDE_PROJECT_DIR/.claude/settings.json`, or `$CLAUDE_PROJECT_DIR/.claude/settings.local.json`. Skills whose plugin isn't enabled in any scope are silently skipped (and logged) — Claude couldn't invoke them anyway.

Mix both freely in one `rules.json`: project skills for conventions specific to the repo, plugin skills for reusable workflows you've installed from a marketplace.

## Requirements

- `jq`
- `bash` 3.2+ (works on stock macOS bash)

## Install

**1. Add the marketplace and install the plugin**

```sh
/plugin marketplace add pavliuko/claude-plugins
/plugin install skill-suggestion@pavliuko
```

**2. Create `rules.json` in your project**

The hook does **not** create this file for you — without it, the hook silently no-ops on every prompt. Drop a starter file at `.claude/skill-suggestion/rules.json`:

```sh
mkdir -p .claude/skill-suggestion
cat > .claude/skill-suggestion/rules.json <<'JSON'
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
JSON
```

Add more skills as needed — see the [`rules.json` shape](#rulesjson-shape) and [skill sources](#skill-sources) sections above.

## Notes

- The hook always exits 0; it never blocks the prompt.
- Logs are append-only — rotate or delete `skill-suggestion.log` yourself if it grows.
- Path matching uses bash globs with `globstar`/`extglob`/`nocaseglob`, so `**/*.swift` works.
