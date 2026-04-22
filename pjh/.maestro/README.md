# PetSpace Maestro 테스트

## 실행 방법

### 단일 테스트
```
maestro test .maestro/flows/00_smoke_test.yaml
```

### 전체 실행
```
maestro test .maestro/flows/
```

### Maestro Studio (UI 보면서 YAML 작성)
```
maestro studio
```

## 파일 구조
```
.maestro/
  flows/
    00_smoke_test.yaml       # 앱 실행 확인
    01_my_tab.yaml           # MY 탭 프로필/설정 검증
    02_feed_tab.yaml         # 피드 탭 사진/Q&A 전환 검증
    03_navigation_smoke.yaml # 전체 탭 네비게이션 스모크
  helpers/                   # 공통 플로우 (추후 추가)
```

## 주의사항
- Android 에뮬레이터가 실행 중이어야 함
- 앱이 에뮬레이터에 설치되어 있어야 함 (`flutter run` 또는 `flutter install`)
- AI분석 탭(중앙 원형 버튼)은 좌표 기반 탭 사용 (텍스트 label 없음)
