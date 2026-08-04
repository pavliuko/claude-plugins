#!/bin/bash
# Claude Code status line.
#   line 1: dir, git branch + dirty counts, clickable PR link
#   line 2: model/effort, context bar, 5h fuel gauge + reset countdown, account
input=$(cat)

MODEL=$(jq -r '.model.display_name' <<<"$input")
EFFORT=$(jq -r '.effort.level // empty' <<<"$input")
DIR=$(jq -r '.workspace.current_dir' <<<"$input")
SESSION_ID=$(jq -r '.session_id' <<<"$input")
PCT=$(jq -r '.context_window.used_percentage // 0' <<<"$input" | cut -d. -f1)
FIVE_H=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
FIVE_H_RESET=$(jq -r '.rate_limits.five_hour.resets_at // empty' <<<"$input")
PR_NUMBER=$(jq -r '.pr.number // empty' <<<"$input")
PR_URL=$(jq -r '.pr.url // empty' <<<"$input")

# The signed-in account isn't part of the status line payload — read it from the CLI's own config.
ACCOUNT=$(jq -r '.oauthAccount | [.displayName, .organizationName] | map(select(. != null and . != "")) | join(" · ")' ~/.claude.json 2>/dev/null)
[ "$ACCOUNT" = "null" ] && ACCOUNT=""

CYAN=$'\033[36m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
BLUE=$'\033[34m'; DIM=$'\033[2m'; RESET=$'\033[0m'
SEP="${DIM}|${RESET}"

# Green under 70%, yellow to 89%, red at 90%+.
usage_color() {
  if [ "$1" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

BAR_WIDTH=10

# $1 = how full to draw the bar, $2 = the used % that decides its color. The two differ for the
# fuel gauge, which fills with what's left but must still turn red as the quota runs out.
render_bar() {
  local fill_pct=$1 used_pct=$2 filled empty bar="" fill pad
  filled=$((fill_pct * BAR_WIDTH / 100))
  [ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
  [ "$filled" -lt 0 ] && filled=0
  empty=$((BAR_WIDTH - filled))
  [ "$filled" -gt 0 ] && printf -v fill "%${filled}s" && bar="${fill// /█}"
  [ "$empty" -gt 0 ] && printf -v pad "%${empty}s" && bar="${bar}${pad// /░}"
  printf '%s%s%s' "$(usage_color "$used_pct")" "$bar" "$RESET"
}

# --- git, cached: `git diff` is slow in large repos and this runs on every message
CACHE_FILE="/tmp/claude-statusline-git-$SESSION_ID"
CACHE_MAX_AGE=5

cache_is_stale() {
  [ ! -f "$CACHE_FILE" ] && return 0
  local mtime now
  # stat -c is GNU, stat -f is BSD; GNU must be tried first — on Linux the BSD
  # form prints a filesystem report to stdout before failing.
  mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  [ $((now - mtime)) -gt "$CACHE_MAX_AGE" ]
}

if cache_is_stale; then
  if git rev-parse --git-dir >/dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    printf '%s|%s|%s' "$BRANCH" "$STAGED" "$MODIFIED" >"$CACHE_FILE"
  else
    printf '||' >"$CACHE_FILE"
  fi
fi
IFS='|' read -r BRANCH STAGED MODIFIED <"$CACHE_FILE"

GIT_SEGMENT=""
if [ -n "$BRANCH" ]; then
  GIT_SEGMENT=" ${SEP} 🌿 ${BRANCH}"
  [ "${STAGED:-0}" -gt 0 ] 2>/dev/null && GIT_SEGMENT="${GIT_SEGMENT} ${GREEN}+${STAGED}${RESET}"
  [ "${MODIFIED:-0}" -gt 0 ] 2>/dev/null && GIT_SEGMENT="${GIT_SEGMENT} ${YELLOW}~${MODIFIED}${RESET}"
fi

# --- PR, as an OSC 8 hyperlink (cmd/ctrl+click); absent until one is open
PR_SEGMENT=""
if [ -n "$PR_NUMBER" ] && [ -n "$PR_URL" ]; then
  OSC8_OPEN=$'\033]8;;'; OSC8_TEXT=$'\a'; OSC8_CLOSE=$'\033]8;;\a'
  PR_SEGMENT=" ${SEP} 🔗 ${BLUE}${OSC8_OPEN}${PR_URL}${OSC8_TEXT}#${PR_NUMBER}${OSC8_CLOSE}${RESET}"
fi

# --- model, with effort when the model exposes it. Left uncolored so it picks up the terminal's
# default foreground, which tracks light/dark themes; a hardcoded black would vanish on a dark one.
MODEL_SEGMENT="🤖 ${MODEL}"
[ -n "$EFFORT" ] && MODEL_SEGMENT="${MODEL_SEGMENT} ⚡ ${EFFORT}"

# --- 5h rate-limit window; absent for non-subscription auth and before the first response
LIMIT_SEGMENT=""
if [ -n "$FIVE_H" ]; then
  FIVE_H_INT=$(printf '%.0f' "$FIVE_H")
  FIVE_H_LEFT=$((100 - FIVE_H_INT))
  [ "$FIVE_H_LEFT" -lt 0 ] && FIVE_H_LEFT=0
  LIMIT_SEGMENT=" ${SEP} ⛽ $(render_bar "$FIVE_H_LEFT" "$FIVE_H_INT") ${FIVE_H_LEFT}% left"
  if [ -n "$FIVE_H_RESET" ]; then
    LEFT=$((FIVE_H_RESET - $(date +%s)))
    if [ "$LEFT" -le 0 ]; then
      LIMIT_SEGMENT="${LIMIT_SEGMENT} ${DIM}· resets now${RESET}"
    elif [ "$LEFT" -lt 60 ]; then
      LIMIT_SEGMENT="${LIMIT_SEGMENT} ${DIM}· resets in <1m${RESET}"
    elif [ "$LEFT" -lt 3600 ]; then
      LIMIT_SEGMENT="${LIMIT_SEGMENT} ${DIM}· resets in $((LEFT / 60))m${RESET}"
    else
      LIMIT_SEGMENT="${LIMIT_SEGMENT} ${DIM}· resets in $((LEFT / 3600))h $(((LEFT % 3600) / 60))m${RESET}"
    fi
  fi
fi

ACCOUNT_SEGMENT=""
[ -n "$ACCOUNT" ] && ACCOUNT_SEGMENT=" ${SEP} 👤 ${DIM}${ACCOUNT}${RESET}"

printf '%s\n' "📁 ${CYAN}${DIR##*/}${RESET}${GIT_SEGMENT}${PR_SEGMENT}"
printf '%s\n' "${MODEL_SEGMENT} ${SEP} 💽 $(render_bar "$PCT" "$PCT") ${PCT}% context${LIMIT_SEGMENT}${ACCOUNT_SEGMENT}"
