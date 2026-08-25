#!/bin/bash

# Shared library for the skill-suggestion hooks. Sourced by:
#   require-skills.sh  (SessionStart)   — delivers `"required": true` skills once
#   suggest-skills.sh  (UserPromptSubmit) — scores every other skill per prompt
#
# Everything here is what both events need identically: locating and merging the
# two rules scopes, the per-scope log, the enabledPlugins gate, the per-skill
# renderer, and the JSON envelope. Scoring lives only in suggest-skills.sh.
#
# Sourcing this file has side effects on purpose — it reads stdin, exits 0 when
# there is nothing to do, and registers an EXIT trap in the caller's shell:
#   $SKILL_RULES  path to the merged rules document (temp file, auto-removed)
#   $EVENT_DATA   the raw hook payload, already validated as JSON
# A caller that reaches the line after `source` has a usable ruleset.

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

# Emits a scope's rules JSON, treating a missing or malformed file as an
# empty ruleset so one broken scope never takes down the other.
read_rules() {
    if [ -f "$1" ] && jq -e . "$1" >/dev/null 2>&1; then
        cat "$1"
    else
        echo '{}'
    fi
}

# Resolves one scope's log file from that scope's own rules.json — not from
# the merged config, so a project can neither silence nor redirect the user
# log: each scope owns its trace. Prints nothing (no log) when the scope has
# no rules or sets `config.logActivations: false`.
#   $1 rules file
#   $2 scope root — a relative `config.logPath` resolves against it
#   $3 default logPath, relative to $2 (next to the scope's rules.json)
# `~/` and absolute paths are honoured as written. The directory is created
# only when the log is actually enabled, so a user-scope-only setup still
# never creates .claude/ directories inside arbitrary projects.
resolve_log() {
    local rules=$1 root=$2 default=$3 enabled path
    [ -f "$rules" ] || return 0
    # Not `// true`: jq's alternative operator treats false as missing.
    enabled=$(read_rules "$rules" | jq -r '.config.logActivations | if . == false then "false" else "true" end')
    [ "$enabled" = "false" ] && return 0
    path=$(read_rules "$rules" | jq -r --arg default "$default" '.config.logPath // $default')
    case "$path" in
        /*) ;;
        "~/"*) path="$HOME/${path#\~/}" ;;
        *) path="$root/$path" ;;
    esac
    mkdir -p "$(dirname "$path")"
    echo "$path"
}

USER_LOG=$(resolve_log "$USER_RULES" "$HOME/.claude" "skill-suggestion/skill-suggestion.log")
PROJECT_LOG=$(resolve_log "$PROJECT_RULES" "$PROJECT_DIR" ".claude/skill-suggestion/skill-suggestion.log")

# Appends a line to every active scope log.
log_line() {
    [ -n "$USER_LOG" ] && echo "$1" >> "$USER_LOG"
    [ -n "$PROJECT_LOG" ] && echo "$1" >> "$PROJECT_LOG"
    return 0
}

# The config keys the hooks read. Anything else under `config` is a typo or a
# leftover from another tool and would otherwise be ignored without a trace —
# exactly how a dead `logPath` sat in a rules.json for months.
KNOWN_CONFIG_KEYS='["maxSkillsPerPrompt","logActivations","logPath","scoring"]'
KNOWN_SCORING_KEYS='["keywordWeight","intentWeight","pathWeight","confidenceThreshold","highConfidenceScore","mediumConfidenceScore"]'

# Logs one warning per unknown config key in a scope's rules.json.
#   $1 rules file   $2 scope label for the log line ("user" / "project")
# Called by each event after its header line so the warning sits inside that
# run's block in the log rather than above it.
warn_unknown_config_keys() {
    local rules=$1 scope=$2 key
    [ -f "$rules" ] || return 0
    while IFS= read -r key; do
        [ -n "$key" ] && log_line "  ⚠ Unknown config key in $scope rules: $key"
    done < <(read_rules "$rules" | jq -r \
        --argjson top "$KNOWN_CONFIG_KEYS" --argjson scoring "$KNOWN_SCORING_KEYS" '
        ((.config // {}) | keys[] | select(IN($top[]) | not)),
        ((.config.scoring // {}) | keys[] | select(IN($scoring[]) | not) | "scoring." + .)
    ')
}

# Convenience for the callers: warn for both scopes in one line.
warn_unknown_config() {
    warn_unknown_config_keys "$USER_RULES" "user"
    warn_unknown_config_keys "$PROJECT_RULES" "project"
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

# Returns 0 when the skill is usable at all: either it isn't plugin-backed, or
# its plugin is enabled somewhere. Logs the skip so the trace explains a
# missing skill. Both events gate on this identically.
skill_is_available() {
    local skill=$1 plugin
    plugin=$(jq -r --arg name "$skill" '.skills[$name].plugin // empty' "$SKILL_RULES")
    if [ -n "$plugin" ] && ! is_plugin_enabled "$plugin"; then
        log_line "  ⊘ Skipped (plugin not in enabledPlugins): $skill ($plugin)"
        return 1
    fi
    return 0
}

# Returns 0 for a `"required": true` entry. The two events split on this:
# required skills belong to SessionStart, everything else to UserPromptSubmit.
skill_is_required() {
    [ "$(jq -r --arg name "$1" '.skills[$name].required // false' "$SKILL_RULES")" = "true" ]
}

# Iterates every skill name in the merged rules.
skill_names() {
    jq -r '.skills | keys[]' "$SKILL_RULES"
}

# The banner rule, used as a section divider by both events.
SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Confidence cut-offs. Only the scored renderer uses them, but they live here so
# render_skill() stays whole rather than half in each caller.
HIGH_CONFIDENCE=$(jq -r '.config.scoring.highConfidenceScore // 6' "$SKILL_RULES")
MEDIUM_CONFIDENCE=$(jq -r '.config.scoring.mediumConfidenceScore // 4' "$SKILL_RULES")

# Renders one skill's banner entry. Called with a score for scored matches and
# without one for required skills, which have no score to report.
#
# The two forms are deliberately worded differently: a scored match is a guess
# about this prompt and gets a confidence band, while a required skill is a
# standing instruction and gets an imperative.
render_skill() {
    local skill=$1
    local score=${2:-}
    local description confidence emoji plugin origin

    description=$(jq -r --arg name "$skill" '.skills[$name].description' "$SKILL_RULES")
    plugin=$(jq -r --arg name "$skill" '.skills[$name].plugin // empty' "$SKILL_RULES")

    if [ -z "$score" ]; then
        printf '📌 %s\n' "$skill"
        printf '   Description: %s\n' "$description"
        printf '   Status: REQUIRED — invoke once per session, then stays in force\n'
    else
        # Confidence label is purely cosmetic — it does not gate inclusion.
        if [ "$score" -ge "$HIGH_CONFIDENCE" ]; then
            confidence="🟢 HIGH"
        elif [ "$score" -ge "$MEDIUM_CONFIDENCE" ]; then
            confidence="🟡 MEDIUM"
        else
            confidence="🟠 LOW"
        fi

        printf '📚 %s\n' "$skill"
        printf '   Description: %s\n' "$description"
        printf '   Confidence: %s (score: %s)\n' "$confidence" "$score"
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

# Prints the JSON envelope. jq handles all escaping (quotes, newlines, emoji).
#   $1 hookEventName — must match the firing event, not be hardcoded
#   $2 additionalContext — injected into the model's context (Claude sees it)
#   $3 systemMessage — shown in the transcript only (user sees it)
emit_envelope() {
    jq -n --arg event "$1" --arg ctx "$2" --arg msg "$3" \
        '{
            hookSpecificOutput: {
                hookEventName: $event,
                additionalContext: $ctx
            },
            systemMessage: $msg
        }'
}

# Read and validate the hook event payload. Bail silently on malformed JSON so
# we never disrupt the user turn.
EVENT_DATA=$(cat)

if ! echo "$EVENT_DATA" | jq -e . >/dev/null 2>&1; then
    exit 0
fi
