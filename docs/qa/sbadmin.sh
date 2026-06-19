#!/bin/bash
# Supabase GoTrue Admin 헬퍼 (테스트 계정 QA용)
# 사용: sbadmin.sh confirm <email>     해당 이메일 계정을 email_confirm 처리
#       sbadmin.sh find <email>        계정 조회(id, confirmed 여부)
#       sbadmin.sh delete <email>      계정 삭제(테스트 정리용)
set -e
URL="https://juukbctqzlrxfnivhgqe.supabase.co"
SR="$(supabase projects api-keys --project-ref juukbctqzlrxfnivhgqe 2>/dev/null | awk -F'|' '/service_role/{gsub(/ /,"",$2);print $2}')"
H=(-s -H "apikey: $SR" -H "Authorization: Bearer $SR")
cmd="$1"; email="$2"

uid_of() {
  curl "${H[@]}" "$URL/auth/v1/admin/users?per_page=200" | python3 -c "
import json,sys
em='''$email'''
d=json.load(sys.stdin)
for u in d.get('users',[]):
    if u.get('email')==em:
        print(u['id']); break
"
}

case "$cmd" in
  find)
    curl "${H[@]}" "$URL/auth/v1/admin/users?per_page=200" | python3 -c "
import json,sys
em='''$email'''
for u in json.load(sys.stdin).get('users',[]):
    if u.get('email')==em:
        print('id:',u['id']); print('email_confirmed_at:',u.get('email_confirmed_at')); print('created_at:',u.get('created_at'))
"
    ;;
  confirm)
    id="$(uid_of)"
    if [ -z "$id" ]; then echo "NOT FOUND: $email"; exit 1; fi
    curl "${H[@]}" -X PUT "$URL/auth/v1/admin/users/$id" \
      -H "Content-Type: application/json" -d '{"email_confirm":true}' \
      | python3 -c "import json,sys; u=json.load(sys.stdin); print('confirmed:', u.get('email_confirmed_at'))"
    ;;
  setpw)
    id="$(uid_of)"
    pw="$3"
    if [ -z "$id" ]; then echo "NOT FOUND: $email"; exit 1; fi
    curl "${H[@]}" -X PUT "$URL/auth/v1/admin/users/$id" \
      -H "Content-Type: application/json" -d "{\"password\":\"$pw\"}" \
      | python3 -c "import json,sys; u=json.load(sys.stdin); print('pw set for', u.get('email'))"
    ;;
  genotp)
    # type: magiclink | recovery  (기본 magiclink) — 이메일 발송 없이 OTP 회수
    typ="${3:-magiclink}"
    curl "${H[@]}" -X POST "$URL/auth/v1/admin/generate_link" \
      -H "Content-Type: application/json" -d "{\"type\":\"$typ\",\"email\":\"$email\"}" \
      | python3 -c "import json,sys; d=json.load(sys.stdin); print('otp:', d.get('email_otp')); print('err:', d.get('msg') or d.get('error_code') or '')"
    ;;
  resetonboarding)
    # public.users.is_onboarding_completed = false (온보딩 플로우 재캡처용)
    id="$(uid_of)"
    if [ -z "$id" ]; then echo "NOT FOUND: $email"; exit 1; fi
    curl "${H[@]}" -X PATCH "$URL/rest/v1/users?id=eq.$id" \
      -H "Content-Type: application/json" -H "Prefer: return=representation" \
      -d '{"is_onboarding_completed":false}' \
      | python3 -c "import json,sys; d=json.load(sys.stdin); print('is_onboarding_completed:', (d[0].get('is_onboarding_completed') if isinstance(d,list) and d else d))"
    ;;
  delete)
    id="$(uid_of)"
    if [ -z "$id" ]; then echo "NOT FOUND: $email"; exit 1; fi
    curl "${H[@]}" -X DELETE "$URL/auth/v1/admin/users/$id" -o /dev/null -w "deleted %{http_code}\n"
    ;;
  *) echo "usage: sbadmin.sh {find|confirm|setpw|delete} <email> [pw]"; exit 1 ;;
esac
