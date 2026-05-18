# Changelog

History of changes across all plugins. Append an entry every time a plugin is edited.

**Each bullet must say what changed AND why.** If the change came from a user request, a doc, a PR, or an external source, link or quote it. The "what" is recoverable from git history; the "why" is what makes the changelog useful when revisiting a decision later.

Format:

```
## YYYY-MM-DD [<plugin>]

- <What changed> — <why>. <Reference: URL / "user request: ..." / doc section / PR / quoted message>.
```

---

## 2026-05-18 [reviewing]

- Fixed gaps and ambiguities surfaced by a self-review of the skill: (1) clarified that "repo root" in the instruction-loading rule means the user's working repo, not the plugin's repo; (2) made the discovery procedure recursive by default and wired `## Applies to` glob filtering into the procedure itself (previously defined in conventions but never used); (3) documented that a path argument satisfies the Scope question so the reviewer doesn't re-ask; (4) added an explicit "emit the banner unfenced" note and a 64-column padding rule covering banner content lines (not just borders); (5) removed the security-only threshold exception (51) — security findings now use the same `< 65` default as everything else, eliminating the only cross-section inconsistency in the rubric; (6) replaced the vague "wait only if the user might disagree" guidance with a concrete proceed-vs-wait heuristic; (7) corrected the Common Mistakes TOC anchor from `#️-common-mistakes` (with VS-16) to `#-common-mistakes` to match GitHub's slugifier. User requests: "fix all the findings" from `/review @plugins/reviewing/`, followed by "just remove threshhold from security".
- Added ASCII art to the Output Format: a boxed banner header, horizontal `─` separators around FINDINGS and SUMMARY, file glyphs (`📄`), and severity glyphs (🔴/🟠/🟡/🟢) on each finding bullet. Confidence score still suppressed by default — the glyph is the only visible severity signal. Goal: make the report easier to scan when several findings are listed under the same file. User request: "add some ascii art to the output to make reading easier".
- Initial plugin creation. Single skill (`reviewing`, originally scaffolded as `reviewing-scope`) that asks the user for scope + review type, loads pluggable project rules from `.claude/reviewing-instructions/` (originally `.claude/review-instructions/`), and emits confidence-rated findings in a fixed report format. Inspired in structure by two existing GitHub Actions review workflows but generalized to a language-agnostic, vendor-neutral plugin. Final shape after the same-day iteration: two review types — **General Code Review** (security folded in as one consolidated bullet with categories listed inline and a priority-raise / threshold-drop-to-51 rule for auth/crypto/payment/user-data scopes) and **Document Review** (READMEs, design docs, RFCs, specs, runbooks, any `.md` under `docs/`; audience is a user-supplied parameter defaulting to mixed) plus a free-form **Custom** option. Unified default confidence threshold `< 65` across both types; rubric's 51–75 band split into `51–64` (drop) and `65–75` (report). All inspiration-derived markers (`AGENTS.md`, `CLAUDE.md`, `.claude/**`, `agent-rules/**`, "agent-instructions" type label, "security-focused" type label, agent-only vs dual-audience split) deliberately excluded — this is a general-usage plugin, not a port of the source workflows. Registered in `marketplace.json` and added to repo `README.md` (table row, install command, layout tree). User requests, in order: "create skill plugin taking as a inspiration this two workflows … no mentions of BulkSource … user should mention scope of review … general code review, not swift and swiftui … pluggable with specific instructions from user, such and instructions should be placed by user in .claude/{folder-name}/"; "## Security-Focused Review - incorporate this into ## General Code Review"; "make part about security more concise"; "rename skill to reviewing"; "rename .claude/review-instructions/ to .claude/reviewing-instructions/"; "agent-instructions - don't copy any naming for inspiration materials; we are building general usage plugin"; "set same threshhold 65".

## 2026-05-16 [building-skills]

- Added "Feedback Loops" section to `references/skill-anatomy.md` covering the validator → fix → repeat pattern (plus the plan-validate-execute extension for batch/destructive ops). Discovery via the references blurb in `SKILL.md` only — kept out of the Workflow: Create steps to avoid promoting a subset-applicable technique to mandatory-every-skill status. Brings the skill in line with the official "Implement feedback loops" best practice. Reference: `https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices#implement-feedback-loops`. User request: "i want to add this technique to the skill" + chose option #3 (reference-only pointer) when asked where to place it.

## 2026-05-14 [building-skills]

- Extracted skill into this repo (`pavliuko/claude-plugins`) as a standalone plugin — previously lived only inside host projects. Added `plugins/building-skills/.claude-plugin/plugin.json` and a `marketplace.json` entry so it's installable via `/plugin install building-skills@pavliuko`. User request: "yes" (to adding the missing plugin manifest and marketplace entry).
- Renamed plugin from `managing-skills` to `building-skills` — `managing-` implies lifecycle ops (delete, track, organize) rather than the core action of writing a skill. User request: "rename to building-skills".
- Fixed stale H1 title (`# Managing Claude Tools` → `# Building Skills`), stale "Maintaining this skill" self-reference (`managing-skills` → `building-skills`), stale frontmatter example (`name: managing-example` → `name: <skill-name>`), and placeholder antipattern rows in `templates/skill-template.md` — all left over from the rename. User request: "inspect skill again" / review session.
- Removed the hardcoded `managing-` / `developing-` prefix list from Naming Conventions — it implied those were the only valid gerunds, which contradicted the skill's own name (`building-skills`). Replaced with the pattern `<gerund>-<object>` and a table comparing skills vs commands. User feedback: "we abuse managing and developing words" and "category-prefix + gerund for skills — this is wrong".
- Rewrote `## Naming Conventions` in `skill-anatomy.md` as a comparison table (Skills vs Commands) — the previous bullet-list structure was hard to read after multiple edits. User request: "update structure of ## Naming Conventions it is hard to read now".
- Moved CHANGELOG instructions from `SKILL.md` to repo-root `CLAUDE.md` and consolidated per-plugin changelogs into a single repo-root `CHANGELOG.md` — per-plugin files were redundant once the rule became repo-wide. User request: "move instructions about CHANGELOG.md from skill to CLAUDE.md" and "let's combine changelog in a single file and move it to the root of the repo".

## 2026-05-14 [building-skills] (session 3)

- Restructured `references/skill-anatomy.md` to fold the three standalone directory sections (`The references/ Directory`, `The templates/ Directory`, `The scripts/ Directory`) into the Progressive Disclosure Patterns section — they only exist as the mechanism of progressive disclosure, not as independent features. Added a role-summary table (read on demand vs executed on demand) to make the `scripts/` distinction explicit. Moved Progressive Disclosure before Single-File Layout since single-file's key limitation is inability to use it. Added "Executed on demand" bullet to Token Budget Rules of Thumb. User question: "can they exist out of progressive disclosure approach?" followed by "yes" to restructure.

## 2026-05-14 [building-skills] (session 2)

- Aligned progressive disclosure content with the official Anthropic docs (`platform.claude.com/docs/…/best-practices#progressive-disclosure-patterns`). Five changes:
  1. Dropped "ranked by how often we use them in this repo" framing in `SKILL.md` — neutral guidance shouldn't encode repo-internal opinion.
  2. Added explicit "don't mix" rule to `SKILL.md`'s pattern list.
  3. Expanded the one-level-deep bullet in `SKILL.md` into its own note with a bad/good tree example — matches the prominence the official docs give this constraint.
  4. Added `scripts/` to the canonical directory tree in `skill-anatomy.md` — docs show it as a first-class peer alongside `references/` and `templates/`.
  5. Expanded all three pattern descriptions in `skill-anatomy.md` with concrete directory-tree + markdown examples — previously each was a 1–2 sentence stub; the official docs show full examples for each. Reference: user request "implement actionable recommendations" from gap analysis against the official docs.

## 2026-05-14 [building-skills] (session 1)

- Changed the example `paths` glob in `references/skill-anatomy.md` from `**/*.swift` to `**/*.md` — the Swift example was misleading when the skill was used in non-Swift projects. A neutral example keeps the canonical version portable across host projects.
- Changed the Common Mistakes rule: scaffolded skills now leave the section empty at creation (header only, no rows). Updated step 6 of the Create workflow, the self-review checklist, and added a Common Mistakes row about the new rule itself. Also promoted Workflow: Edit's final step into its own `### 8. Self-review` heading. The template was intentionally left untouched. User requests: "update @.claude/skills/managing-skills/ to leave this section empty during skill creation"; "add ### 8. Self-review to ## Workflow: Edit"; "revert @.claude/skills/managing-skills/templates/skill-template.md changes".

## 2026-05-13 [building-skills]

- Initial creation as `managing-claude-tools` skill (SKILL.md + references + templates) — to provide a single place that owns skill/command authoring so the model stops writing `SKILL.md` files freehand. User request: "inspect skills we have across the project, learn best practices and create skill to build and edit skills and commands as special case of the skill; use Progressive disclosure approach".
- Renamed templates from `*.template` to `*-template.md` — keeps markdown tooling working. User: "yes" (to a recommendation to rename).
- Merged `slash-command-anatomy.md` into `skill-anatomy.md` — same primitive, only layout differs. User: "do we really need to separate skill from command by concept… what are other differences?"
- Reframed "Skill vs Slash Command" as "ask the user" — both axes (layout, invocation mode) belong to the user, not the agent. User: "no need to make decision. Agent needs to get this information from user, if agent not sure it should stop and ask".
- Reworded the skill description's negative constraint to name file paths instead of "skill descriptions" — user feedback: "'skill descriptions' here sounds vague".
- Dropped the standalone `templates/command-template.md` and consolidated to one `templates/skill-template.md` — user feedback: "do we still need separate templates?" then "yes" to merging.
- Dropped the "thin invoker" pattern — user request: "Thin invoker - i don't want to make such a commands anymore".
- Renamed skill from `managing-claude-tools` to `managing-skills` — shorter, no vendor word. User request: "rename from managing-claude-tools to managing-skills".
- Resolved contradiction between Critical Rule #3 and the Progressive Disclosure guidance — CR #3 forbade putting helper docs in `docs/` / `agent-rules/` "unless the user asks", while the disclosure section instructs extracting truly cross-cutting content there directly. Scoped CR #3 to skill-specific docs only.

## 2026-04-28 [skill-suggestion]

- Initial plugin created — `UserPromptSubmit` hook that scores user prompts against a project-defined skill catalog (`rules.json`) and injects a ranked suggestion banner into Claude's context. Commit: `24713dd`.
- Rewrote README from scratch — original was auto-generated and unclear. Commit: `130bbf9`.
- Expanded README with detailed explanations of project skills vs plugin skills — users were unclear on the distinction. Commit: `3178603`.
- Expanded README install steps with a ready-to-paste `rules.json` starter — users had no starting point after installing the hook. Commit: `4ebe736`.

## 2026-04-28 [swift-concurrency-reviewer]

- Initial migration into `pavliuko/claude-plugins` marketplace — moved from the standalone repo `https://github.com/pavliuko/swift-concurrency-reviewer` to consolidate all plugins in one place. Commit: `410a13a`.
- Moved `plugins/swift-concurrency-reviewer/AGENTS.md` to repo-root `CLAUDE.md` — plugin-level guidance belongs at the repo root so it applies across all plugins. Commit: `6141dbb`.
