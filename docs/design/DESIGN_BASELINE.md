# DESIGN BASELINE — 펫페이스

> 현행 디자인 시스템의 단일 기준. 클로드 디자인 비교/개선의 출발점.
> 근거: `shared/themes/app_theme.dart` · `shared/widgets`(22개) · feature별 theme

---

## 1. 컬러 토큰

### 브랜드
| 토큰 | HEX | 의미 |
|---|---|---|
| primary | `#1E3A5F` | Deep Blue — 신뢰·전문성 |
| secondary | `#2C4482` | JENA Indigo — 리더십·혁신 |
| accent | `#0077B6` | Bright Blue — 기술 |
| highlight | `#FF6F61` | Coral Red — 고객 중심 |
| sub | `#5BC0EB` | Sky Blue — 네트워크 |

### 표면 / 텍스트
| 토큰 | HEX |
|---|---|
| background | `#F8F9FA` |
| surface / card | `#FFFFFF` |
| text primary | `#2D2D2D` |
| text secondary | `#757575` |
| text light | `#BDBDBD` |
| surfaceWarm / surfaceCool | `#FFF8E8` / `#F8F9FA` |

### 기능 컬러
| 기능 | HEX |
|---|---|
| emotion | `#FF6F61` |
| health | `#1E3A5F` |
| play | `#7E57C2` |
| fortune | `#FFB300` |
| quiz | `#0077B6` |
| walk | `#26A69A` |

### 상태 컬러
success `#4CAF50` · warning `#FF9800` · error `#E53935` · info `#0077B6`

### 감정 팔레트 (9종)
기쁨 `#5BC0EB` · 슬픔 `#2C4482` · 불안 `#FF6F61` · 호기심 `#0077B6` · 편안함 `#2E7D6B` · 흥분 `#E8A838` · 공포 `#6B3FA0` · 불편함 `#D4511E` · (졸림 deprecated)

### 파스텔 타일 (7종)
blue `#E6F1FB` · green `#EAF3DE` · peach `#FAECE7` · sand `#F1EFE8` · pink `#FBEAF0` · rose `#FCEBEB` · mint `#E1F5EE`

---

## 2. 타이포그래피
- 기본 폰트: **Pretendard** (PDF 요약서에 임베드 확인)
- 세부 스케일(h1~caption)은 `app_theme.dart`의 TextTheme 기준 — 클로드 디자인에 토큰화하여 등록 권장

---

## 3. 공용 컴포넌트 (shared/widgets 22개)

| 컴포넌트 | 용도 |
|---|---|
| custom_bottom_navigation_bar | 하단 5탭 네비 (중앙 FAB) |
| main_navigation_wrapper | 탭 셸 래퍼 |
| petspace_logo | 로고 |
| default_avatar / profile_image_picker | 아바타·프로필 이미지 |
| image_picker_widget / multi_image_picker / image_source_picker | 이미지 선택 |
| image_viewer_page / optimized_image | 이미지 뷰어·최적화 |
| upload_progress_widget | 업로드 진행 |
| section_header | 섹션 헤더 |
| empty_state_widget | 빈 상태 |
| error_dialog / error_snackbar / network_error_widget | 에러 표시 |
| shimmer_loading | 스켈레톤 로딩 |
| lazy_load_list | 무한 스크롤 |
| haptic_refresh_indicator | 당겨 새로고침 |
| animated_widgets / feedback_widgets | 애니메이션·피드백 |
| rate_limit_countdown | 요청 제한 카운트다운 |

> feature 전용 theme: `quiz_theme` · `mbti_theme` · `emotion_result_tokens` — 도메인 색채가 분기되어 있어, 클로드 디자인 등록 시 "공용 토큰 → feature override" 계층으로 정리 필요.

---

## 4. 클로드 디자인 비교 프레임 (화면별 작성 템플릿)

> 각 화면을 아래 표 한 행으로 평가. `USER_FLOW.md` 인벤토리 66행과 1:1 매핑.

```
### [화면명] (라우트)
- 현재 패턴:   (레이아웃·주요 컴포넌트·문제점)
- 디자인 원칙 위반:  (토큰 미사용 / 간격 불일치 / 위계 불명확 등)
- 개선 방향:   (구체 변경안)
- 클로드 디자인 액션:  (시스템 등록 / 컴포넌트 생성 / 재배치)
- 우선순위:   상/중/하
```

### 우선 적용 후보 (근거 있는 3선)
1. **/home** — 매거진 시안 + 레거시 카드 공존 과도기. 정보 위계·카드 일관성부터.
2. **/emotion result + /health result** — 핵심 가치 화면. 이미 리디자인 v1/v2 진행됨 → 토큰 일관성 점검.
3. **/feed-hub** — 사진 피드 ↔ Q&A 두 모드 전환 UX 명확화.

---

## 5. 디자인 부채 메모
- feature theme 3종이 공용 토큰과 별개로 색을 정의 → 단일 토큰 트리로 통합 검토
- confidence 등 내부 수치는 UI 비노출 원칙 유지 (데이터엔 보존)
- 홈 레거시 카드 "임시 배치" 주석 → 정식 위치 확정 필요
