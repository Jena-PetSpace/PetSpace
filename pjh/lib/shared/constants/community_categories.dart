/// 커뮤니티(라운지) 카테고리 단일 소스.
///
/// posts.category 값·한글 라벨·노출 그룹을 한 곳에서 관리한다.
/// 참조처: 라운지 필터 칩(feed_hub_page), 글 작성 화면(create_community_post_page),
/// CommunityPost.categoryLabel, 홈 이슈 콘텐츠 칩(category_filter_chips).
///
/// 순수 Dart — domain entity에서 import하므로 Flutter 의존 금지.
class CommunityCategory {
  /// posts.category 컬럼 값 (매거진만 예외 — hashtag 'magazine' 기반 식별자).
  final String value;

  /// 한글 노출 라벨.
  final String label;

  const CommunityCategory({required this.value, required this.label});
}

abstract final class CommunityCategories {
  // ── 라운지 카테고리 (2026-07 피드 재편) ─────────────────────────
  // 'qa'는 구 체계 값 재사용(웹 검토 승인) — 기존 글 호환·백필 불필요.
  static const chat = CommunityCategory(value: 'chat', label: '잡담');
  static const brag = CommunityCategory(value: 'brag', label: '자랑');
  static const qa = CommunityCategory(value: 'qa', label: '궁금해요');
  static const info = CommunityCategory(value: 'info', label: '정보');

  /// 라운지 필터·글 작성 공용 목록 (순서 = 노출 순서, '전체'는 UI에서 별도).
  static const List<CommunityCategory> lounge = [chat, brag, qa, info];

  /// 글 작성 기본 카테고리 값.
  static const String defaultWriteValue = 'chat';

  // ── 이슈 콘텐츠 그룹 (홈 칩 · 발견 탭 운영 카드 소스) ─────────────
  // magazine은 category 컬럼이 아닌 hashtag 'magazine'으로 조회한다.
  static const magazine = CommunityCategory(value: 'magazine', label: '매거진');
  static const careguide =
      CommunityCategory(value: 'careguide', label: '케어가이드');
  static const education = CommunityCategory(value: 'education', label: '교육');
  static const policy = CommunityCategory(value: 'policy', label: '정책');
  static const event = CommunityCategory(value: 'event', label: '이벤트');

  /// 홈 이슈 콘텐츠 칩 목록 (값 기반 매핑 — 인덱스 결합 금지).
  static const List<CommunityCategory> issueContents = [
    magazine,
    careguide,
    education,
    policy,
    event,
  ];

  /// 발견 탭 운영 카드가 조회하는 구 카테고리 값 (magazine은 hashtag 경로 별도).
  static const List<String> operationalCardCategories = [
    'careguide',
    'education',
    'policy',
  ];

  /// category 컬럼 값 → 한글 라벨. 미분류(null)·미상 값은 빈 문자열.
  ///
  /// 신 4종 + 구 세대 값(2026-07 재편 이전 글) 호환 표기를 모두 처리한다.
  static String label(String? value) {
    switch (value) {
      // ── 신 체계 (라운지) ──
      case 'chat':
        return chat.label;
      case 'brag':
        return brag.label;
      case 'qa':
        return qa.label;
      case 'info':
        return info.label;
      // ── 구 체계 (2026-07 재편 이전 글 호환) ──
      case 'quiz':
        return 'O/X 퀴즈';
      case 'careguide':
        return careguide.label;
      case 'education':
        return education.label;
      case 'policy':
        return policy.label;
      case 'event':
        return event.label;
      case 'health':
        return '건강';
      case 'training':
        return '훈련';
      case 'food':
        return '먹거리';
      case 'life':
        return '생활';
      default:
        return '';
    }
  }
}
