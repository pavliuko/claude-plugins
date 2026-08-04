# statusline

A two-line Claude Code [status line](https://code.claude.com/docs/en/statusline).

```
📁 claude-plugins | 🌿 feat/15101-role-respecting-client ~11 | 🔗 #1234
🤖 Opus 5 ⚡ high | 💽 ███░░░░░░░ 38% context | ⛽ ███████░░░ 76% left · resets in 2h 41m | 👤 Sasha Pavliuk
```

Line 1 is **where you are** — it changes as you move between projects and branches. Line 2 is **what
you're spending** — it changes as the session burns on.

| Line | Section | Shows | Absent when |
| --- | --- | --- | --- |
| 1 | 📁 directory | basename of `workspace.current_dir`, in cyan | never |
| 1 | 🌿 git | branch, `+staged` (green), `~modified` (yellow) | not a git repository |
| 1 | 🔗 PR | `pr.number` as an OSC 8 hyperlink | no open PR for the branch |
| 2 | 🤖 model | `model.display_name` | never |
| 2 | ⚡ effort | `effort.level` | model doesn't support the effort parameter |
| 2 | 💽 context | 10-block bar + `used_percentage` | never (falls back to 0%) |
| 2 | ⛽ fuel gauge | 10-block bar + how much of the 5h rate-limit window is **left**, plus a reset countdown | non-subscription auth, or before the first API response |
| 2 | 👤 account | `displayName · organizationName` | `~/.claude.json` unreadable |

**The two bars fill in opposite directions on purpose.** 💽 is a tank filling up — it grows as context
is consumed. ⛽ is a fuel gauge — it drains as the quota burns, so a nearly empty bar means you're
nearly out. Both are 10 blocks wide, and both are colored by *consumption* so red always means danger:
green below 70% used, yellow to 89%, red at 90%+. That's why a nearly empty ⛽ bar is red rather than
green.

## Not a plugin

A plugin's `settings.json` accepts only the `agent` and `subagentStatusLine` keys — `statusLine` is not
among them ([plugins reference](https://code.claude.com/docs/en/plugins-reference)) — so this ships as a
plain versioned script instead of a marketplace plugin.

## Install

```bash
cp statusline/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Then add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "refreshInterval": 60
  }
}
```

`refreshInterval` matters here: the reset countdown and the git counts are time-sensitive, and the
event-driven triggers go quiet while a session sits idle. 60s matches the countdown's minute
granularity.

## Requirements

- `jq` — `brew install jq`
- A terminal with OSC 8 hyperlink support for the clickable PR (iTerm2, Kitty, WezTerm; **not**
  Terminal.app). Without it the `#1234` still renders, just not clickable.

## Notes

- **The fuel gauge is not per-conversation.** It tracks Claude's 5-hour rolling rate-limit window,
  which keeps counting across `/clear` and new sessions and resets on its own clock. A full tank does
  not mean a fresh conversation.
- **"% left" is computed, not reported.** `rate_limits` exposes only `used_percentage`; there is no
  remaining field for it (unlike `context_window`, which has `remaining_percentage`), so the gauge
  shows `100 - used`.
- **The account comes from `~/.claude.json`**, not from the status line payload, which carries no
  account fields. 92K file, ~6ms per `jq` read, so it isn't cached.
- **Git state is cached for 5s** per session in `/tmp/claude-statusline-git-$SESSION_ID`. `git diff`
  is slow in large repos and the script runs on every assistant message.
- **The model and effort are deliberately uncolored** so they inherit the terminal's default
  foreground and stay legible in both light and dark themes. Hardcoding black would make them
  invisible on a dark background.
- **Line 2 is the long one** — roughly 118 display columns when every segment is present, against ~71
  for line 1. On a narrow terminal the account and the reset countdown truncate first, and status line
  notifications (MCP errors, auto-update notices) share the right side of that row. Drop the
  organization from the account segment if you need the width back.

## Test

```bash
echo '{"model":{"display_name":"Opus 5"},"effort":{"level":"high"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":38},"session_id":"t1"}' | ./statusline/statusline.sh
```
