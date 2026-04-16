# Learning Note

## Summary

WSL to Windows file-queue bridge failures were not only caused by request lifecycle bugs inside the PowerShell host. A second major cause was duplicate Windows bridge host processes, where an older process kept consuming requests and returned stale behavior. The completed bridge pattern should be preserved under the repository or skill name `winwslbridge`.

## Trigger

While validating the WSL Windows bridge, `window.active` kept returning `unsupported action` through normal `bridgectl.py` runs even after the host script had been patched and manual one-off tests sometimes succeeded.

## Root cause

Two issues overlapped:
1. The file-queue host request lifecycle was unsafe, especially around reading, responding, and deleting request files.
2. More importantly for the inconsistent validation, multiple `windows-bridge-fileq.ps1` processes were left running on Windows. Old hosts could keep serving requests after code updates, so tests hit stale logic even when the new script had already been copied over.

## Fix

- Updated `windows-bridge-fileq.ps1` so request contents are read into memory first, the response file is written before request deletion, and cleanup is safer in both success and error paths.
- Updated `check-bridge.ps1` to trim PID file contents before parsing.
- Updated `start-bridge.ps1` so `-Fresh` kills duplicate bridge host processes discovered via `Win32_Process` command lines, removes stale PID state, then launches a single fresh host.
- Reworked `window.focus` into an activation-style path that separates matching from actual foreground success.
- Added a UTF-8-safe fallback payload for non-ASCII titles so Korean window title matching survives the WSL to Windows file-queue hop.
- Revalidated the bridge end to end after restarting with a single host.

## Prevention

- Treat Windows bridge restarts as host lifecycle management, not just script replacement.
- When validation looks inconsistent after a code change, suspect multiple live host processes before assuming the latest script is wrong.
- Make the launcher responsible for duplicate cleanup during fresh starts.
- Prefer logging and validation that confirm which host process is actually serving requests.
- For window activation, distinguish title matching from actual foreground success. Windows can legitimately reject `SetForegroundWindow` even when the target window was found and activation was attempted correctly.
- For non-ASCII window titles, include a UTF-8-safe fallback field such as base64 in the request payload so the Windows host can recover the exact title text even when the direct JSON string path is mangled by Windows PowerShell parsing.
- Preserve the final reusable pattern as `winwslbridge`, including host lifecycle cleanup, activation semantics, and non-ASCII-safe request handling.

## Promote to skill?

- yes
- suggested skill name: wsl-windows-bridge
- useful resources needed: `state/bridge/bin/start-bridge.ps1`, `state/bridge/bin/check-bridge.ps1`, `state/bridge/bin/windows-bridge-fileq.ps1`, launcher notes in the skill guidance, activation semantics and Windows foreground limitation notes
