# Skill Suggestion

A Claude Code plugin that scores each submitted user prompt against a project-defined catalog of skills and injects a ranked suggestion banner into the model's context for the current turn.

## How It Works

The plugin registers a `UserPromptSubmit` hook that:

1. Reads `$CLAUDE_PROJECT_DIR/.claude/skill-suggestion/rules.json`.
2. Scores every skill in `rules.json` against the prompt:
   - `score = keywords*KW + intentPatterns*IW + pathPatterns*PW`
3. Skips skills whose `excludePatterns` match, or whose `plugin` field is not present in any enabled scope's `enabledPlugins`.
4. Emits a ranked banner via `hookSpecificOutput.additionalContext` so Claude sees the suggestions.
5. Appends a per-skill scoring trace to `$CLAUDE_PROJECT_DIR/.claude/skill-suggestion/skill-suggestion.log`.

If `rules.json` is missing the hook silently exits — the plugin can be safely enabled in projects that haven't opted in.

## Installation

### Add the Marketplace

```
/plugin marketplace add pavliuko/claude-plugins
```

### Install the Plugin

```
/plugin install skill-suggestion@pavliuko
```

## Setup

Create `.claude/skill-suggestion/rules.json` in your project. Example:

```json
{
  "skills": {
    "managing-commits": {
      "description": "Commits changes following project conventions.",
      "promptTriggers": {
        "keywords": ["commit"],
        "intentPatterns": [
          "(create|make|write|add).*(commit)"
        ],
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
```

### Skill Fields

- `description` — shown in the suggestion banner.
- `plugin` (optional) — gates the skill on `enabledPlugins`. If set, the skill only fires when the named plugin is enabled in user, project, or project-local settings.
- `promptTriggers.keywords` — case-insensitive fixed-string matches.
- `promptTriggers.intentPatterns` — extended regex (`grep -E`) matched against the lowercased prompt.
- `promptTriggers.pathPatterns` — bash globs (`globstar`, `extglob`, `nocaseglob`) matched against `Foo.swift` / `@path/to/file.json` style tokens extracted from the prompt.
- `promptTriggers.excludePatterns` — case-insensitive substring match; any hit vetoes the skill regardless of score.

### Config Fields

- `maxSkillsPerPrompt` — cap on banner detail entries (extras render as a one-line "also matched" footer). Default `3`.
- `scoring.keywordWeight` — default `2`.
- `scoring.intentWeight` — default `3`.
- `scoring.pathWeight` — default `2`.
- `scoring.confidenceThreshold` — minimum score for a skill to be suggested. Default `3`.
- `scoring.highConfidenceScore` — score for the 🟢 HIGH label. Default `6`.
- `scoring.mediumConfidenceScore` — score for the 🟡 MEDIUM label. Default `4`.

## Files

- `$CLAUDE_PROJECT_DIR/.claude/skill-suggestion/rules.json` — skill catalog (you provide).
- `$CLAUDE_PROJECT_DIR/.claude/skill-suggestion/skill-suggestion.log` — per-prompt scoring trace (auto-created).

## Requirements

- `bash`, `jq`, `grep`, `sed`, `sort` (all preinstalled on macOS).

## License

MIT
