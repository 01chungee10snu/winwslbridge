#!/usr/bin/env bash
set -euo pipefail

BRIDGE_ROOT="${OPENCLAW_BRIDGE_ROOT:-/home/brienz311/.openclaw/workspace/state/bridge}"
WIN_SHARE_BASE="${OPENCLAW_BRIDGE_WINDOWS_SHARE:-/mnt/c/OpenClawBridge}"

mkdir -p "$WIN_SHARE_BASE/bin" "$WIN_SHARE_BASE/state/requests" "$WIN_SHARE_BASE/state/responses" "$WIN_SHARE_BASE/logs" "$WIN_SHARE_BASE/tmp"
cp "$BRIDGE_ROOT/bin/windows-bridge-fileq.ps1" "$WIN_SHARE_BASE/bin/windows-bridge-fileq.ps1"
cp "$BRIDGE_ROOT/bin/setup-windows-bridge.ps1" "$WIN_SHARE_BASE/bin/setup-windows-bridge.ps1"

echo "Seeded Windows bridge files into $WIN_SHARE_BASE"
echo "Next on Windows:"
echo "  powershell -ExecutionPolicy Bypass -File C:\\OpenClawBridge\\bin\\setup-windows-bridge.ps1"
echo "  powershell -ExecutionPolicy Bypass -File C:\\OpenClawBridge\\bin\\windows-bridge-fileq.ps1 -BridgeRoot C:\\OpenClawBridge"
