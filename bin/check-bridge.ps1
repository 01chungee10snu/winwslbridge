param(
  [string]$BridgeRoot = 'C:\OpenClawBridge'
)

$ErrorActionPreference = 'Stop'
$stateDir = Join-Path $BridgeRoot 'state'
$pidPath = Join-Path $stateDir 'bridge.pid'
$requests = Join-Path $BridgeRoot 'state\requests'
$responses = Join-Path $BridgeRoot 'state\responses'
$logDir = Join-Path $BridgeRoot 'logs'

$bridgePid = $null
if (Test-Path $pidPath) {
  $rawPid = (Get-Content $pidPath -Raw -ErrorAction SilentlyContinue).Trim()
  if ($rawPid -match '^\d+$') {
    $bridgePid = [int]$rawPid
  }
}

$proc = $null
if ($bridgePid) {
  try {
    $proc = Get-Process -Id $bridgePid -ErrorAction Stop
  }
  catch {
    $proc = $null
  }
}

$latestStdout = Get-ChildItem $logDir -Filter 'bridge-stdout-*.log' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
$latestStderr = Get-ChildItem $logDir -Filter 'bridge-stderr-*.log' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1

[ordered]@{
  hostRunning = [bool]($null -ne $proc)
  processId = $bridgePid
  pidFile = $pidPath
  pidFileExists = (Test-Path $pidPath)
  requestDir = $requests
  requestDirExists = (Test-Path $requests)
  responseDir = $responses
  responseDirExists = (Test-Path $responses)
  requestCount = @((Get-ChildItem $requests -Filter *.json -File -ErrorAction SilentlyContinue)).Count
  responseCount = @((Get-ChildItem $responses -Filter *.json -File -ErrorAction SilentlyContinue)).Count
  latestStdoutLog = if ($latestStdout) { $latestStdout.FullName } else { $null }
  latestStderrLog = if ($latestStderr) { $latestStderr.FullName } else { $null }
} | ConvertTo-Json -Depth 4
