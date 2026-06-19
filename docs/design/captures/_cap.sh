#!/bin/bash
# Usage: _cap.sh <output_path>  — captures emulator screen via adb exec-out (binary-safe in bash)
ADB="/c/Users/wjdgu/AppData/Local/Android/Sdk/platform-tools/adb.exe"
OUT="$1"
"$ADB" exec-out screencap -p > "$OUT"
echo "saved: $OUT ($(stat -c%s "$OUT" 2>/dev/null || echo '?') bytes)"
