/// AI 분석 로딩 화면 §5.6 — placeholder fact 데이터.
/// 추후 카테고리별 25~30개씩 총 150개 목표 (스펙 §5.5).
class PetFact {
  final String category;
  final String text;
  const PetFact({required this.category, required this.text});
}

const List<PetFact> kPlaceholderFacts = [
  PetFact(
    category: '#감정',
    text: '꼬리를 좌우로 빠르게 흔든다면\n흥분 상태일 수 있어요',
  ),
  PetFact(
    category: '#건강',
    text: '연 1회 건강검진은\n조기 진단의 핵심이에요',
  ),
  PetFact(
    category: '#음식',
    text: '강아지에게 포도와 양파는\n절대 주면 안 돼요',
  ),
  PetFact(
    category: '#행동',
    text: '갑자기 물을 많이 마신다면\n신장·당뇨 신호일 수 있어요',
  ),
  PetFact(
    category: '#케어',
    text: '양치는 주 2-3회로도\n치주염을 절반 줄여줘요',
  ),
  PetFact(
    category: '#감정',
    text: '강아지가 옆꼬리를 빼면\n긴장 신호일 수 있어요',
  ),
];
