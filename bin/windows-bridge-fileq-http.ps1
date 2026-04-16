param(
  [string]$BridgeRoot = 'C:\OpenClawBridge',
  [int]$Port = 4765
)

$ErrorActionPreference = 'Stop'

$stateDir = Join-Path $BridgeRoot 'state'
$tmpDir = Join-Path $BridgeRoot 'tmp'
$logDir = Join-Path $BridgeRoot 'logs'
foreach ($dir in @($BridgeRoot, $stateDir, $tmpDir, $logDir)) {
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

function New-Response($ok, $action, $result, $error) {
  return [ordered]@{
    ok = $ok
    action = $action
    result = $result
    error = $error
    handledAt = (Get-Date).ToString('o')
  }
}

function Get-Capabilities() {
  return [ordered]@{
    health = $true
    capabilities = $true
    'window.list' = $true
    'screen.capture' = $true
    'window.focus' = $false
    'browser.openUrl' = $false
  }
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
    $items.Add([ordered]@{ hwnd = $hWnd.ToInt64(); title = $title; pid = $pidRef; process = $procName }) | Out-Null
    return $true
  }
  [WindowEnum]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
  return $items
}

function Capture-Screen($BridgeRoot) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bitmap.Size)
  $fileName = 'capture-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.png'
  $outPath = Join-Path (Join-Path $BridgeRoot 'tmp') $fileName
  $bitmap.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose(); $bitmap.Dispose()
  return [ordered]@{ path = $outPath; fileName = $fileName; width = $bounds.Width; height = $bounds.Height }
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Host "OpenClaw HTTP bridge listening on http://127.0.0.1:$Port/"

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $encoding = if ($ctx.Request.ContentEncoding) { $ctx.Request.ContentEncoding } else { [System.Text.Encoding]::UTF8 }
    $reader = New-Object System.IO.StreamReader($ctx.Request.InputStream, $encoding)
    $raw = $reader.ReadToEnd()
    $body = if ([string]::IsNullOrWhiteSpace($raw)) { @{} } else { $raw | ConvertFrom-Json }
    $action = [string]$body.action
    if ([string]::IsNullOrWhiteSpace($action) -and $ctx.Request.HttpMethod -eq 'GET') {
      $action = 'health'
    }
    switch ($action) {
      'health' { $resp = New-Response $true 'health' @{ status = 'ok'; mode = 'http'; session = 'interactive-user' } $null }
      'capabilities' { $resp = New-Response $true 'capabilities' (Get-Capabilities) $null }
      'window.list' { $resp = New-Response $true 'window.list' (Get-WindowList) $null }
      'screen.capture' { $resp = New-Response $true 'screen.capture' (Capture-Screen -BridgeRoot $BridgeRoot) $null }
      default { $resp = New-Response $false $action $null 'unsupported action' }
    }
  }
  catch {
    $resp = New-Response $false 'error' $null $_.Exception.Message
  }
  $json = $resp | ConvertTo-Json -Depth 8
  $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
  $ctx.Response.ContentType = 'application/json; charset=utf-8'
  $ctx.Response.OutputStream.Write($buffer, 0, $buffer.Length)
  $ctx.Response.OutputStream.Close()
}
