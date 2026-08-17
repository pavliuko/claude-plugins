#!/bin/bash

# Required Skills Hook (SessionStart)
#
# Delivers every `"required": true` skill from rules.json once, at the top of the
# session, phrased as an instruction to invoke rather than a suggestion to weigh.
# Registered for startup|resume|clear|compact|fork — `compact` matters most, as
# it re-asserts them right after a compaction would have summarised them out
# of context.
#
# There is no prompt at SessionStart, so nothing here scores anything: a required
# skill applies regardless of what the user goes on to ask. Scored suggestions
# are suggest-skills.sh's job.
#
# Inputs:  stdin  — SessionStart JSON ({ "source": "startup", ... })
#          files  — rules.json in the user and/or project scope (see lib.sh)
# Outputs: stdout — JSON envelope with hookSpecificOutput.additionalContext,
#                   or nothing at all when no skill is required
#          files  — skill-suggestion.log in each scope that has a rules.json
# Exit:    always 0 — never blocks session startup.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Session start ($(echo "$EVENT_DATA" | jq -r '.source // "?"')): delivering required skills"

REQUIRED_SKILLS=()
while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    skill_is_required "$skill" || continue
    skill_is_available "$skill" || continue

    REQUIRED_SKILLS+=("$skill")
    log_line "  📌 Required (sent as an instruction): $skill"
done < <(skill_names)

# Silence when nothing is required: with no prompt there is nothing to report, and
# an unconfigured install should stay invisible.
if [ ${#REQUIRED_SKILLS[@]} -eq 0 ]; then
    log_line "  No required skills"
    exit 0
fi

CONTEXT=$({
    echo ""
    echo "$SEP"
    echo "📌 REQUIRED SKILLS — MUST BE ACTIVE THIS SESSION"
    echo "$SEP"
    echo ""

    for i in "${!REQUIRED_SKILLS[@]}"; do
        render_skill "${REQUIRED_SKILLS[$i]}"
    done

    echo "❗ Not suggestions — required by the user's config, so they apply to every"
    echo "   prompt this session regardless of topic. Invoke each one above via the"
    echo "   Skill tool before replying, then keep following it for the rest of the"
    echo "   session. Skip the call only if it is already in your context."
    echo ""
    echo "$SEP"
})

emit_envelope "SessionStart" "$CONTEXT" "📌 Required skills: ${REQUIRED_SKILLS[*]}"

log_line "  → Required (instructed): ${REQUIRED_SKILLS[*]}"

exit 0
