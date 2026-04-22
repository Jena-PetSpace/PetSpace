#!/bin/bash
# PetSpace iOS Integration Test Runner
# Usage: ./scripts/run_ios_integration_tests.sh

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

REPORTS_DIR="test_reports"
LOGS_DIR="$REPORTS_DIR/logs"
SCREENSHOTS_DIR="$REPORTS_DIR/screenshots"
mkdir -p "$LOGS_DIR" "$SCREENSHOTS_DIR"

# ── iPhone 17 시뮬레이터 탐색 & 부팅 ──────────────────────
DEVICE_ID=$(xcrun simctl list devices available | grep -E "iPhone 17 \(" | head -1 | grep -oE '[A-F0-9-]{36}')

if [[ -z "$DEVICE_ID" ]]; then
  echo "❌ iPhone 17 Simulator를 찾을 수 없습니다."
  exit 1
fi

echo "📱 Device: iPhone 17 ($DEVICE_ID)"

# 이미 부팅돼있는지 확인 후 부팅
if ! xcrun simctl list devices | grep "$DEVICE_ID" | grep -q "Booted"; then
  echo "▶ 시뮬레이터 부팅 중..."
  xcrun simctl boot "$DEVICE_ID" || true
  sleep 3
fi

open -a Simulator || true
sleep 2

# ── 테스트 실행 ────────────────────────────────────────
TOTAL=0
PASSED=0
FAILED=0
FAILED_TESTS=()

echo ""
echo "========================================"
echo "PetSpace iOS Integration Tests"
echo "========================================"

for test_file in integration_test/*_test.dart; do
  TOTAL=$((TOTAL + 1))
  test_name=$(basename "$test_file" .dart)
  log_file="$LOGS_DIR/${test_name}.log"

  echo ""
  echo "▶ [$TOTAL] Running: $test_name"

  if flutter test "$test_file" \
      -d "$DEVICE_ID" \
      --reporter expanded \
      > "$log_file" 2>&1; then
    echo "  ✅ PASSED"
    PASSED=$((PASSED + 1))
  else
    echo "  ❌ FAILED (see $log_file)"
    FAILED=$((FAILED + 1))
    FAILED_TESTS+=("$test_name")
  fi
done

# ── 결과 요약 ──────────────────────────────────────────
echo ""
echo "========================================"
echo "Test Results"
echo "========================================"
echo "Total:  $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do
    echo "  - $t"
  done
fi

# ── 간이 리포트 생성 ────────────────────────────────────
{
  echo "# PetSpace iOS Integration Test Report"
  echo ""
  echo "**Date:** $(date '+%Y-%m-%d %H:%M:%S')"
  echo "**Device:** iPhone 17 ($DEVICE_ID)"
  echo ""
  echo "## Summary"
  echo "| Metric | Value |"
  echo "|--------|-------|"
  echo "| Total  | $TOTAL |"
  echo "| Passed | $PASSED |"
  echo "| Failed | $FAILED |"
  echo ""
  echo "## Details"
  for log in "$LOGS_DIR"/*.log; do
    [[ -f "$log" ]] || continue
    name=$(basename "$log" .log)
    status="FAIL"
    if grep -qE "^All tests passed|✓.*tests passed" "$log" 2>/dev/null; then
      status="PASS"
    fi
    echo "- **$name**: $status — see \`$log\`"
  done
} > "$REPORTS_DIR/ios_test_report.md"

echo "📄 Report: $REPORTS_DIR/ios_test_report.md"
exit $FAILED
