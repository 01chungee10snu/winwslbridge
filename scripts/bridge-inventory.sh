#!/usr/bin/env bash
set -euo pipefail

echo "== openclaw status =="
openclaw status || true

echo
echo "== wsl kernel =="
uname -a || true

echo
echo "== routes =="
ip route || true

echo
echo "== resolv.conf =="
cat /etc/resolv.conf || true

echo
echo "== WSL interop binfmt =="
cat /proc/sys/fs/binfmt_misc/WSLInterop 2>/dev/null || true

echo
echo "== drvfs mounts =="
mount | grep -E '/mnt/c|/mnt/d|drvfs' || true

echo
echo "== windows exe smoke =="
for exe in \
  /mnt/c/Windows/System32/cmd.exe \
  /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
  /mnt/c/Windows/System32/notepad.exe; do
  if [ -e "$exe" ]; then
    echo "-- $exe"
    "$exe" 2>&1 | sed -n '1,3p' || true
  fi
done
