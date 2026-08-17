#!/bin/bash

# Skill Suggestion Hook (UserPromptSubmit)
#
# Reads the submitted user prompt from stdin (JSON event payload), scores every
# skill defined in rules.json, and emits a ranked suggestion banner via the
# UserPromptSubmit hook's `hookSpecificOutput.additionalContext` JSON contract
# so Claude Code injects it into the model's context for this turn.
#
# Scoring per skill:
#   score = keywords*KW + intentPatterns*IW + pathPatterns*PW
# A skill is suggested when score >= confidenceThreshold AND no excludePattern
# matches. Weights and thresholds come from rules.json (.config.scoring).
#
# A skill entry with `"always": true` opts out of all of the above: it needs no
# promptTriggers, ignores excludePatterns, and does not consume a
# maxSkillsPerPrompt slot. Such skills are emitted in their own REQUIRED section
# phrased as an instruction to invoke them, not as a suggestion to weigh — the
# user pinned them precisely because relevance is not in question.
#
# Inputs:  stdin  — UserPromptSubmit JSON ({ "prompt": "..." , ... })
#          files  — $HOME/.claude/skill-suggestion/rules.json          (user scope)
#                   $CLAUDE_PROJECT_DIR/.claude/skill-suggestion/rules.json (project scope)
# Outputs: stdout — JSON envelope with hookSpecificOutput.additionalContext
#                   (when no skills match, a systemMessage-only envelope tells
#                   the user; the model context is untouched)
#          files  — skill-suggestion.log in each scope that has a rules.json
#                   (both logs are appended when both scopes exist)
# Exit:    always 0 — never block the prompt.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Rules come from two scopes, merged: user-scope rules apply in every project,
# project rules add to them and win on skill-name collisions. Config keys are
# deep-merged with project values taking precedence.
USER_DATA_DIR="$HOME/.claude/skill-suggestion"
PROJECT_DATA_DIR="$PROJECT_DIR/.claude/skill-suggestion"
USER_RULES="$USER_DATA_DIR/rules.json"
PROJECT_RULES="$PROJECT_DATA_DIR/rules.json"

# Without any rules file there is nothing to score against; bail silently so
# the hook never disrupts the user turn when nobody has opted in.
if [ ! -f "$USER_RULES" ] && [ ! -f "$PROJECT_RULES" ]; then
    exit 0
fi

# Log next to each scope's rules file: the user log when user rules exist,
# the project log when project rules exist — both when both do. A scope
# without rules gets no log, so a user-scope-only setup never creates
# .claude/ directories inside arbitrary projects.
USER_LOG=""
PROJECT_LOG=""
if [ -f "$USER_RULES" ]; then
    USER_LOG="$USER_DATA_DIR/skill-suggestion.log"
    mkdir -p "$USER_DATA_DIR"
fi
if [ -f "$PROJECT_RULES" ]; then
    PROJECT_LOG="$PROJECT_DATA_DIR/skill-suggestion.log"
    mkdir -p "$PROJECT_DATA_DIR"
fi

# Appends a line to every active scope log.
log_line() {
    [ -n "$USER_LOG" ] && echo "$1" >> "$USER_LOG"
    [ -n "$PROJECT_LOG" ] && echo "$1" >> "$PROJECT_LOG"
    return 0
}

# Emits a scope's rules JSON, treating a missing or malformed file as an
# empty ruleset so one broken scope never takes down the other.
read_rules() {
    if [ -f "$1" ] && jq -e . "$1" >/dev/null 2>&1; then
        cat "$1"
    else
        echo '{}'
    fi
}

# Merge the two scopes into a single rules document that the rest of the
# script reads. Each skill entry is tagged with its origin scope so the
# banner can render the right SKILL.md path (~/.claude vs .claude).
SKILL_RULES=$(mktemp "${TMPDIR:-/tmp}/skill-suggestion-rules.XXXXXX")
trap 'rm -f "$SKILL_RULES"' EXIT

jq -n \
    --argjson user "$(read_rules "$USER_RULES")" \
    --argjson project "$(read_rules "$PROJECT_RULES")" \
    '
    def tagged(rules; o): (rules.skills // {}) | with_entries(.value.origin = o);
    {
        skills: (tagged($user; "user") + tagged($project; "project")),
        config: (($user.config // {}) * ($project.config // {}))
    }
    ' > "$SKILL_RULES"

# Build the set of plugins enabled across all settings scopes Claude Code
# reads (user, project, project-local). Skills whose rules.json entry has a
# `plugin` field are gated by this set: if no scope enables the plugin, the
# skill is skipped (Claude Code wouldn't be able to invoke it anyway).
ENABLED_PLUGINS_LIST=""
for settings_file in \
    "$HOME/.claude/settings.json" \
    "$PROJECT_DIR/.claude/settings.json" \
    "$PROJECT_DIR/.claude/settings.local.json"
do
    [ -f "$settings_file" ] || continue
    enabled_in_scope=$(jq -r '
        .enabledPlugins // {}
        | to_entries
        | map(select(.value == true) | .key)
        | .[]
    ' "$settings_file" 2>/dev/null || true)
    if [ -n "$enabled_in_scope" ]; then
        ENABLED_PLUGINS_LIST=$(printf '%s\n%s' "$ENABLED_PLUGINS_LIST" "$enabled_in_scope" | sed '/^$/d' | sort -u)
    fi
done

is_plugin_enabled() {
    [ -z "$ENABLED_PLUGINS_LIST" ] && return 1
    echo "$ENABLED_PLUGINS_LIST" | grep -qxF "$1"
}

# Read and validate the hook event payload. Bail silently on malformed JSON or
# an empty prompt so we never disrupt the user turn.
EVENT_DATA=$(cat)

if ! echo "$EVENT_DATA" | jq -e . >/dev/null 2>&1; then
    exit 0
fi

USER_PROMPT=$(echo "$EVENT_DATA" | jq -r '.prompt // empty' 2>/dev/null)

if [ -z "$USER_PROMPT" ]; then
    exit 0
fi

log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Suggesting skills for prompt: ${USER_PROMPT:0:80}"

# Lowercase copy used by every case-insensitive substring/regex match below.
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

# Parallel arrays: MATCHED_SKILLS[i] has score MATCHED_SCORES[i].
MATCHED_SKILLS=()
MATCHED_SCORES=()

# Skills flagged `"always": true`. They have no score, so they keep their own
# list: rendered ahead of the scored matches and outside the display cap.
PINNED_SKILLS=()

# Scoring weights and thresholds (with sensible fallbacks if rules.json omits
# them). HIGH/MEDIUM only affect the displayed confidence label.
KEYWORD_WEIGHT=$(jq -r '.config.scoring.keywordWeight // 2' "$SKILL_RULES")
INTENT_WEIGHT=$(jq -r '.config.scoring.intentWeight // 3' "$SKILL_RULES")
PATH_WEIGHT=$(jq -r '.config.scoring.pathWeight // 2' "$SKILL_RULES")
CONFIDENCE_THRESHOLD=$(jq -r '.config.scoring.confidenceThreshold // 3' "$SKILL_RULES")
HIGH_CONFIDENCE=$(jq -r '.config.scoring.highConfidenceScore // 6' "$SKILL_RULES")
MEDIUM_CONFIDENCE=$(jq -r '.config.scoring.mediumConfidenceScore // 4' "$SKILL_RULES")

# Counts case-insensitive fixed-string keyword hits in the prompt.
# Result is written to the global KEYWORD_MATCH_COUNT (bash 3 has no easy way
# to return integers, and this script must run on macOS's stock bash).
KEYWORD_MATCH_COUNT=0
count_keyword_matches() {
    local skill_name=$1
    KEYWORD_MATCH_COUNT=0
    local keywords=$(jq -r --arg name "$skill_name" '.skills[$name].promptTriggers.keywords[]?' "$SKILL_RULES" 2>/dev/null)

    while IFS= read -r keyword; do
        if [ -n "$keyword" ]; then
            keyword_lower=$(echo "$keyword" | tr '[:upper:]' '[:lower:]')
            if echo "$PROMPT_LOWER" | grep -qiF "$keyword_lower"; then
                ((KEYWORD_MATCH_COUNT++)) || true
            fi
        fi
    done <<< "$keywords"
}

# Counts extended-regex intent-pattern hits in the prompt.
# Patterns express "shape of intent" (e.g. "(add|fix).*(haptic)") and are
# weighted higher than keywords because they imply a verb+object pairing.
INTENT_MATCH_COUNT=0
count_intent_matches() {
    local skill_name=$1
    INTENT_MATCH_COUNT=0
    local patterns=$(jq -r --arg name "$skill_name" '.skills[$name].promptTriggers.intentPatterns[]?' "$SKILL_RULES" 2>/dev/null)

    if [ -z "$patterns" ]; then
        return
    fi

    while IFS= read -r pattern; do
        if [ -n "$pattern" ]; then
            if echo "$PROMPT_LOWER" | grep -qiE "$pattern"; then
                ((INTENT_MATCH_COUNT++)) || true
            fi
        fi
    done <<< "$patterns"
}

# Extract file-path-like tokens from the prompt (e.g. `Foo.swift`, `@path/to/file.json`).
# The leading `@` is stripped so the remaining string compares cleanly against
# glob patterns like `**/*.swift`.
PROMPT_PATHS=()
while IFS= read -r path; do
    [ -n "$path" ] && PROMPT_PATHS+=("$path")
done < <(echo "$USER_PROMPT" \
    | grep -oE '@?[A-Za-z0-9_./-]+\.[A-Za-z0-9]{1,5}\b' \
    | sed 's/^@//')

# Enable glob features used by `[[ path == pattern ]]` below:
#   globstar    — `**` recursive matching
#   extglob     — extended patterns like `*(...)`
#   nullglob    — empty expansion when nothing matches
#   nocaseglob  — case-insensitive glob matching
shopt -s extglob globstar nullglob nocaseglob 2>/dev/null || true

# Counts how many of the skill's pathPatterns match any path mentioned in the
# prompt. Each pattern contributes at most once, even if multiple prompt paths
# match it, to keep scoring proportional to pattern coverage rather than
# prompt verbosity.
PATH_MATCH_COUNT=0
count_path_matches() {
    local skill_name=$1
    PATH_MATCH_COUNT=0
    [ ${#PROMPT_PATHS[@]} -eq 0 ] && return

    local patterns=$(jq -r --arg name "$skill_name" '.skills[$name].promptTriggers.pathPatterns[]?' "$SKILL_RULES" 2>/dev/null)
    [ -z "$patterns" ] && return

    while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue
        for prompt_path in "${PROMPT_PATHS[@]}"; do
            # shellcheck disable=SC2053
            if [[ "$prompt_path" == $pattern ]]; then
                ((PATH_MATCH_COUNT++)) || true
                break  # one match per pattern is enough
            fi
        done
    done <<< "$patterns"
}

# Returns 0 (match) if any excludePattern substring appears in the prompt.
# Used to veto a skill regardless of its score — e.g. suppressing a "create PR"
# skill when the prompt actually says "review PR".
matches_exclusion() {
    local skill_name=$1
    local patterns=$(jq -r --arg name "$skill_name" '.skills[$name].promptTriggers.excludePatterns[]?' "$SKILL_RULES" 2>/dev/null)

    if [ -z "$patterns" ]; then
        return 1
    fi

    while IFS= read -r pattern; do
        if [ -n "$pattern" ]; then
            pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
            if echo "$PROMPT_LOWER" | grep -qiF "$pattern_lower"; then
                return 0
            fi
        fi
    done <<< "$patterns"

    return 1
}

# Score every skill defined in rules.json. Skills that score above the
# threshold and don't trip an exclusion are collected for display; everything
# else is logged for debugging.
while IFS= read -r skill; do
    [ -z "$skill" ] && continue

    plugin=$(jq -r --arg name "$skill" '.skills[$name].plugin // empty' "$SKILL_RULES")
    if [ -n "$plugin" ] && ! is_plugin_enabled "$plugin"; then
        log_line "  ⊘ Skipped (plugin not in enabledPlugins): $skill ($plugin)"
        continue
    fi

    # Pinned skills short-circuit scoring entirely: no keyword/intent/path
    # counting, no exclusion check. "Always" means always.
    if [ "$(jq -r --arg name "$skill" '.skills[$name].always // false' "$SKILL_RULES")" = "true" ]; then
        PINNED_SKILLS+=("$skill")
        log_line "  📌 Required (always, sent as an instruction): $skill"
        continue
    fi

    count_keyword_matches "$skill"
    count_intent_matches "$skill"
    count_path_matches "$skill"

    SCORE=$((KEYWORD_MATCH_COUNT * KEYWORD_WEIGHT + INTENT_MATCH_COUNT * INTENT_WEIGHT + PATH_MATCH_COUNT * PATH_WEIGHT))

    if [ $SCORE -gt 0 ]; then
        if matches_exclusion "$skill"; then
            log_line "  ✗ Excluded: $skill (score=$SCORE, matched exclusion pattern)"
            continue
        fi

        if [ $SCORE -ge $CONFIDENCE_THRESHOLD ]; then
            MATCHED_SKILLS+=("$skill")
            MATCHED_SCORES+=("$SCORE")
            log_line "  ✓ Matched: $skill (score=$SCORE, keywords=$KEYWORD_MATCH_COUNT, intents=$INTENT_MATCH_COUNT, paths=$PATH_MATCH_COUNT)"
        else
            log_line "  ○ Below threshold: $skill (score=$SCORE < $CONFIDENCE_THRESHOLD)"
        fi
    fi
done < <(jq -r '.skills | keys[]' "$SKILL_RULES")

# Sort matched skills by score descending. We build "score:index" tokens, sort
# them numerically by the score field, then rebuild the parallel arrays in the
# new order — `sort` does the heavy lifting since bash arrays don't sort natively.
if [ ${#MATCHED_SKILLS[@]} -gt 1 ]; then
    SORT_INPUT=()
    for i in "${!MATCHED_SKILLS[@]}"; do
        SORT_INPUT+=("${MATCHED_SCORES[$i]}:$i")
    done

    SORTED_SKILLS=()
    SORTED_SCORES=()
    while IFS=: read -r _ idx; do
        if [ -n "$idx" ]; then
            SORTED_SKILLS+=("${MATCHED_SKILLS[$idx]}")
            SORTED_SCORES+=("${MATCHED_SCORES[$idx]}")
        fi
    done < <(printf '%s\n' "${SORT_INPUT[@]}" | sort -t: -k1 -rn)

    MATCHED_SKILLS=("${SORTED_SKILLS[@]}")
    MATCHED_SCORES=("${SORTED_SCORES[@]}")
fi

if [ ${#MATCHED_SKILLS[@]} -eq 0 ] && [ ${#PINNED_SKILLS[@]} -eq 0 ]; then
    log_line "  No skills matched"
    # Tell the user in the transcript that the hook ran but found nothing.
    # No additionalContext — the model's context stays untouched.
    jq -n '{systemMessage: "💡 Skill suggestion: no matching skills for this prompt"}'
    exit 0
fi

# Cap the number of scored skills shown in detail. Anything beyond MAX_SKILLS is
# rendered as a one-line "also matched" footer so the banner stays compact.
# Pinned skills are exempt from the cap — they are always shown in full.
MAX_SKILLS=$(jq -r '.config.maxSkillsPerPrompt // 3' "$SKILL_RULES")

ALL_MATCHED_SKILLS=()
CUTOFF_SKILLS=()
CUTOFF_SCORES=()

# Guarded: bash 3.2 under `set -u` rejects "${empty[@]}" as unbound, and a
# pinned-only run reaches here with no scored matches at all.
if [ ${#MATCHED_SKILLS[@]} -gt 0 ]; then
    ALL_MATCHED_SKILLS=("${MATCHED_SKILLS[@]}")
    ALL_MATCHED_SCORES=("${MATCHED_SCORES[@]}")

    if [ ${#ALL_MATCHED_SKILLS[@]} -gt "$MAX_SKILLS" ]; then
        CUTOFF_SKILLS=("${ALL_MATCHED_SKILLS[@]:$MAX_SKILLS}")
        CUTOFF_SCORES=("${ALL_MATCHED_SCORES[@]:$MAX_SKILLS}")
    fi

    MATCHED_SKILLS=("${ALL_MATCHED_SKILLS[@]:0:$MAX_SKILLS}")
    MATCHED_SCORES=("${ALL_MATCHED_SCORES[@]:0:$MAX_SKILLS}")
fi

# Renders one skill's banner entry. Called with a score for scored matches and
# without one for pinned skills, which have no score to report.
#
# The two forms are deliberately worded differently: a scored match is a guess
# about this prompt and gets a confidence band, while a pinned skill is a
# standing instruction and gets an imperative.
render_skill() {
    local skill=$1
    local score=${2:-}
    local description confidence emoji score_label plugin origin

    description=$(jq -r --arg name "$skill" '.skills[$name].description' "$SKILL_RULES")
    plugin=$(jq -r --arg name "$skill" '.skills[$name].plugin // empty' "$SKILL_RULES")

    if [ -z "$score" ]; then
        printf '📌 %s\n' "$skill"
        printf '   Description: %s\n' "$description"
        printf '   Status: REQUIRED — invoke once per session, then stays in force\n'
    else
        # Confidence label is purely cosmetic — it does not gate inclusion.
        if [ "$score" -ge "$HIGH_CONFIDENCE" ]; then
            confidence="HIGH"
            emoji="🟢"
        elif [ "$score" -ge "$MEDIUM_CONFIDENCE" ]; then
            confidence="MEDIUM"
            emoji="🟡"
        else
            confidence="LOW"
            emoji="🟠"
        fi
        score_label="score: $score"

        printf '📚 %s\n' "$skill"
        printf '   Description: %s\n' "$description"
        printf '   Confidence: %s %s (%s)\n' "$emoji" "$confidence" "$score_label"
    fi

    if [ -n "$plugin" ]; then
        printf '   Plugin: %s\n' "$plugin"
        printf '   Invoke: %s\n' "$skill"
    else
        # Origin scope decides where the SKILL.md lives: user-scope skills
        # sit under ~/.claude/skills, project skills under .claude/skills.
        origin=$(jq -r --arg name "$skill" '.skills[$name].origin // "project"' "$SKILL_RULES")
        if [ "$origin" = "user" ]; then
            printf '   Path: ~/.claude/skills/%s/SKILL.md\n' "$skill"
        else
            printf '   Path: .claude/skills/%s/SKILL.md\n' "$skill"
        fi
    fi
    echo ""
}

# Build the suggestion banner into a string. We emit it as
# `hookSpecificOutput.additionalContext` in a JSON envelope (the documented
# UserPromptSubmit hook contract) rather than as raw stdout text — Claude Code
# injects `additionalContext` into the model's context for this turn.
CONTEXT=$({
    echo ""

    # Pinned skills get their own section, ahead of and worded unlike the
    # scored matches: an instruction to carry out, not a list to consider.
    # Either section is omitted entirely when it has nothing in it.
    if [ ${#PINNED_SKILLS[@]} -gt 0 ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📌 REQUIRED SKILLS — MUST BE ACTIVE THIS SESSION"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        for i in "${!PINNED_SKILLS[@]}"; do
            render_skill "${PINNED_SKILLS[$i]}"
        done

        echo "❗ Not suggestions — pinned by the user's config, so don't skip them as"
        echo "   irrelevant. Invoke each one above via the Skill tool as your first"
        echo "   action, unless its instructions are already in your context from this"
        echo "   session: then keep following them, don't re-invoke."
        echo ""
    fi

    if [ ${#MATCHED_SKILLS[@]} -gt 0 ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎯 SUGGESTED SKILLS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        for i in "${!MATCHED_SKILLS[@]}"; do
            render_skill "${MATCHED_SKILLS[$i]}" "${MATCHED_SCORES[$i]}"
        done

        if [ ${#CUTOFF_SKILLS[@]} -gt 0 ]; then
            echo "📋 Also matched (not shown above):"
            for i in "${!CUTOFF_SKILLS[@]}"; do
                skill="${CUTOFF_SKILLS[$i]}"
                score="${CUTOFF_SCORES[$i]}"
                printf '   • %s (score: %s)\n' "$skill" "$score"
            done
            echo ""
        fi

        echo "💡 Consider using these skills if they're relevant to this task."
        echo "   Invoke a skill by name via the Skill tool."
        echo ""
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
})

# Short transcript-visible notice (user sees this, model does not). Required and
# suggested are reported separately so it's clear at a glance which skills were
# handed to Claude as an instruction and which as a hint.
SYSTEM_MESSAGE=""
if [ ${#PINNED_SKILLS[@]} -gt 0 ]; then
    SYSTEM_MESSAGE="📌 Required skills: ${PINNED_SKILLS[*]}"
fi
if [ ${#ALL_MATCHED_SKILLS[@]} -gt 0 ]; then
    [ -n "$SYSTEM_MESSAGE" ] && SYSTEM_MESSAGE="$SYSTEM_MESSAGE · "
    # Braces are load-bearing: "$SYSTEM_MESSAGE💡" parses the emoji as part of
    # the variable name and dies under `set -u`.
    SYSTEM_MESSAGE="${SYSTEM_MESSAGE}💡 Suggested skills: ${ALL_MATCHED_SKILLS[*]}"
fi

# Hand the buffers to jq so it handles all JSON escaping (quotes, newlines, etc.).
#   additionalContext — injected into the model's context (Claude sees it)
#   systemMessage     — shown in the transcript only (user sees it)
jq -n \
    --arg ctx "$CONTEXT" \
    --arg msg "$SYSTEM_MESSAGE" \
    '{
        hookSpecificOutput: {
            hookEventName: "UserPromptSubmit",
            additionalContext: $ctx
        },
        systemMessage: $msg
    }'

# Final picks for this run; pairs with the per-skill scoring trace above.
if [ ${#PINNED_SKILLS[@]} -gt 0 ]; then
    log_line "  → Required (instructed): ${PINNED_SKILLS[*]}"
fi
if [ ${#ALL_MATCHED_SKILLS[@]} -gt 0 ]; then
    log_line "  → Suggested (optional): ${ALL_MATCHED_SKILLS[*]}"
fi

exit 0
