$startup = [System.Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startup 'OpenClawBridge.lnk'
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($shortcutPath)
$sc.TargetPath = 'wscript.exe'
$sc.Arguments = 'C:\OpenClawBridge\bin\start-bridge-hidden.vbs'
$sc.WorkingDirectory = 'C:\OpenClawBridge\bin'
$sc.WindowStyle = 7
$sc.Save()
Write-Output "Created: $shortcutPath"
