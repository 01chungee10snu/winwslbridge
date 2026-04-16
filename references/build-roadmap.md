# Build roadmap

## Stage 1, bootstrap

Deliverables:
- `scripts/bridge-inventory.sh`
- `scripts/bridgectl.py`
- bridge directory plan
- host skeleton source

Success criteria:
- inventory captured without disruption
- thin client produces valid request envelopes
- host skeleton compiles on Windows

## Stage 2, transport and health

Deliverables:
- functioning named pipe host
- `health`
- `capabilities`

Success criteria:
- WSL caller receives JSON health responses
- no network configuration changes were needed

## Stage 3, first useful worker

Deliverables:
- `window.list`
- `screen.capture`

Success criteria:
- bridge returns window metadata reliably
- screenshot files land under the fixed temp directory
- OpenClaw remains online throughout

## Stage 4, desktop actions

Deliverables:
- `browser.openUrl`
- `window.focus` best-effort
- `clipboard.getText` and `clipboard.setText`

Success criteria:
- actions are bounded by timeouts
- failures are explicit and non-destructive

## Stage 5, COM adapters

Deliverables:
- Explorer reveal/open
- Excel open workbook
- Outlook draft creation

Success criteria:
- adapters are action-based, not arbitrary script exec
- app-specific failures do not crash the bridge host

## Stage 6, cleanup and hardening

Deliverables:
- retention policy for logs and temp artifacts
- startup strategy for the bridge host in the interactive session
- stale worker cleanup

Success criteria:
- old artifacts are removed safely
- active state is never deleted
- rollback remains simple
