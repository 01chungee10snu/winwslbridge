Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell -ExecutionPolicy Bypass -File C:\OpenClawBridge\bin\start-bridge.ps1 -BridgeRoot C:\OpenClawBridge -Fresh", 0, False
