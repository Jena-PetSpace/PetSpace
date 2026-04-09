# 병원/시설 찾기 기능 개발 문서

> 작성일: 2026-04-09  
> 브랜치: `win-android-release`  
> 커밋: `aa2dd4b`

---

## 개요

반려동물 관련 주변 시설(동물병원, 동물약국, 애견미용, 펫호텔, 펫샵)을 지도에서 탐색하고 전화/길찾기로 연결하는 기능.

---

## 구현 방식 변천 과정

### 1단계: 카카오맵 딥링크 (폐기)
- `kakaomap://` URI로 앱 실행
- 단점: 앱 내에서 지도를 직접 보여줄 수 없음

### 2단계: WebView + Kakao Maps JS SDK (폐기)
- WebView 안에 카카오맵 JS SDK를 로드하는 방식
- **실패 원인**: Kakao JS SDK가 `http://t1.daumcdn.net`에서 스크립트를 `document.write()`로 주입하는데, Android WebView가 HTTPS 페이지에서 HTTP 리소스를 차단함 (Mixed Content 정책)
- CSP `upgrade-insecure-requests` 패치 시도했으나 `document.write()` 방식은 우회 불가

### 3단계: flutter_map + Kakao Local REST API (현재) ✅
- **지도**: `flutter_map` 패키지 + OpenStreetMap 타일
- **장소 검색**: Kakao Local REST API (`https://dapi.kakao.com/v2/local/search/keyword.json`)
- **이유**: REST API는 도메인 등록 불필요, HTTP 블록 문제 없음

---

## 현재 기술 스택

| 항목 | 내용 |
|------|------|
| 지도 렌더링 | `flutter_map ^8.2.2` |
| 좌표 타입 | `latlong2 ^0.9.1` |
| 지도 타일 | OpenStreetMap 기본 타일 (POI 아이콘 포함) |
| 장소 검색 | Kakao Local REST API (반경 5km, 최대 15개) |
| API 인증 | `KakaoAK {REST_API_KEY}` 헤더 |
| 위치 | `geolocator` — getLastKnownPosition → getCurrentPosition 순서 |

---

## 주요 파일

```
lib/features/home/presentation/pages/hospital_search_page.dart  # 메인 페이지
lib/config/secrets.dart                                          # kakaoRestApiKey
lib/config/api_config.dart                                       # kakaoRestApiKey getter
lib/core/navigation/app_router.dart                              # /hospital 라우트 (ShellRoute 내)
android/app/src/main/AndroidManifest.xml                        # 위치 권한
```

---

## 핵심 구현 내용

### 바텀시트 3단계 구조
```dart
enum _SheetSize { collapsed, half, full }

// 반응형 높이 (ScreenUtil 기반 — 모든 기기 동일하게 표시)
case _SheetSize.half:
  return headerH + (itemSlotH * 3) - separatorH + listPadV; // 3개 정확히
```

### 목록 ↔ 상세 슬라이드 전환
- `_showDetail` 플래그로 `AnimatedSwitcher` + `SlideTransition` 전환
- 상세 뷰: 바텀시트 하단 42% / 지도 상단 58% 구조
- 안드로이드 뒤로가기 버튼: `PopScope`로 상세→목록 복귀

### 검색창 포커스 시 바텀시트 자동 닫힘
```dart
_searchFocusNode.addListener(() {
  if (_searchFocusNode.hasFocus && _sheetSize != _SheetSize.collapsed) {
    setState(() => _sheetSize = _SheetSize.collapsed);
  }
});
```

### 카카오맵 연동
```dart
// 앱 설치 시 카카오맵 앱으로, 없으면 웹으로
final appUri = Uri.parse('kakaomap://look?p=${place.lat},${place.lng}');
if (await canLaunchUrl(appUri)) { await launchUrl(appUri); return; }
// fallback: m.map.kakao.com
```

### 위치 권한 (AndroidManifest)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

---

## 알려진 한계 및 개선 계획

### POI (장소 아이콘) 부족 문제
- 현재 OSM 타일은 한국 로컬 데이터(편의점, 카페 등)가 카카오맵 대비 부족
- 카카오맵 수준의 한국 POI는 **Kakao Maps SDK (네이티브)** 가 필요

### 🚀 도메인 구매 후 개선 계획: Kakao Maps SDK 전환

Kakao Maps JS SDK는 **등록된 도메인이 필수**여서 현재 앱 환경(localhost/앱 내 WebView)에서 사용 불가했음.

도메인 구매 후 다음 두 가지 옵션 중 선택:

#### 옵션 A: `kakao_maps_flutter` 패키지 (권장)
- 네이티브 Kakao Maps SDK를 Flutter에 임베드
- 도메인 불필요 (Android 패키지명 + 키해시 등록만 필요)
- 카카오맵과 동일한 POI, 로드뷰 등 지원
- 카카오 개발자 콘솔에서 Android 플랫폼 등록 필요:
  - 패키지명: `com.petspace.app`
  - 키해시: `keytool`로 추출한 SHA-1

#### 옵션 B: WebView + Kakao Maps JS SDK
- 도메인 등록 후 WebView에서 로드
- 도메인: `https://your-domain.com`을 카카오 개발자 콘솔에 등록
- 기존 JS SDK 방식 재활용 가능

**→ 옵션 A (kakao_maps_flutter) 권장**: 네이티브라 성능/안정성 우수, 도메인 불필요

---

## 카테고리

| 이모지 | 라벨 | 검색 키워드 |
|--------|------|-------------|
| 🏥 | 동물병원 | 동물병원 |
| 💊 | 동물약국 | 동물약국 |
| ✂️ | 애견미용 | 애견미용 |
| 🐾 | 펫호텔 | 펫호텔 애견호텔 |
| 🛒 | 펫샵 | 펫샵 반려동물용품 |

---

## 오늘 작업 내역 (2026-04-09)

1. WebView → flutter_map + REST API 전면 전환
2. `/hospital` 라우트를 ShellRoute 내부로 이동 → 하단 탭 표시
3. AppBar 제거 (상단 타이틀 삭제)
4. 바텀시트 3개 반응형 고정 (ScreenUtil `.h` 기반)
5. 검색창 포커스 시 바텀시트 자동 collapse
6. 목록 → 상세 슬라이드 전환 (AnimatedSwitcher)
7. 상세 뷰: 지도 58% + 카드 42% 구조
8. 안드로이드 뒤로가기 버튼으로 상세 → 목록 복귀 (PopScope)
9. 지도 타일: OSM 기본 (POI 아이콘 표시)
10. 줌 레벨 상향: 초기 16, 장소 선택 시 17
11. 위치 권한 AndroidManifest 추가
