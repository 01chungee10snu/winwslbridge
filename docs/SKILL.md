---
name: wsl-windows-bridge
description: Design, review, or implement a bridge between WSL-hosted OpenClaw workflows and Windows user-session capabilities such as screenshots, window focus, browser attach, and COM-backed app automation. Use when planning or building a WSL thin client plus Windows bridge host, deciding between file queue, named pipe, or localhost IPC, or enforcing no-network-disruption, staged cleanup, and user-session safety constraints on one-machine hybrid automation.
---

# WSL Windows Bridge

## Overview

Design the bridge as a local execution layer between WSL and the interactive Windows session, not as a second agent runtime. Keep decision-making in WSL/OpenClaw and keep the Windows side focused on capability execution, health reporting, and fast failure.

Optimize first for host stability, no network disruption, recoverability, and predictable response times. Treat external-host security as secondary to not breaking the current machine, while still avoiding arbitrary code execution surfaces.

## Core architecture

Use this reference shape for long-lived designs:

- **WSL thin client** handles request shaping, retries, timeouts, and capability selection.
- **Windows bridge host** runs in the logged-in user session and owns IPC, worker lifecycle, and health.
- **Capability workers** isolate window, screen, browser, COM, clipboard, and file-open tasks.
- **IPC** should prefer named pipes for the steady-state design; use file-queue prototypes only for early validation.

Keep the bridge additive. Do not replace or reconfigure the network path that OpenClaw already uses to stay online.

## Non-negotiable constraints

Follow these constraints unless the user explicitly asks for a riskier path:

1. **Do not disrupt networking.** Do not change WSL routing, Windows NIC settings, Hyper-V/WSL virtual networking, DNS, firewall defaults, or the current OpenClaw gateway path just to make the bridge work.
2. **Build in parallel.** Create bridge files in dedicated directories on both sides. Do not delete or rewrite the current working path until the new path is proven.
3. **Run in the interactive user session.** Prefer a normal user process over SYSTEM, service-session GUI access, or elevated background agents.
4. **Delete last.** Add, validate, switch, then clean up stale artifacts. Never front-load deletion.
5. **Keep live-state-aware cleanup.** Remove only temp files, stale logs, or orphaned worker artifacts. Do not remove active handles, active sockets, live state files, or the currently serving bridge host.

## IPC decision rule

Choose IPC in this order:

1. **Named pipe** for long-term local-only production use on one machine.
2. **File queue** for bootstrap experiments, dead-simple debugging, or when the Windows host is not yet stable.
3. **Localhost HTTP/WebSocket** only when another local tool truly benefits from a network-shaped API.

Prefer named pipes for the final architecture because they are local, fast, and do not require changing network behavior.

See `references/ipc-options.md` when comparing tradeoffs.

## Capability rollout order

Roll out read-mostly capabilities first.

Recommended sequence:

1. `health`
2. `capabilities`
3. `window.list`
4. `screen.capture`
5. `clipboard.getText`
6. `browser.openUrl`
7. `window.focus`
8. COM-backed app actions such as Explorer reveal, Excel open, or Outlook draft

Do not start with raw key injection, arbitrary PowerShell execution, or broad COM eval surfaces.

## Operating model

Treat the Windows host as a capability dispatcher, not an autonomous system.

- Keep requests action-based, for example `window.focus`, `screen.capture`, `browser.openUrl`, `excel.openWorkbook`.
- Return structured results with duration, status, and any best-effort caveats.
- Make foreground and window-focus actions explicitly best-effort because Windows foreground rules are not absolute.
- Treat window activation as a layered operation: match the window title, restore if minimized, raise or bring to top, then attempt foreground. Report each step separately when possible.
- For non-ASCII title matching across WSL to Windows file-queue requests, include a UTF-8-safe fallback representation such as base64 in the request payload so PowerShell-side parsing can recover the intended text.
- Use short, bounded timeouts per worker.
- Make workers individually restartable.

See `references/architecture.md` for the detailed component model.

## Cleanup and migration workflow

Use this migration order:

1. Inventory the current working state.
2. Add bridge directories and scaffolding without touching the live path.
3. Validate IPC locally.
4. Enable the first read-only capability.
5. Expand capability coverage.
6. Switch WSL callers to the new bridge path.
7. Observe stability.
8. Only then remove obsolete temp files, stale scripts, and abandoned prototypes.

Use `scripts/bridge-inventory.sh` to capture a baseline before implementation or cleanup.

## What not to do

Avoid these patterns in normal operation:

- changing WSL network config as part of bridge rollout
- assuming Chrome MCP existing-session is the same thing as a WSL-to-Windows bridge
- exposing arbitrary script execution over the bridge
- running the bridge as admin by default
- relying on focus success as if it were guaranteed
- treating `foregroundResult = false` as proof that window matching failed
- deleting old launchers or scripts before proving the new path works
- letting cleanup scripts recurse through shared workspace or system paths
- trusting bridge validation after code updates without checking for duplicate Windows bridge host processes

## Implementation workflow

When the user wants to actually build the bridge, work in this order:

1. Run `scripts/bridge-inventory.sh` and keep the result as a pre-change baseline.
2. Read `references/implementation-plan.md` and follow the current phase only.
3. Use `scripts/bridgectl.py` as the WSL thin-client starter.
4. Use `references/windows-host-skeleton.cs` as the Windows host starter.
5. Implement health and capability reporting before adding workers.
6. Add `window.list` and `screen.capture` before focus or COM-backed actions.
7. When validating updated Windows host code, ensure only one `windows-bridge-fileq.ps1` host is alive. On fresh restarts, clean up duplicate bridge hosts before trusting test results.
8. For `window.focus`, validate two things separately: title matching and actual foreground success. Matching may succeed while Windows still refuses to grant foreground.
9. Re-check `references/no-network-disruption-checklist.md` before cleanup or migration steps.

## Design outputs this skill should produce

Depending on the request, produce one or more of these:

- a staged bridge architecture plan
- an IPC choice and rationale
- capability registry proposals
- cleanup policy and migration checklist
- worker interface definitions
- bootstrap scripts or skeleton code for inventory, thin client, and Windows host
- a build roadmap tied to non-disruptive rollout phases
- a reusable bridge package or repo layout that can be preserved under the name `winwslbridge`

## Working files

- `references/architecture.md` explains the long-term host, worker, and migration design.
- `references/ipc-options.md` compares named pipe, file queue, and localhost HTTP.
- `references/capabilities.md` defines the recommended capability surface and rollout order.
- `references/no-network-disruption-checklist.md` lists the changes to avoid and the validation points to keep OpenClaw online.
- `references/implementation-plan.md` turns the architecture into a staged build sequence.
- `references/build-roadmap.md` summarizes deliverables and success criteria by stage.
- `references/windows-host-skeleton.cs` is the starter host for the Windows side.
- `scripts/bridge-inventory.sh` captures a read-only baseline of WSL networking, OpenClaw status, and interop symptoms.
- `scripts/bridgectl.py` is the starter thin client for WSL.

Read only the reference files that match the current task to keep context lean.
