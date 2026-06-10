# 🚦 cc-light

A macOS menu bar traffic light for Claude Code — see your session state at a glance.

| Color | Glyph | Meaning |
|-------|-------|---------|
| 🟢 Green | 🟢 | Idle — task complete, ready for input |
| 🟡 Yellow | 💬 | Waiting for input — Claude is sitting idle waiting for your next message |
| 🟡 Yellow | 🔒 | Waiting for permission — a tool call needs your authorization |
| 🔴 Red | 🔴 | Busy — Claude is working |

![demo](./demo.gif)

The same hooks are used by every Claude Code client on this machine — the CLI, the VSCode extension, and the JetBrains plugins (IDEA, GoLand, PyCharm, …). Each session's state is tracked in its own file under `/tmp/cc-light/`, so sessions are independent; the menu bar icon is just an aggregate of the highest-priority state across them.

The aggregate priority is **yellow > green > red**:
- **🟡 waiting** — at least one session needs your input; the menu bar goes yellow (the dropdown distinguishes 💬 input vs 🔒 permission)
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
2. Install Claude Code hooks (deep-merged into your existing `~/.claude/settings.json` if one exists; safe to re-run). On re-run, stale `/tmp/cc-light/*.json` files are cleared so the menu doesn't start with leftover zombie sessions.
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
                   drops busy/idle entries older than 5min,
                   keeps waiting entries until SessionEnd,
                   shows highest-priority emoji,
                   lists each session with its project name)
```

**Hook events covered** (each one updates state):

| Event | State | Why |
|-------|-------|-----|
| `UserPromptSubmit` | busy | Light goes red the moment you send a message — covers pure-text turns that don't call tools |
| `PreToolUse` | busy | Claude is about to call a tool |
| `PostToolUse` | busy | Tool finished; Claude is still in the same turn |
| `PostToolUseFailure` | busy | Tool failed but the turn isn't over yet |
| `PostToolBatch` | busy | Batch tool dispatch |
| `SubagentStart` / `SubagentStop` | busy | Subagent lifecycle (parent is still working) |
| `TaskCreated` / `TaskCompleted` | busy | Task system events |
| `MessageDisplay` | busy | **Fires for every batch of streamed assistant text** — the only hook that ticks during Claude's pure-text generation phase (the "thinking / generating / incubating" states), so the red light stays alive through long messages |
| `WorktreeCreate` / `WorktreeRemove` | busy | Git worktree operations |
| `PermissionRequest` | waitingPermission | A tool needs your authorization — 🔒 in the menu |
| `Notification` (idle_prompt) | waitingInput | Claude is idle waiting for your next message — 💬 in the menu |
| `Stop` / `StopFailure` | idle | Claude finished its turn (or failed out of it) |
| `SessionEnd` | (delete file) | User closed Claude Code — clean up the session's state file. Combined with the stale-filter exemption for waiting states below, this means waiting sessions stay visible until either Claude Code is closed or you handle the prompt. |

The menu shows e.g.:

```
1 waiting for permission
─────────
🔒  cc-light       —  34574b6f
─────────
1 waiting for input
─────────
💬  tracker-tool-flutter  —  32f753f9
─────────
1 busy
─────────
🔴  observer-sessions  —  f5683b79
─────────
Quit                              ⌘Q
```

`waitingPermission` is shown first because permission prompts block your work; `waitingInput` is next; everything else (busy/idle) follows.

## Manual Setup

If you prefer manual configuration, add this to `~/.claude/settings.json` (it's safe to merge with any existing hooks you have):

```json
{
  "hooks": {
    "UserPromptSubmit":   [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "PreToolUse":         [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "PostToolUse":        [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "PostToolUseFailure": [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "PostToolBatch":      [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "SubagentStart":      [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "SubagentStop":       [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "TaskCreated":        [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "TaskCompleted":      [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "MessageDisplay":     [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "WorktreeCreate":     [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "WorktreeRemove":     [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh busy || true" }] }],
    "PermissionRequest":  [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh waitingPermission || true" }] }],
    "Notification":       [{ "matcher": "idle_prompt", "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh waitingInput || true" }] }],
    "Stop":               [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh idle || true" }] }],
    "StopFailure":        [{ "hooks": [{ "type": "command", "command": "[ -x /path/to/cc-light/hooks/cc-light-hook.sh ] && /path/to/cc-light/hooks/cc-light-hook.sh idle || true" }] }]
  }
}
```

The `[ -x ... ] && ... || true` wrapper makes each hook a silent no-op if the script is missing — so uninstalling cc-light without cleaning `settings.json` doesn't spam "command not found" on every Claude Code action. The `UserPromptSubmit` hook is what turns the light red the moment you send a message (otherwise pure-text turns that don't call any tools would leave the light green until the response finishes). `MessageDisplay` is the only hook that fires while Claude is generating text (the "thinking / spinning / generating" UI states), so it's what keeps the red light alive during long streaming responses.

The hook script itself uses `python3` (built into macOS) to parse the JSON stdin robustly — it does not require `jq`.

## Requirements

- macOS 14+ (Sonoma)
- Claude Code CLI, VSCode extension, and/or JetBrains plugin — any combination works
- Python 3 (preinstalled on macOS)

## Uninstall

```bash
./uninstall.sh
```

This removes the `.app` bundle and the entire `/tmp/cc-light` directory. The hooks in `~/.claude/settings.json` are **not** removed — edit the file manually to clean them up.

## License

MIT
