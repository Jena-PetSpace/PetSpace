#!/bin/bash
# 시뮬레이터 UI 조작/캡처 래퍼 — idb + xcrun simctl
# 사용: sim.sh <subcommand> [args]
#   desc                 라벨 있는 요소를 center좌표와 함께 출력
#   find <substr>        라벨에 substr 포함된 요소만 출력
#   raw <max_y> <max_w>  좌상단(y<max_y, w<max_w) 무라벨 포함 요소 출력
#   tap X Y              탭
#   text "..."           포커스된 필드에 텍스트 입력
#   key NAME             하드웨어 키 (return, delete 등)
#   swipe x1 y1 x2 y2    스와이프
#   shot <path>          스크린샷 저장
set -e
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
U="${SIM_UDID:-7CBE4DEF-45EA-4E8D-B40D-73D836289644}"
cmd="$1"; shift || true

case "$cmd" in
  desc)
    idb ui describe-all --udid "$U" 2>/dev/null | python3 -c "
import json,sys
for e in json.load(sys.stdin):
    lbl=e.get('AXLabel'); f=e.get('frame'); t=e.get('type')
    if lbl:
        cx=f['x']+f['width']/2; cy=f['y']+f['height']/2
        print(f'{int(cx):4d},{int(cy):4d}  {t:14s} {lbl!r}')"
    ;;
  find)
    sub="$1"
    idb ui describe-all --udid "$U" 2>/dev/null | python3 -c "
import json,sys
sub='''$sub'''
for e in json.load(sys.stdin):
    lbl=e.get('AXLabel'); f=e.get('frame'); t=e.get('type')
    if lbl and sub in lbl:
        cx=f['x']+f['width']/2; cy=f['y']+f['height']/2
        print(f'{int(cx):4d},{int(cy):4d}  {t:14s} {lbl!r}')"
    ;;
  raw)
    my="${1:-9999}"; mw="${2:-9999}"
    idb ui describe-all --udid "$U" 2>/dev/null | python3 -c "
import json,sys
my=float('$my'); mw=float('$mw')
for e in json.load(sys.stdin):
    f=e.get('frame'); t=e.get('type'); lbl=e.get('AXLabel')
    if f['y']<my and 0<f['width']<mw:
        cx=f['x']+f['width']/2; cy=f['y']+f['height']/2
        print(f'{int(cx):4d},{int(cy):4d}  {t:16s} w={f[\"width\"]:.0f} h={f[\"height\"]:.0f} {lbl!r}')"
    ;;
  tap)    idb ui tap --udid "$U" "$1" "$2"; echo "tapped $1 $2" ;;
  text)   idb ui text --udid "$U" "$1"; echo "typed: $1" ;;
  key)    idb ui key --udid "$U" "$1"; echo "key: $1" ;;
  swipe)  idb ui swipe --udid "$U" "$1" "$2" "$3" "$4"; echo "swiped $1,$2 -> $3,$4" ;;
  shot)   xcrun simctl io booted screenshot "$1" >/dev/null 2>&1 && echo "saved: $1 ($(stat -f%z "$1") bytes)" ;;
  *) echo "unknown: $cmd"; exit 1 ;;
esac
