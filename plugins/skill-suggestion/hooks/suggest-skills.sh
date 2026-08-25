#!/bin/bash

# Skill Suggestion Hook (UserPromptSubmit)
#
# Scores every non-required skill in rules.json against the submitted prompt and
# emits a ranked suggestion banner. Required (`"required": true`) skills are skipped
# here — require-skills.sh delivered them at SessionStart.
#
# Scoring per skill:
#   score = keywords*KW + intentPatterns*IW + pathPatterns*PW
# A skill is suggested when score >= confidenceThreshold AND no excludePattern
# matches. Weights and thresholds come from rules.json (.config.scoring).
#
# Inputs:  stdin  — UserPromptSubmit JSON ({ "prompt": "..." , ... })
#          files  — rules.json in the user and/or project scope (see lib.sh)
# Outputs: stdout — JSON envelope with hookSpecificOutput.additionalContext
#                   (when nothing matches, a systemMessage-only envelope tells
#                   the user; the model context is untouched)
#          files  — each scope's activation log (default skill-suggestion.log next to its rules.json; see config.logPath / config.logActivations)
# Exit:    always 0 — never blocks the prompt.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

USER_PROMPT=$(echo "$EVENT_DATA" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$USER_PROMPT" ] && exit 0

log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Suggesting skills for prompt: ${USER_PROMPT:0:80}"
warn_unknown_config

# Lowercase copy used by every case-insensitive substring/regex match below.
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

# Parallel arrays: MATCHED_SKILLS[i] has score MATCHED_SCORES[i].
MATCHED_SKILLS=()
MATCHED_SCORES=()

# Scoring weights and thresholds (with sensible fallbacks if rules.json omits
# them). The HIGH/MEDIUM display cut-offs live in lib.sh with the renderer.
KEYWORD_WEIGHT=$(jq -r '.config.scoring.keywordWeight // 2' "$SKILL_RULES")
INTENT_WEIGHT=$(jq -r '.config.scoring.intentWeight // 3' "$SKILL_RULES")
PATH_WEIGHT=$(jq -r '.config.scoring.pathWeight // 2' "$SKILL_RULES")
CONFIDENCE_THRESHOLD=$(jq -r '.config.scoring.confidenceThreshold // 3' "$SKILL_RULES")

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

# Score every non-required skill. Skills that clear the threshold and don't trip an
# exclusion are collected for display; everything else is logged for debugging.
while IFS= read -r skill; do
    [ -z "$skill" ] && continue

    if skill_is_required "$skill"; then
        log_line "  ⊘ Required (delivered at SessionStart): $skill"
        continue
    fi

    skill_is_available "$skill" || continue

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
done < <(skill_names)

if [ ${#MATCHED_SKILLS[@]} -eq 0 ]; then
    log_line "  No skills matched"
    # Tell the user in the transcript that the hook ran but found nothing.
    # No additionalContext — the model's context stays untouched.
    jq -n '{systemMessage: "💡 Skill suggestion: no matching skills for this prompt"}'
    exit 0
fi

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

# Cap the number of skills shown in detail. Anything beyond MAX_SKILLS is
# rendered as a one-line "also matched" footer so the banner stays compact.
MAX_SKILLS=$(jq -r '.config.maxSkillsPerPrompt // 3' "$SKILL_RULES")

ALL_MATCHED_SKILLS=("${MATCHED_SKILLS[@]}")
ALL_MATCHED_SCORES=("${MATCHED_SCORES[@]}")

CUTOFF_SKILLS=()
CUTOFF_SCORES=()
if [ ${#ALL_MATCHED_SKILLS[@]} -gt "$MAX_SKILLS" ]; then
    CUTOFF_SKILLS=("${ALL_MATCHED_SKILLS[@]:$MAX_SKILLS}")
    CUTOFF_SCORES=("${ALL_MATCHED_SCORES[@]:$MAX_SKILLS}")
fi

MATCHED_SKILLS=("${ALL_MATCHED_SKILLS[@]:0:$MAX_SKILLS}")
MATCHED_SCORES=("${ALL_MATCHED_SCORES[@]:0:$MAX_SKILLS}")

CONTEXT=$({
    echo ""
    echo "$SEP"
    echo "🎯 SUGGESTED SKILLS"
    echo "$SEP"
    echo ""

    for i in "${!MATCHED_SKILLS[@]}"; do
        render_skill "${MATCHED_SKILLS[$i]}" "${MATCHED_SCORES[$i]}"
    done

    if [ ${#CUTOFF_SKILLS[@]} -gt 0 ]; then
        echo "📋 Also matched (not shown above):"
        for i in "${!CUTOFF_SKILLS[@]}"; do
            printf '   • %s (score: %s)\n' "${CUTOFF_SKILLS[$i]}" "${CUTOFF_SCORES[$i]}"
        done
        echo ""
    fi

    echo "💡 Consider using these skills if they're relevant to this task."
    echo "   Invoke a skill by name via the Skill tool."
    echo ""
    echo "$SEP"
})

emit_envelope "UserPromptSubmit" "$CONTEXT" "💡 Suggested skills: ${ALL_MATCHED_SKILLS[*]}"

log_line "  → Suggested (optional): ${ALL_MATCHED_SKILLS[*]}"

exit 0
