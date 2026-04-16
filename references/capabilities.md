# Capability surface

## Initial capability registry

Start narrow. A good first registry is:

- `health`
- `capabilities`
- `window.list`
- `window.focus`
- `screen.capture`
- `clipboard.getText`
- `clipboard.setText`
- `browser.openUrl`
- `shell.revealPath`

Add COM-backed actions later only after the transport and worker model is stable.

## Rollout order

### Stage 1, read-mostly
- `health`
- `capabilities`
- `window.list`
- `screen.capture`
- `clipboard.getText`

### Stage 2, low-risk action
- `browser.openUrl`
- `shell.revealPath`
- `clipboard.setText`

### Stage 3, best-effort desktop control
- `window.focus`
- `window.restore`

### Stage 4, COM-backed app actions
- `excel.openWorkbook`
- `outlook.createDraft`
- `explorer.open`

## Avoid at first

Do not start with:
- arbitrary PowerShell execution
- generic COM eval
- send-keys injection
- registry writes
- service management
- system-wide configuration changes

## Result conventions

Return enough detail for retries and auditing.

Examples:
- whether a target matched
- whether an action was attempted
- whether the intended effect was confirmed
- how long it took
- whether the result was partial or best-effort
