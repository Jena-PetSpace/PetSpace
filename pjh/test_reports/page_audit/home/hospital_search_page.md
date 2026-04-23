# lib/features/home/presentation/pages/hospital_search_page.dart

**감사일:** 2026-04-23
**감사자:** Claude Code
**페이지 LOC:** 1448줄 (Phase 3에서 유일 페이지, 복잡도 최상급)

---

## 📍 페이지 개요

- **진입 라우트:** home 탭 내부 기능 (홈 대시보드 → 동물병원 찾기 진입 추정)
- **BLoC 의존성:** 없음 — **전체 StatefulWidget + Supabase/API 직접 호출**
- **상위 탭:** 홈 기능
- **로그인 필요:** 추정 필요 (즐겨찾기 기능 때문)
- **Scaffold 구조:** PopScope → Scaffold → SafeArea → Column(배너 + 검색바 + 카테고리바 + Expanded(Stack(지도 + 오버레이 + 바텀시트)))

---

## 🎯 상호작용 요소 카탈로그

### 검색바
| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 1 | TextField onSubmitted | 1215 | 검색어 입력 후 엔터 | `_searchByKeyword` → Kakao REST API | 동일 | ✅ |
| 2 | IconButton (clear) | 1221-1224 | 검색어 지우기 X | 검색어 초기화 | 동일 | ✅ |
| 3 | TextField onChanged | 1242 | 입력 중 | `setState(() {})`로 X 버튼 표시 갱신 | 동일 | ⚠️ |

### 위치 에러 배너
| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 4 | GestureDetector | 1259-1262 | "재시도" | `_getLocation` 재호출 | 동일 | ✅ |

### 카테고리 바 (5개)
| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 5 | GestureDetector × 5 | 1280-1311 | 내장소/동물병원/약국/카페/미용실 | `_searchCategory(i)` | 동일 | ✅ |

### 지도 오버레이
| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 6 | GestureDetector (my loc) | 818-822 | "내 위치로" 버튼 | `_moveToMyLocation` | 동일 | ✅ |
| 7 | GestureDetector × 3 | 835-873 | 반경 선택 1km/3km/5km | 반경 변경 + 카메라 이동 + 재검색 | 동일 | ✅ |
| 8 | GestureDetector | 920-921 | "이 지역 재검색" | `_reSearchHere` | 동일 | ✅ |

### 지도 네이티브 이벤트
| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 9 | Label Click Stream | 298-306 | 지도 마커 탭 | `_selectPlace(place)` | 동일 | ✅ |
| 10 | Camera Move End | 308-318 | 지도 이동 종료 | `_isFollowingLocation=false` + `_showReSearchButton=true` | suppressCameraMoveEvent 가드 있음 | ✅ |

### 바텀시트
| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 11 | GestureDetector onVerticalDragUpdate | 983 | 시트 드래그 | `_onSheetDrag` → collapsed/half/full 전환 | 동일 | ✅ |
| 12 | GestureDetector onTap | 984-992 | 시트 헤더 탭 | full↔half 토글 | 동일 | ✅ |
| 13 | GestureDetector × N | 1345-1400 | 장소 리스트 아이템 | `_selectPlace(place)` | 동일 | ✅ |
| 14 | GestureDetector (bookmark) | 1389-1395 | 리스트 내 북마크 아이콘 | `_toggleFavorite(place)` | **로컬 Set만 저장, 서버 저장 없음** | ❌ |
| 15 | GestureDetector | 1063-1072 | 상세 뷰 "목록으로" | `_closeDetail` | 동일 | ✅ |
| 16 | GestureDetector | 1075-1085 | 상세 뷰 북마크 | `_toggleFavorite(place)` | **로컬만** | ❌ |
| 17 | GestureDetector | 1150-1157 | "전화" 버튼 | `canLaunchUrl(tel:) → launchUrl` | 동일 | ✅ |
| 18 | GestureDetector | 1159-1164 | "길찾기" 버튼 | `_openKakaoMapDirections` → 외부 카카오맵 | 동일 | ✅ |
| 19 | GestureDetector | 1172-1177 | "리뷰·상세" 버튼 | `_openKakaoMapDetail` → 외부 카카오맵 | 동일 | ✅ |
| 20 | GestureDetector | 1179-1184 | "공유" 버튼 | `Share.share(name, address, url)` | 동일 | ✅ |

### 시스템
| # | 요소 타입 | 라인 | 요소 설명 | 기대 동작 | 실제 동작 | 상태 |
|---|---------|-----|---------|---------|---------|------|
| 21 | PopScope | 772-781 | 뒤로가기 인터셉트 | full → half, detail → list, 아니면 정상 pop | 동일 | ✅ |

**상호작용 요소 합계:** 21개 (이벤트/드래그/시스템 포함)

---

## 🎨 UI 요소

### 레이아웃 구조
- PopScope → Scaffold → SafeArea → Column
  - _buildLocationBanner (권한 에러 시)
  - _buildSearchBar
  - _buildCategoryBar (가로 스크롤)
  - Expanded(Stack):
    - Positioned.fill(KakaoMap)
    - _buildMapOverlayButtons (우측 하단 FAB 세트)
    - _buildSearchingIndicator (검색 중)
    - _buildReSearchButton (카메라 이동 후)
    - _buildBottomSheet (collapsed/half/full 3단계)

### 스크롤
- [x] 카테고리 바 가로 스크롤
- [x] 장소 리스트 `ListView.separated`
- [ ] BouncingScrollPhysics 미적용

### Safe Area
- [x] SafeArea 적용 (line 785)
- `resizeToAvoidBottomInset: false` — 키보드 올라와도 레이아웃 안 밀림 (의도적)

### 리소스 관리
- [x] `_labelClickSub?.cancel()` (line 162)
- [x] `_cameraMoveEndSub?.cancel()` (line 163)
- [x] `_listScrollController.dispose()` (line 164)
- [x] `_searchController.dispose()` (line 165)
- [x] `_searchFocusNode.dispose()` (line 166)
- ⚠️ `_mapController` 명시적 dispose 없음 — KakaoMap이 자체 처리하는지 확인 필요

### 바텀시트 시스템
- 3단계: `_SheetSize.collapsed(56.h)` / `half(200~280)` / `full(screen - 120 - topPad)`
- 디테일 뷰: 0.42 * screenH (clamp 320~420)
- 상태 전환: 드래그 + 탭 + 마커 선택 + 상세 열기로 자동 조정
- `_syncMapPaddingToSheet` — 시트 높이만큼 지도 padding 조정 (카메라 중심 보정)

---

## 🔄 상태 변화

| 상태 | 조건 | 렌더링 |
|------|------|--------|
| 초기 로딩 | `_position == null && _locationError == null` | 지도 자리에 CircularProgressIndicator |
| 위치 에러 | `_locationError != null` | 상단 빨간 배너 (재시도 버튼) |
| 검색 중 | `_searching = true` | 상단 "검색 중..." 카드 |
| 재검색 가능 | `_showReSearchButton = true` | 상단 "이 지역 재검색" 버튼 |
| 빈 결과 | `_places.isEmpty` | EmptyState ("🔍 N km 이내에 없어요") |
| 상세 뷰 | `_showDetail && _selectedPlace != null` | 바텀시트 → 상세 렌더링 |

---

## 🔗 외부 의존성

### API 호출
- **Kakao Local REST API** (line 439-449):
  - `https://dapi.kakao.com/v2/local/search/keyword.json`
  - Header: `Authorization: KakaoAK ${ApiConfig.kakaoRestApiKey}`
  - Timeout 10초

### 외부 앱 / URL Scheme
- `tel:${phone}` — 전화 걸기
- `https://map.kakao.com/link/search/${name}` — 카카오맵 장소 검색
- `https://map.kakao.com/link/to/${name},${lat},${lng}` — 카카오맵 길찾기
- `Share.share(text)` — 시스템 공유 시트

### 권한 요청
- 위치 (Geolocator — Info.plist `NSLocationWhenInUseUsageDescription` 필요)

### 네이티브 통합
- `kakao_maps_flutter` 로컬 패키지 (pjh/packages/kakao_maps_flutter)
- 마커 스타일 등록: `registerMarkerStyles`
- 이미지 자산: `assets/icons/map/my_location_dot.png`, `place_marker.png`
- 카테고리 아이콘: `assets/icons/category/cat_*.png`

---

## 🧪 시뮬레이터 동적 검증

### 검증 포인트 (많음)
- [ ] iOS 시뮬레이터 위치 설정 (Simulator → Features → Location → Custom Location)
- [ ] `Info.plist NSLocationWhenInUseUsageDescription` 노출 — 첫 진입 시 권한 다이얼로그
- [ ] 카카오맵 네이티브 렌더링 (KakaoMap Widget)
- [ ] 마커 스타일 등록 성공 여부 (fallback 로직 있음)
- [ ] 외부 카카오맵/전화/공유 링크 작동 (시뮬레이터 제한)

---

## 🐛 발견된 이슈

### Critical

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 1 | 🔴 **Critical** | 북마크(즐겨찾기) 서버 저장 없음 — **데이터 유실** | line 681-689, 1075-1085, 1389-1395: `_favoriteIds`는 `Set<String>` 로컬 변수. 앱 재시작 시 전부 삭제됨. "내 장소" 탭이 의미 없음 (`_categories[0]` isFavoriteTab이지만 실제 필터링 로직 없음) |

### High

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 2 | 🟠 High | "내 장소" 카테고리 필터링 미구현 | line 80 `isFavoriteTab: true`이지만 `_searchCategory`와 `_fetchPlaces`가 동일하게 Kakao API 호출 → 실제로는 "" (빈 쿼리) 검색이므로 결과 이상 |
| 3 | 🟠 High | 권한 거부 영구(`deniedForever`)시 설정 앱 이동 없음 | line 214-217: `_locationError` 메시지만 띄우고 끝 — 사용자가 수동으로 설정앱 가야 해결 가능. `openAppSettings()` 호출 권장 |
| 4 | 🟠 High | `Kakao REST API Key` 누락 시 실패 메시지 없음 | line 448: 401/403 응답 시 `response.statusCode == 200` 분기 외에는 로딩만 꺼짐. 사용자는 왜 비었는지 모름 |

### Medium

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 5 | 🟡 Medium | `_mapController` dispose 안 됨 | line 160-168: `_mapController` 자체 cleanup 코드 없음. kakao_maps_flutter 내부가 처리하는지 확인 필요 |
| 6 | 🟡 Medium | `onChanged: (_) => setState(() {})` 과도한 리빌드 | line 1242: 입력마다 전체 build. suffixIcon만 갱신하려면 별도 위젯 분리 권장 |
| 7 | 🟡 Medium | 검색 결과 15개 고정 | line 444 `size=15`. Pagination 또는 "더 보기" 없음 |
| 8 | 🟡 Medium | Timeout 에러 처리 | line 449 `.timeout(10s)` — 타임아웃 시 `catch (e)` 진입, 사용자 안내는 `_searching=false`만 |
| 9 | 🟡 Medium | "내 위치로" 버튼이 위치 없을 때 `_getLocation()` 재호출 | line 259-260: 위치 요청 중 여러 번 탭 시 중복 요청 가능 |
| 10 | 🟡 Medium | 카카오맵 외부 이동 `launchUrl` 실패 시 SnackBar만 | line 710, 723: 카카오맵 앱이 설치되지 않은 경우 웹 fallback 없음 (`LaunchMode.externalApplication`만 시도) |

### Low

| # | 심각도 | 요약 | 상세 |
|---|-------|------|------|
| 11 | 🟢 Low | `_suppressCameraMoveEvent` 불리언 플래그 | line 310: 상태 관리 복잡. 향후 리팩토링 시 State 머신으로 정리 |
| 12 | 🟢 Low | BouncingScrollPhysics 미적용 | iOS 감성 (카테고리 바 + 리스트뷰) |
| 13 | 🟢 Low | 카테고리 아이콘 색상 overlay | line 1298-1299: `color: selected ? Colors.white : null` — 아이콘 PNG 색상 강제 변환. SVG로 변환 권장 |

---

## ✅ 종합 평가

- **정상 동작:** 19/21 (즐겨찾기 관련 2건 ❌)
- **버그 발견:** 13건 (**Critical 1** / High 3 / Medium 6 / Low 3)
- **심각도:** **Critical** (북마크 데이터 유실)
- **iOS 특화 문제:**
  - Info.plist 위치 권한 ✅ (이전 Phase에서 확인)
  - 카카오맵 네이티브 패키지 pod install 성공 ✅
  - 시뮬레이터 위치 수동 설정 필요

### 권장 조치

- **즉시 수정 (Critical/High):**
  - #1: 북마크 Supabase `favorites` 테이블 연동 (또는 shared_preferences)
  - #2: "내 장소" 탭 별도 렌더 로직 (로컬 즐겨찾기 또는 서버 즐겨찾기 표시)
  - #3: `openAppSettings()` 호출 추가
  - #4: API 키 실패 시 안내 다이얼로그

- **다음 이터레이션:**
  - #5~10 (Medium)

- **모니터링:**
  - #11~13 (Low)

### 복잡도 평가

이 페이지는 PetSpace에서 가장 복잡한 페이지 중 하나:
- 비동기 지도 컨트롤러 라이프사이클
- 3단계 바텀시트 상태 머신
- Kakao REST API + Geolocator + kakao_maps_flutter 네이티브 통합
- 외부 앱 딥링크 (tel / kakaomap)

→ 향후 BLoC 도입 시 **HospitalSearchBloc**로 분리 필수. 현재 1448줄은 단일 StatefulWidget으로는 너무 큼.
