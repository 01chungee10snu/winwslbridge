param(
  [string]$BridgeRoot = 'C:\OpenClawBridge',
  [string]$WorkspaceRoot = 'C:\Users\Administrator\AppData\Local\OpenClawBridgeSeed'
)

$ErrorActionPreference = 'Stop'

$dirs = @(
  $BridgeRoot,
  (Join-Path $BridgeRoot 'bin'),
  (Join-Path $BridgeRoot 'state'),
  (Join-Path $BridgeRoot 'state\requests'),
  (Join-Path $BridgeRoot 'state\responses'),
  (Join-Path $BridgeRoot 'logs'),
  (Join-Path $BridgeRoot 'tmp')
)

foreach ($dir in $dirs) {
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
}

Write-Host "Bridge directories ready under $BridgeRoot"
Write-Host 'Copy windows-bridge-fileq.ps1 into the bin directory if it is not already there.'
Write-Host "Suggested run command: powershell -ExecutionPolicy Bypass -File $BridgeRoot\bin\windows-bridge-fileq.ps1 -BridgeRoot $BridgeRoot"
