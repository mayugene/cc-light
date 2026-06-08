# 🚦 cc-light

A macOS menu bar traffic light for Claude Code — see your session state at a glance.

| Color | Meaning |
|-------|---------|
| 🟢 Green | Idle — task complete, ready for input |
| 🟡 Yellow (blinking) | Waiting for user confirmation |
| 🔴 Red | Busy — Claude is working |

![demo](./demo.gif)

## Install

```bash
git clone https://github.com/yourname/cc-light.git
cd cc-light
./install.sh
```

This will:
1. Build the native macOS menu bar app
2. Install Claude Code hooks to report session state
3. Launch cc-light in your menu bar

## How It Works

```
Claude Code Hooks  →  /tmp/cc-light-state.json  →  cc-light menu bar app
(PreToolUse, Stop,     (state file)                 (monitors file changes)
 Notification)
```

Claude Code [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) write session state to a temp file. The menu bar app watches that file and updates the icon color accordingly.

## Manual Setup

If you prefer manual configuration, add this to `~/.claude/settings.json`:

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

## Requirements

- macOS 14+ (Sonoma)
- Claude Code CLI

## Uninstall

```bash
./uninstall.sh
```

## License

MIT
