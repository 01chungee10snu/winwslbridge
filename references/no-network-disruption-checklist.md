# No-network-disruption checklist

## Goal

Keep OpenClaw online and keep the current WSL-to-internet path working while building the Windows bridge.

## Do not change during bridge rollout

- WSL default route
- WSL DNS generation strategy
- Windows NIC settings
- Hyper-V / WSL virtual switch configuration
- Windows firewall defaults
- OpenClaw gateway bind/auth path that is already working
- current Telegram, Gmail, or calendar automation path

## Safe rollout sequence

1. Capture a read-only inventory of the current state.
2. Create new bridge directories in parallel.
3. Validate the transport in isolation.
4. Enable one read-only capability.
5. Confirm OpenClaw network-dependent functions still work.
6. Expand capabilities gradually.
7. Clean only obsolete bridge artifacts after the new path is stable.

## Validation points after each major step

- `openclaw status` still succeeds
- current chat channel remains responsive
- calendar and mail automations still authenticate
- default route in WSL remains unchanged
- no new firewall or port prompts appeared unexpectedly

## Cleanup policy

Safe to remove:
- stale temp screenshots
- old request/response files in a prototype queue
- abandoned prototype scripts
- rotated logs older than the chosen retention window

Do not remove:
- active bridge host state
- active IPC handles or pipe metadata
- current launcher path in use by the thin client
- any live OpenClaw runtime files unrelated to the bridge
