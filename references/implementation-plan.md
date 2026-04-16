# Implementation plan

## Goal

Turn the bridge design into a buildable prototype that can evolve into a stable local bridge without interrupting the current OpenClaw workflow.

## Phase 0, inventory only

Run `scripts/bridge-inventory.sh` from WSL and save the output before changing anything.

Capture at minimum:
- `openclaw status`
- WSL routing and `/etc/resolv.conf`
- WSL interop symptoms
- current Windows executable launch failures

Do not change network settings during this phase.

## Phase 1, file layout only

Create these paths in parallel with the live setup.

Windows side target:

```text
C:\OpenClawBridge\
  host\
  workers\
  logs\
  tmp\
  state\
```

WSL side target:

```text
~/.openclaw/bridge/
  bin/
  logs/
  state/
```

Do not delete any old path during creation.

## Phase 2, thin client bootstrap

Use `scripts/bridgectl.py` as the WSL-side client skeleton.

Initial subcommands:
- `health`
- `capabilities`
- `window-list`
- `screen-capture`

In the early bootstrap, allow two transport modes:
- `fileq` for initial proof-of-life
- `pipe` as the intended long-term mode

The thin client should:
- serialize a request envelope
- enforce a timeout
- print JSON only
- exit non-zero on transport or bridge failure

## Phase 3, Windows host bootstrap

Use `references/windows-host-skeleton.cs` as the host skeleton.

Initial features:
- named pipe listener
- JSON request parsing
- health response
- static capability registry
- bounded logging

Do not implement privileged or system-wide behavior here.

## Phase 4, first real worker

Implement `window.list` first.

Why:
- useful immediately
- lower risk than focus or send-keys
- confirms IPC and result structure

Then implement `screen.capture` with a fixed output directory under `C:\OpenClawBridge\tmp`.

## Phase 5, switch from file queue to named pipe

If a file queue was used for bootstrap, cut over to named pipe after:
- health is stable
- capability registry works
- `window.list` works reliably
- `screen.capture` is validated

Do not keep two active control paths longer than necessary once the pipe path is trusted.

## Phase 6, cleanup

Only remove:
- prototype request/response files
- temp captures beyond retention
- stale logs
- abandoned prototype launchers that are no longer referenced

Do not remove active host state or the currently configured client path.

## Validation after each phase

- `openclaw status` still works
- Telegram chat still responds
- Gmail/calendar automation still works
- default route remains unchanged
- no new firewall-driven network dependence was introduced
