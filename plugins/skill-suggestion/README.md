# skill-suggestion

`UserPromptSubmit` hook that scores every skill in your `rules.json` against the submitted prompt and prints a ranked suggestion banner so Claude sees it alongside the user's message.

## Scoring

```
score = keywords*KW + intentPatterns*IW + pathPatterns*PW
```

A skill is suggested when `score >= confidenceThreshold` and no `excludePatterns` substring matches the prompt. Weights, thresholds and confidence cut-offs come from `rules.json` → `.config.scoring`.

## Always-on skills

Some skills are standing instructions rather than a match on this particular prompt — a coding-style enforcer, a house-rules skill. Give the entry `"always": true`:

```jsonc
"ponytail:ponytail": {
  "plugin": "ponytail@ponytail",
  "description": "Forces the laziest solution that actually works.",
  "always": true
}
```

A pinned skill:

- is suggested on **every** prompt, and needs no `promptTriggers` at all;
- shows as `📌 ALWAYS (always suggested)` instead of a confidence band — there is no score to report;
- is listed **before** the scored matches, and does **not** consume a `maxSkillsPerPrompt` slot, so pinning never pushes a real match into the "also matched" footer;
- ignores `excludePatterns`. Always means always — drop the flag if you want conditions.

Still gated by `enabledPlugins`: a pin whose plugin is disabled in every settings scope is skipped, same as any other skill.

Don't fake this with `"intentPatterns": [".*"]`. That matches every prompt but scores exactly `intentWeight` (3), so the skill sits permanently at the bottom of the list labeled `🟠 LOW` — the opposite of the intent.

## Rules scopes

The hook reads `rules.json` from two scopes and merges them:

```
~/.claude/skill-suggestion/rules.json                    # user scope — applies in every project
$CLAUDE_PROJECT_DIR/.claude/skill-suggestion/rules.json  # project scope — this repo only
```

Merge semantics:

- **Skills** — the union of both files. On a skill-name collision the project entry replaces the user entry wholesale.
- **Config** — deep-merged key by key, project values winning. A project can override just `confidenceThreshold` and inherit everything else from the user scope.
- Either file may be absent; a malformed file is treated as empty so one broken scope never disables the other.

The `skill-suggestion.log` scoring trace is written next to each scope's `rules.json`: the user log when user rules exist, the project log when project rules exist — both logs get the same lines when both scopes exist. A scope without rules gets no log, so a user-scope-only setup never creates `.claude/` directories inside projects.

If neither `rules.json` exists the hook silently no-ops, so installing the plugin is harmless until you opt in.

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

### File-based skill (no `plugin` field)

The skill lives at `.claude/skills/<name>/SKILL.md` — in the project when the entry comes from project rules, under `~` when it comes from user-scope rules. The banner renders the matching path so Claude can read it directly:

```
📚 managing-commits
   Description: Commits changes following project conventions.
   Confidence: 🟡 MEDIUM (score: 5)
   Path: .claude/skills/managing-commits/SKILL.md      ← project-scope entry
```

```
📚 writing-docs
   Description: Keeps READMEs and docs in house style.
   Confidence: 🟡 MEDIUM (score: 4)
   Path: ~/.claude/skills/writing-docs/SKILL.md        ← user-scope entry
```

No marketplace, no install step — just create the `SKILL.md` and reference the name in the `rules.json` of the same scope.

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

**2. Create a `rules.json`**

The hook does **not** create this file for you — without one, it silently no-ops on every prompt. Put reusable, everywhere rules in `~/.claude/skill-suggestion/rules.json` and repo-specific rules in the project's `.claude/skill-suggestion/rules.json` — either alone works, and both merge (see [Rules scopes](#rules-scopes)). Starter file for the project scope:

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
- Logs are append-only — rotate or delete each scope's `skill-suggestion.log` yourself if it grows.
- Path matching uses bash globs with `globstar`/`extglob`/`nocaseglob`, so `**/*.swift` works.
