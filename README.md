# winwslbridge

A file-queue bridge between WSL and the interactive Windows user session for window management, screen capture, and automation.

## What it does

- **WSL thin client** (`bridgectl.py`) sends JSON requests to a shared directory
- **Windows bridge host** (`windows-bridge-fileq.ps1`) watches for requests and executes them in the interactive user session
- Responses are written back as JSON files for the WSL client to pick up

## Capabilities

| Action | Status | Notes |
|--------|--------|-------|
| `health` | Stable | Heartbeat check |
| `capabilities` | Stable | Returns supported actions |
| `window.list` | Stable | Lists visible windows with title, PID, process name |
| `window.active` | Stable | Returns currently focused window |
| `screen.capture` | Stable | Full virtual screen screenshot to PNG |
| `window.focus` | Stable | Activates a window by title substring (best-effort foreground) |

## Quick start

### 1. Seed Windows bridge files from WSL

```bash
export OPENCLAW_BRIDGE_WINDOWS_SHARE=/mnt/c/OpenClawBridge
bash bin/bootstrap-bridge-share.sh
```

### 2. Start the Windows bridge host

From WSL:
```bash
powershell.exe -NoProfile -Command "& 'C:\OpenClawBridge\bin\start-bridge.ps1' -BridgeRoot 'C:\OpenClawBridge' -Fresh"
```

Or directly on Windows PowerShell:
```powershell
& C:\OpenClawBridge\bin\start-bridge.ps1 -BridgeRoot C:\OpenClawBridge
```

### 3. Send requests from WSL

```bash
export OPENCLAW_BRIDGE_WINDOWS_SHARE=/mnt/c/OpenClawBridge
python3 bin/bridgectl.py health
python3 bin/bridgectl.py window-list
python3 bin/bridgectl.py window-active
python3 bin/bridgectl.py screen-capture
python3 bin/bridgectl.py window-focus --title-contains "Window Title"
```

## Non-ASCII title support

Window focus requests include both the raw title string and a base64-encoded UTF-8 fallback (`titleContainsBase64`). This ensures Korean and other non-ASCII titles survive the WSL-to-Windows file-queue hop even when Windows PowerShell's JSON parsing mangles the direct string.

## Window focus semantics

`window.focus` is an activation-style operation, not a guaranteed foreground steal:

1. Find window by title substring match
2. Restore if minimized (`ShowWindow SW_RESTORE`)
3. Bring to top (`BringWindowToTop`)
4. Attempt foreground (`SetForegroundWindow`)

Windows may legitimately reject the foreground request. The response includes each step's result separately so callers can distinguish matching success from foreground success.

## Architecture

```
WSL (bridgectl.py)
  → writes JSON request to /mnt/c/OpenClawBridge/state/requests/
  → polls /mnt/c/OpenClawBridge/state/responses/

Windows (windows-bridge-fileq.ps1)
  → watches C:\OpenClawBridge\state\requests\
  → reads request, executes action
  → writes response, then deletes request
```

See `references/architecture.md` for the full component model.

## Lessons learned

See `docs/lessons/` for detailed notes on:
- Duplicate host process lifecycle management
- Request file handling order safety
- Non-ASCII title matching across WSL/Windows boundary
- Windows foreground policy limitations

## Requirements

- WSL 2.6+ with interop enabled
- Windows PowerShell 5.1+ (Windows PowerShell, not just pwsh)
- Python 3.8+ on WSL side
- User-session context on Windows (not SYSTEM/service)
