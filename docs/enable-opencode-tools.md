# Enable OpenCode Tool Execution for This Project

To allow the assistant to edit files and run shell commands (builds, tests, etc.) in this project, you need to grant tool permissions in the OpenCode CLI configuration.

## Option 1: Add permissions to the project config

Edit the OpenCode config file you showed me (usually `opencode.json` or `opencode.jsonc` in the project root) and add a `permissions` block alongside the existing `provider` and `model` sections:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "perplexity-agent": {
      "...": "existing provider config"
    }
  },
  "model": "perplexity-agent/perplexity/kimi-k2.7-code",
  "permissions": {
    "allowFileWrites": true,
    "allowShellCommands": true,
    "allowWebFetch": true
  }
}
```

If the schema does not accept `permissions`, try adding an `agent` block instead:

```json
{
  "...": "existing config",
  "agent": {
    "mode": "act"
  }
}
```

## Option 2: Global user config

If a project-level config does not work, add the permissions to your global OpenCode config, typically one of:

- `~/.config/opencode/config.json`
- `~/.config/opencode/opencode.json`
- `~/.opencode/config.json`

Use the same `permissions` block shown above.

## Verify

After saving the config, restart the OpenCode CLI session and ask the assistant to run a simple command such as:

```
Please run `ls` in the project root.
```

If the assistant can execute the command, tool execution is enabled.

## What I need tool execution for

Once enabled, I will complete the remaining habit-form tasks:

1. Remove the upper bound on increment size (keep only `> 0`).
2. Change `incrementCount` from a `Double` text field to an `Int` with `−` / `+` buttons.
3. Rebuild all five Xcode schemes (`Clarity`, `Widgets`, `ClarityAppIntentsExtension`, `ClarityWatch`, `ClarityWatchWidgetsExtension`).
4. Re-run `HabitStreakCalculatorTests` to verify no regressions.
