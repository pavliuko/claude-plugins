# The Directive-Description Pattern

The `description:` field is the single signal the harness uses to decide whether to activate a skill. It has to do two jobs: say *what* the skill does and *that the model must use it* instead of acting directly.

## The Shape

```
<short factual lead>. ALWAYS invoke this skill when <trigger clauses>. Do not <forbidden direct action> — use this skill first.
```

- **Lead** — one third-person sentence starting with a verb. No "I" / "you", no marketing.
- **Trigger clauses** — 3–6 concrete user-intent phrases. The router does keyword matching, so mix natural-language phrases with the backticked CLI/API/file names the workflow touches. Include obvious typos and casual forms when common. Don't claim triggers that belong to another skill.
- **Negative constraint** — name the exact shortcut the model would otherwise take (the CLI command, the file the skill owns, the artifact it produces). This is the half that changes behavior; the router can find the skill, but the model defaults to acting directly unless told not to.

Skip slot 3 only if there's no obvious direct action to replace (rare). Skip the whole pattern when `disable-model-invocation: true` — the description doesn't drive routing then.

## Scoping to Avoid Overlap

When multiple skills could match a prompt, only one fires. The skill set is dynamic — don't maintain a static table of neighbors. Instead:

1. `ls .claude/skills/` and `ls .claude/commands/`; read each existing `description:`.
2. Compare your draft triggers against theirs. If your trigger phrases (verbatim or as obvious synonyms) appear in another skill's description, that's an overlap.
3. Stop and ask the user how to resolve it.

Scope by **files or CLI commands the skill owns** — they don't collide the way English verbs do.

## Self-Check

- [ ] Three slots present (lead, triggers, negative constraint) — or `disable-model-invocation: true`
- [ ] Triggers include backticked CLI/API/file names where they exist
- [ ] No overlap with existing skills
- [ ] Third person, under 1024 chars, no time-sensitive wording
