#!/bin/bash
# PetSpace 실기기 빌드 & 실행 스크립트
# iOS 26.4+ 에서는 Debug JIT 제한으로 --profile 사용

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================"
echo "PetSpace iOS 실기기 빌드 & 실행"
echo "========================================"

# ── 실기기 탐색 ────────────────────────────────────────
echo "▶ 연결된 iOS 기기 탐색..."
DEVICE_LINE=$(flutter devices 2>&1 | grep "ios " | grep -v "simulator" | head -1)

if [[ -z "$DEVICE_LINE" ]]; then
  echo "❌ 연결된 iOS 실기기를 찾을 수 없습니다."
  echo "   - iPhone을 USB로 연결했는지 확인"
  echo "   - Developer Mode 활성화 여부 확인"
  echo "   - iPhone에서 '이 컴퓨터 신뢰' 수락 확인"
  exit 1
fi

DEVICE_ID=$(echo "$DEVICE_LINE" | awk -F'•' '{print $2}' | xargs)
DEVICE_NAME=$(echo "$DEVICE_LINE" | awk -F'•' '{print $1}' | xargs)

echo "📱 Device: $DEVICE_NAME ($DEVICE_ID)"

# ── Clean & Build ──────────────────────────────────────
read -p "clean 후 재빌드할까요? (y/N): " DO_CLEAN
if [[ "$DO_CLEAN" == "y" || "$DO_CLEAN" == "Y" ]]; then
  echo "▶ flutter clean..."
  flutter clean > /dev/null
  echo "▶ flutter pub get..."
  flutter pub get > /dev/null
  echo "▶ pod install..."
  (cd ios && pod install > /dev/null 2>&1)
fi

# ── 기존 앱 삭제 여부 ───────────────────────────────────
read -p "기기에 설치된 기존 PetSpace 앱을 삭제하고 새로 설치할까요? (y/N): " DO_UNINSTALL
UNINSTALL_FLAG=""
if [[ "$DO_UNINSTALL" == "y" || "$DO_UNINSTALL" == "Y" ]]; then
  UNINSTALL_FLAG="--uninstall-first"
fi

# ── 실행 모드 선택 ─────────────────────────────────────
echo ""
echo "실행 모드:"
echo "  1) Profile   (기본 — iOS 26.4+ 권장, Hot Reload 없음)"
echo "  2) Release   (최적화 완료 바이너리)"
echo "  3) Debug     (Hot Reload 가능, iOS 26.4+에서는 JIT 제한으로 크래시 가능)"
read -p "선택 [1]: " MODE_CHOICE
MODE_CHOICE="${MODE_CHOICE:-1}"

case "$MODE_CHOICE" in
  1) MODE_FLAG="--profile" ;;
  2) MODE_FLAG="--release" ;;
  3) MODE_FLAG="" ;;
  *) MODE_FLAG="--profile" ;;
esac

# ── 실행 ───────────────────────────────────────────────
echo ""
echo "▶ flutter run $MODE_FLAG -d $DEVICE_ID $UNINSTALL_FLAG"
echo ""
flutter run $MODE_FLAG -d "$DEVICE_ID" $UNINSTALL_FLAG
