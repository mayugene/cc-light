# 🚦 cc-light

A macOS menu bar traffic light for Claude Code — see your session state at a glance.

| Color | Meaning |
|-------|---------|
| 🟢 Green | Idle — task complete, ready for input |
| 🟡 Yellow (blinking) | Waiting for user confirmation |
| 🔴 Red | Busy — Claude is working |

![demo](./demo.gif)

The same hooks are used by every Claude Code client on this machine — the CLI, the VSCode extension, and the JetBrains plugins (IDEA, GoLand, PyCharm, …). The menu bar aggregates the highest-priority state across all sessions and the dropdown lists each one with its project name.

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
3 busy · 1 waiting · 0 idle
─────────
🔴  foo      —  abc12345
🔴  bar      —  def67890
🔴  baz      —  ghi11111
🟡  qux      —  jkl22222
```

## Manual Setup

If you prefer manual configuration, add this to `~/.claude/settings.json` (it's safe to merge with any existing hooks you have):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [{ "type": "command", "command": "/path/to/cc-light/hooks/cc-light-hook.sh busy" }]
      }
    ],
    "Notification": [
      {
        "matcher": "idle_prompt|permission_prompt",
        "hooks": [{ "type": "command", "command": "/path/to/cc-light/hooks/cc-light-hook.sh waiting" }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "/path/to/cc-light/hooks/cc-light-hook.sh idle" }]
      }
    ]
  }
}
```

The hook script uses `python3` (built into macOS) to parse the JSON stdin robustly — it does not require `jq`.

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
