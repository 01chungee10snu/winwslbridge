param(
  [string]$BridgeRoot = 'C:\OpenClawBridge',
  [switch]$Fresh
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $BridgeRoot 'bin\windows-bridge-fileq.ps1'
$logDir = Join-Path $BridgeRoot 'logs'
$stateDir = Join-Path $BridgeRoot 'state'
$pidPath = Join-Path $stateDir 'bridge.pid'

foreach ($dir in @($logDir, $stateDir)) {
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
}
if (-not (Test-Path $scriptPath)) {
  throw "Bridge host not found: $scriptPath"
}

$existingPid = $null
if (Test-Path $pidPath) {
  $rawPid = (Get-Content $pidPath -Raw -ErrorAction SilentlyContinue).Trim()
  if ($rawPid -match '^\d+$') {
    $existingPid = [int]$rawPid
  }
}

$existingProc = $null
if ($existingPid) {
  $existingProc = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
}

$bridgeProcs = @()
try {
  $bridgeProcs = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction Stop | Where-Object {
    $_.CommandLine -and $_.CommandLine -like '*windows-bridge-fileq.ps1*' -and $_.CommandLine -like ('*' + $BridgeRoot + '*')
  }
}
catch {
  $bridgeProcs = @()
}

if ($existingProc -and -not $Fresh -and $bridgeProcs.Count -le 1) {
  [ordered]@{
    started = $false
    reason = 'already-running'
    processId = $existingPid
    pidFile = $pidPath
    scriptPath = $scriptPath
  } | ConvertTo-Json -Depth 4
  exit 0
}

if ($Fresh) {
  if ($existingProc) {
    Stop-Process -Id $existingPid -Force -ErrorAction SilentlyContinue
  }
  foreach ($procInfo in $bridgeProcs) {
    if (-not $existingPid -or $procInfo.ProcessId -ne $existingPid) {
      Stop-Process -Id $procInfo.ProcessId -Force -ErrorAction SilentlyContinue
    }
  }
  if (Test-Path $pidPath) { Remove-Item $pidPath -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 800
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stdoutLog = Join-Path $logDir ("bridge-stdout-" + $stamp + ".log")
$stderrLog = Join-Path $logDir ("bridge-stderr-" + $stamp + ".log")
$proc = Start-Process powershell -ArgumentList @('-ExecutionPolicy','Bypass','-File',$scriptPath,'-BridgeRoot',$BridgeRoot) -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -WindowStyle Minimized -PassThru
$proc.Id | Set-Content -Path $pidPath -Encoding ascii
Start-Sleep -Milliseconds 800
$alive = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue

[ordered]@{
  started = [bool]$alive
  processId = $proc.Id
  pidFile = $pidPath
  scriptPath = $scriptPath
  stdoutLog = $stdoutLog
  stderrLog = $stderrLog
} | ConvertTo-Json -Depth 4
