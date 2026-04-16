param(
  [string]$BridgeRoot = 'C:\OpenClawBridge'
)

$ErrorActionPreference = 'Stop'
$stateDir = Join-Path $BridgeRoot 'state'
$pidPath = Join-Path $stateDir 'bridge.pid'

if (Test-Path $pidPath) {
  $rawPid = Get-Content $pidPath -Raw -ErrorAction SilentlyContinue
  if ($rawPid -match '^\d+$') {
    $pid = [int]$rawPid
    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
  }
  Remove-Item $pidPath -Force -ErrorAction SilentlyContinue
}

powershell -ExecutionPolicy Bypass -File (Join-Path $BridgeRoot 'bin\start-bridge.ps1') -BridgeRoot $BridgeRoot -Fresh
