# english

Light English-grammar coaching on every prompt. A `UserPromptSubmit` hook injects `coach.md` into each turn; Claude appends a short `✍️ English` correction **only when your prompt has a real mistake**, always after the actual answer.

- **No extra cost** — the check happens inside the normal turn, no second model call.
- **Low noise** — silent when your prompt is clean or just casual shorthand (`u`, `gimme`, `coz`).
- **Brief** — a ❌ / ✅ pair plus a ≤6-word note on what changed.

```
✍️ **English**
❌ Doesn't ~~a~~ flow:go skill have it ~~too as well~~?
✅ Doesn't **the** flow:go skill have it **as well**?
**the** before the skill name; drop the doubled **too**.
```

## Hook

`UserPromptSubmit` (matcher `*`) → `cat coach.md`. Edit `coach.md` to change the coaching style (e.g. switch from brief notes to explained corrections).

## Install

```sh
/plugin marketplace add pavliuko/claude-plugins
/plugin install english@pavliuko
```
