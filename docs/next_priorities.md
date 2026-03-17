# PetSpace 현재 상태 & 우선순위

> 기준일: 2026-03-17  
> 최신 커밋: `831a721`

---

## 전체 개발 완료 현황

| 커밋 | 내용 | 상태 |
|------|------|------|
| `c080c2f` | Phase 1 — 탭 순서, Health UseCase, MY 프로필 | ✅ |
| `7c1186a` | Phase 2 — 감정분석 → 피드 공유 | ✅ |
| `02fadb4` | Phase 3 — 북마크, Realtime, 멀티이미지 | ✅ |
| `434c13e` | Phase 4 — emotion_result 분리, BLoC 테스트 | ✅ |
| `a91d859` | Supabase SQL 스키마 수정 + saved_posts | ✅ |
| `bb2477f` | GitHub Actions CI/CD | ✅ |
| `e558fa8` | 코드 리뷰 — 크래시/누수/딥링크/데드코드 | ✅ |
| `8188f17` | 기술 부채 — 색상 토큰, DataSource 분리, 테스트 | ✅ |
| `831a721` | Firebase 초기화 + Play Store 배포 준비 | ✅ |

---

## 🔴 우선순위 1 — Play Store 제출 전 필수 (정현이 직접 해야 함)

### 1-1. 릴리즈 서명 키 생성 (로컬에서 1회)

```bash
keytool -genkey -v \
  -keystore android/petspace-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias petspace \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=PetSpace, OU=Jena, O=Jena, L=Seoul, S=Seoul, C=KR"
```

그 후 `android/key.properties` 파일 생성 (예시: `android/key.properties.example` 참고).

### 1-2. `POST_NOTIFICATIONS` 권한 추가 (Android 13+)

`android/app/src/main/AndroidManifest.xml`에 추가 필요:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### 1-3. FCM 서비스 AndroidManifest 등록

`android/app/src/main/AndroidManifest.xml` `<application>` 태그 안에 추가:

```xml
<service
    android:name="com.google.firebase.messaging.FirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT"/>
    </intent-filter>
</service>
```

### 1-4. Supabase에서 `saved_posts` 테이블 생성

`supabase/petspace_setup.sql` 전체를 Supabase SQL Editor에서 실행 (한 번도 안 했다면).  
이미 실행했다면 아래 SQL만 추가 실행:

```sql
CREATE TABLE IF NOT EXISTS saved_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);
ALTER TABLE saved_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own saved posts" ON saved_posts
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
```

### 1-5. Supabase Realtime Publication 활성화

Supabase Dashboard → Database → Replication → `supabase_realtime` publication에  
`likes`, `comments`, `notifications` 테이블 추가.  
(또는 petspace_setup.sql PART 9 실행 시 자동 처리됨)

---

## 🟡 우선순위 2 — Play Store 제출 (정현이 직접)

### 2-1. Google Play Console 계정 생성
- [play.google.com/console](https://play.google.com/console)
- 개발자 등록비: $25 (1회)

### 2-2. 릴리즈 APK 빌드
```bash
cd pjh
flutter build apk --release --split-per-abi
# 또는 AAB (Play Store 권장)
flutter build appbundle --release
```
빌드 파일 위치: `build/app/outputs/bundle/release/app-release.aab`

### 2-3. Play Store 제출 체크리스트
- [ ] 앱 아이콘 (512×512 PNG)
- [ ] 스크린샷 (최소 2장, 권장 8장)
- [ ] 앱 설명 (한국어)
- [ ] 개인정보처리방침 URL
- [ ] 콘텐츠 등급 설문

---

## 🟢 우선순위 3 — 코드로 바로 가능 (Claude 진행 가능)

### 3-1. 유저 차단 기능 구현
`post_card.dart` L595 `// TODO: unblock user` — 차단 해제 UI 연결

### 3-2. 이메일 인증 활성화
`auth_repository_impl.dart`에 SMTP 설정 후 주석 처리된 이메일 인증 코드 3곳 활성화

### 3-3. Supabase Edge Function — FCM 알림 발송 구현
현재 `analyze-emotion` 함수만 있음.  
좋아요/댓글/팔로우 이벤트 발생 시 FCM 토큰으로 푸시 발송하는 함수 필요:

```
supabase/functions/send-notification/index.ts
```

### 3-4. 커뮤니티 포스트 기능
`community_posts` 테이블이 SQL에 있지만 앱에서 미사용.  
피드 탭 → 커뮤니티 탭 서브메뉴에서 데이터 연결 필요.

---

## 🔵 우선순위 4 — iOS 출시 준비 (Android 이후)

### 4-1. Firebase iOS 앱 등록
Firebase Console → 프로젝트 설정 → iOS 앱 추가  
→ `GoogleService-Info.plist` 다운로드 → `ios/Runner/` 에 배치

### 4-2. `firebase_options.dart` iOS 값 채우기
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: '...',    // GoogleService-Info.plist → API_KEY
  appId: '...',     // GoogleService-Info.plist → GOOGLE_APP_ID
  ...
);
```

### 4-3. APNs 인증키 설정
Apple Developer Program → APNs 키 생성 → Firebase Console 등록

### 4-4. App Store Connect 제출
- Apple Developer Program: $99/년
- Xcode로 Archive + Upload

---

## 현재 앱 완성도

| 영역 | 완성도 | 비고 |
|------|--------|------|
| 인증 (카카오/구글/이메일) | 95% | 이메일 인증 비활성화 중 |
| 감정 분석 AI | 100% | Gemini API 연동 완료 |
| 피드 & 소셜 | 95% | 커뮤니티 포스트 데이터 미연결 |
| 건강관리 | 95% | 감정 트렌드 차트 데이터 확인 필요 |
| 북마크 | 90% | Supabase 테이블 생성 필요 |
| 채팅 | 90% | 기능 완성, 테스트 필요 |
| 푸시 알림 | 60% | FCM 코드 완성, Edge Function 미구현 |
| Play Store 배포 | 70% | 서명 키 + 제출 작업 필요 |

---

## 지금 당장 시작 순서 (권장)

```
1. [정현] Supabase SQL 실행 (saved_posts 테이블 + Realtime)
2. [정현] AndroidManifest POST_NOTIFICATIONS + FCM 서비스 등록
3. [정현] 릴리즈 서명 키 생성 → key.properties 파일 작성
4. [Claude] FCM 알림 발송 Edge Function 구현
5. [Claude] 커뮤니티 포스트 데이터 연결
6. [정현] flutter build appbundle --release → Play Store 제출
```
