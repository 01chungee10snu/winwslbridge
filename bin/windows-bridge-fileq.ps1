param(
  [string]$BridgeRoot = 'C:\OpenClawBridge',
  [int]$IdleTimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'

$stateDir = Join-Path $BridgeRoot 'state'
$reqDir = Join-Path $stateDir 'requests'
$resDir = Join-Path $stateDir 'responses'
$tmpDir = Join-Path $BridgeRoot 'tmp'
$logDir = Join-Path $BridgeRoot 'logs'

foreach ($dir in @($BridgeRoot, $stateDir, $reqDir, $resDir, $tmpDir, $logDir)) {
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

function New-Response($ok, $action, $result, $error, $requestId) {
  return [ordered]@{
    ok = $ok
    action = $action
    result = $result
    error = $error
    requestId = $requestId
    handledAt = (Get-Date).ToString('o')
  }
}

function Write-ResponseFile($Path, $Response) {
  $tmpPath = $Path + '.tmp'
  $json = $Response | ConvertTo-Json -Depth 8
  [System.IO.File]::WriteAllText($tmpPath, $json, [System.Text.Encoding]::UTF8)
  [System.IO.File]::Copy($tmpPath, $Path, $true)
  Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
}

function Get-RequestContext($RequestFile) {
  $reqPath = $RequestFile.FullName
  $reqName = $RequestFile.Name
  $fallbackId = [IO.Path]::GetFileNameWithoutExtension($reqName)
  $raw = $null
  $readRetries = 0
  while ($readRetries -lt 3) {
    try {
      $bytes = [System.IO.File]::ReadAllBytes($reqPath)
      $raw = [System.Text.Encoding]::UTF8.GetString($bytes)
      if ($raw.Length -gt 0 -and $raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
      break
    }
    catch {
      $readRetries++
      Start-Sleep -Milliseconds 100
    }
  }
  if ($null -eq $raw) { throw $_.Exception }
  $body = $raw | ConvertFrom-Json -ErrorAction Stop
  $requestId = if ([string]::IsNullOrWhiteSpace([string]$body.id)) { $fallbackId } else { [string]$body.id }
  return [ordered]@{
    requestPath = $reqPath
    requestName = $reqName
    fallbackId = $fallbackId
    requestId = $requestId
    body = $body
  }
}

function Get-Capabilities() {
  $caps = [ordered]@{}
  $caps['health'] = $true
  $caps['capabilities'] = $true
  $caps['window.list'] = $true
  $caps['window.active'] = $true
  $caps['screen.capture'] = $true
  $caps['window.focus'] = $true
  $caps['browser.openUrl'] = $false
  return $caps
}

function Get-WindowList() {
  Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public static class WindowEnum {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
"@
  $items = New-Object System.Collections.Generic.List[object]
  $callback = [WindowEnum+EnumWindowsProc]{
    param($hWnd, $lParam)
    if (-not [WindowEnum]::IsWindowVisible($hWnd)) { return $true }
    $sb = New-Object System.Text.StringBuilder 1024
    [void][WindowEnum]::GetWindowText($hWnd, $sb, $sb.Capacity)
    $title = $sb.ToString()
    if ([string]::IsNullOrWhiteSpace($title)) { return $true }
    $pidRef = [uint32]0
    [void][WindowEnum]::GetWindowThreadProcessId($hWnd, [ref]$pidRef)
    $procName = $null
    try { $procName = (Get-Process -Id $pidRef -ErrorAction Stop).ProcessName } catch {}
    $items.Add([ordered]@{
      hwnd = $hWnd.ToInt64()
      title = $title
      pid = $pidRef
      process = $procName
    }) | Out-Null
    return $true
  }
  [WindowEnum]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
  return $items
}

function Get-ActiveWindow() {
  Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class ActiveWin {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
"@
  $hWnd = [ActiveWin]::GetForegroundWindow()
  if ($hWnd -eq [IntPtr]::Zero) {
    return [ordered]@{ found = $false }
  }
  $sb = New-Object System.Text.StringBuilder 1024
  [void][ActiveWin]::GetWindowText($hWnd, $sb, $sb.Capacity)
  $title = $sb.ToString()
  $pidRef = [uint32]0
  [void][ActiveWin]::GetWindowThreadProcessId($hWnd, [ref]$pidRef)
  $procName = $null
  try { $procName = (Get-Process -Id $pidRef -ErrorAction Stop).ProcessName } catch {}
  return [ordered]@{
    found = $true
    hwnd = $hWnd.ToInt64()
    title = $title
    pid = $pidRef
    process = $procName
  }
}

function Focus-Window($TitleContains) {
  $windows = Get-WindowList
  $needle = [string]$TitleContains
  foreach ($win in $windows) {
    $title = [string]$win.title
    if ([string]::IsNullOrWhiteSpace($title)) { continue }
    if ($title.Contains($needle)) {
      Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class FocusSetter {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
}
"@
      $hWnd = [IntPtr]::new([int64]$win.hwnd)
      $wasMinimized = [FocusSetter]::IsIconic($hWnd)
      $restoreResult = [FocusSetter]::ShowWindowAsync($hWnd, 9)
      Start-Sleep -Milliseconds 80
      $bringToTopResult = [FocusSetter]::BringWindowToTop($hWnd)
      Start-Sleep -Milliseconds 50
      $foregroundResult = [FocusSetter]::SetForegroundWindow($hWnd)
      return [ordered]@{
        matched = $true
        hwnd = $win.hwnd
        title = $title
        activationAttempted = $true
        wasMinimized = $wasMinimized
        restoreAttempted = $true
        restoreResult = $restoreResult
        bringToTopAttempted = $true
        bringToTopResult = $bringToTopResult
        foregroundAttempted = $true
        foregroundResult = $foregroundResult
      }
    }
  }
  return [ordered]@{ matched = $false; query = $TitleContains; activationAttempted = $false }
}

function Capture-Screen($BridgeRoot) {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bitmap.Size)

    $fileName = 'capture-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.png'
    $outPath = Join-Path (Join-Path $BridgeRoot 'tmp') $fileName
    $bitmap.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $graphics.Dispose()
    $bitmap.Dispose()

    return [ordered]@{
      path = $outPath
      fileName = $fileName
      width = $bounds.Width
      height = $bounds.Height
    }
  }
  catch {
    return [ordered]@{
      captureError = $_.Exception.Message
    }
  }
}

Write-Host "OpenClaw file-queue bridge watching $reqDir (idle timeout: ${IdleTimeoutSeconds}s)"
$lastActivity = Get-Date
while ($true) {
  $requests = Get-ChildItem -Path $reqDir -Filter *.json -File | Sort-Object LastWriteTime
  foreach ($req in $requests) {
    $context = $null
    try {
      $context = Get-RequestContext -RequestFile $req
      $body = $context.body
      $action = [string]$body.action
      $actionLower = $action.ToLowerInvariant()
      $requestId = $context.requestId
            $response = $null
      if ($actionLower -eq 'health') {
        $response = New-Response $true 'health' @{ status = 'ok'; mode = 'fileq'; session = 'interactive-user' } $null $requestId
      }
      if (($null -eq $response) -and $actionLower -eq 'capabilities') {
        $response = New-Response $true 'capabilities' (Get-Capabilities) $null $requestId
      }
      if (($null -eq $response) -and $actionLower -eq 'window.list') {
        $response = New-Response $true 'window.list' (Get-WindowList) $null $requestId
      }
      if (($null -eq $response) -and $actionLower -eq 'window.active') {
        $response = New-Response $true 'window.active' (Get-ActiveWindow) $null $requestId
      }
      if (($null -eq $response) -and $actionLower -eq 'screen.capture') {
        $cap = Capture-Screen -BridgeRoot $BridgeRoot
        if ($cap.captureError) {
          $response = New-Response $false 'screen.capture' $null $cap.captureError $requestId
        } else {
          $response = New-Response $true 'screen.capture' $cap $null $requestId
        }
      }
      if (($null -eq $response) -and $actionLower -eq 'window.focus') {
        $titleContains = [string]$body.args.titleContains
        if ([string]::IsNullOrWhiteSpace($titleContains) -and $body.args.titleContainsBase64) {
          $titleContains = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String([string]$body.args.titleContainsBase64))
        }
        $response = New-Response $true 'window.focus' (Focus-Window -TitleContains $titleContains) $null $requestId
      }
      if ($null -eq $response) {
        $response = New-Response $false $action $null ("unsupported action normalized=[$actionLower]") $requestId
      }
      $outPath = Join-Path $resDir ($requestId + '.json')
      Write-ResponseFile -Path $outPath -Response $response
      if ($context -and $context.requestPath) {
        Remove-Item -LiteralPath $context.requestPath -Force -ErrorAction SilentlyContinue
      }
    }
    catch {
      $err = $_.Exception.Message
      $requestId = if ($context -and $context.requestId) { $context.requestId } elseif ($req) { [IO.Path]::GetFileNameWithoutExtension($req.Name) } else { [guid]::NewGuid().ToString() }
      $action = if ($context -and $context.body -and $context.body.action) { [string]$context.body.action } else { 'error' }
      $response = New-Response $false $action $null $err $requestId
      $outPath = Join-Path $resDir ($requestId + '.json')
      Write-ResponseFile -Path $outPath -Response $response
      if ($context -and $context.requestPath) {
        Remove-Item -LiteralPath $context.requestPath -Force -ErrorAction SilentlyContinue
      }
      elseif ($req) {
        Remove-Item -LiteralPath $req.FullName -Force -ErrorAction SilentlyContinue
      }
    }
  }
  if ($requests.Count -gt 0) {
    $lastActivity = Get-Date
  }
  elseif (((Get-Date) - $lastActivity).TotalSeconds -ge $IdleTimeoutSeconds) {
    Write-Host "Idle timeout reached ($IdleTimeoutSeconds seconds). Exiting."
    break
  }
  Start-Sleep -Milliseconds 250
}
