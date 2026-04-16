# WSL Windows bridge architecture

## Goal

Bridge a WSL-hosted OpenClaw workflow to Windows user-session capabilities on the same physical machine without breaking networking, disrupting the live gateway path, or coupling every action to a brittle one-off script.

## Reference topology

```text
OpenClaw / WSL agent
  -> thin client
  -> IPC transport
  -> Windows bridge host
  -> capability workers
  -> Windows user-session APIs
```

## Components

### 1. WSL thin client

Responsibilities:
- shape requests into a small bridge protocol
- choose the correct capability
- apply retries and timeouts
- surface structured errors back to OpenClaw
- remain stateless except for short-lived request metadata

Do not let the thin client contain Windows-specific business logic beyond transport and capability selection.

### 2. Windows bridge host

Responsibilities:
- run in the interactive logged-in user session
- accept requests from the WSL side
- maintain a capability registry
- dispatch work to isolated workers
- enforce timeouts and cancellation
- expose health and version information
- keep logs bounded and easy to clear

Recommended long-term implementation:
- C#/.NET host
- named pipe server
- per-capability worker isolation

### 3. Capability workers

Create workers by function, not by app brand, at first.

Suggested initial workers:
- `window-worker`
- `screen-worker`
- `browser-worker`
- `clipboard-worker`
- `com-worker`

Promote app-specific adapters later only if repeated demand appears, for example Excel or Outlook.

## Session model

Use the currently logged-in user session. Avoid SYSTEM, service-session GUI automation, and admin-first designs.

Reasoning:
- GUI and COM actions are more predictable in the active user session
- breakage is easier to diagnose and recover
- the bridge does not need platform-wide authority to do local desktop tasks

## Migration model

Use staged coexistence:

1. baseline inventory
2. add bridge directories
3. validate transport
4. roll out read-only capabilities
5. switch callers
6. observe
7. clean up obsolete artifacts

Never combine network reconfiguration and bridge rollout in the same step.

## Directory suggestions

Windows side example:

```text
C:\OpenClawBridge\
  host\
  workers\
  logs\
  tmp\
  state\
```

WSL side example:

```text
~/.openclaw/bridge/
  bin/
  state/
  logs/
```

Keep logs and temp files under dedicated directories so cleanup can be narrow and safe.

## Result shape

Prefer structured responses such as:

```json
{
  "ok": true,
  "action": "window.focus",
  "durationMs": 87,
  "result": {
    "matchedWindow": "Google Chrome",
    "attempted": true,
    "foregroundConfirmed": false
  }
}
```

Separate attempt, partial success, and confirmed effect.
