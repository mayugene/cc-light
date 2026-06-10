# 🚦 cc-light

A macOS menu bar traffic light for Claude Code — see your session state at a glance.

| Color | Meaning |
|-------|---------|
| 🟢 Green | Idle — task complete, ready for input |
| 🟡 Yellow (blinking) | Waiting for user confirmation |
| 🔴 Red | Busy — Claude is working |

![demo](./demo.gif)

The same hooks are used by every Claude Code client on this machine — the CLI, the VSCode extension, and the JetBrains plugins (IDEA, GoLand, PyCharm, …). Each session's state is tracked in its own file under `/tmp/cc-light/`, so sessions are independent; the menu bar icon is just an aggregate of the highest-priority state across them.

The aggregate priority is **yellow > green > red**:
- **🟡 waiting** — at least one session needs your input; the menu bar goes yellow
- **🟢 idle** — otherwise, if any session is sitting idle, all clear
- **🔴 busy** — every session is busy (Claude is working, no action needed from you)

So if you're mid-edit in one project while another is asking for permission, the icon stays yellow until you handle the prompt — even if the first project is still grinding.

## Install

```bash
git clone https://github.com/mayugene/cc-light.git
cd cc-light
./install.sh
```

This will:
1. Build the native macOS menu bar app
2. Install Claude Code hooks (deep-merged into your existing `~/.claude/settings.json` if one exists; safe to re-run)
3. Launch cc-light in your menu bar

## How It Works

```
Claude Code hooks  ──►  cc-light-hook.sh <state>
(any client: CLI,         │
 VSCode, JetBrains)       │  parses stdin JSON via python3,
                           ▼  writes /tmp/cc-light/<session_id>.json
                  containing state, session_id, cwd, transcript_path, ts
                           │
                           ▼
                  cc-light menu bar app
                  (polls /tmp/cc-light every 0.5s,
                   drops entries older than 30s,
                   shows highest-priority emoji,
                   lists each session with its project name)
```

The menu shows e.g.:

```
2 waiting for input
─────────
🟡  foo      —  abc12345
🟡  bar      —  def67890
─────────
1 busy · 2 idle
─────────
🔴  baz      —  ghi11111
🟢  qux      —  jkl22222
🟢  zap      —  mno33333
─────────
Quit                              ⌘Q
```

Sessions in the `waiting` state are always listed first under their own header so you can see at a glance which project needs your input, even if other projects are busy or idle.

## Manual Setup

If you prefer manual configuration, add this to `~/.claude/settings.json` (it's safe to merge with any existing hooks you have):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }]
      }
    ],
    "Notification": [
      {
        "matcher": "idle_prompt|permission_prompt",
        "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh waiting || true" }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh idle || true" }]
      }
    ]
  }
}
```

The `[ -x ... ] && ... || true` wrapper makes each hook a silent no-op if the script is missing — so uninstalling cc-light without cleaning `settings.json` doesn't spam "command not found" on every Claude Code action. The `UserPromptSubmit` hook is what turns the light red the moment you send a message (otherwise pure-text turns that don't call any tools would leave the light green until the response finishes).

The hook script itself uses `python3` (built into macOS) to parse the JSON stdin robustly — it does not require `jq`.

## Requirements

- macOS 14+ (Sonoma)
- Claude Code CLI, VSCode extension, and/or JetBrains plugin — any combination works
- Python 3 (preinstalled on macOS)

## Uninstall

```bash
./uninstall.sh
```

This removes the `.app` bundle and the `/tmp/cc-light` state files. The hooks in `~/.claude/settings.json` are **not** removed — edit the file manually to clean them up.

## License

MIT
