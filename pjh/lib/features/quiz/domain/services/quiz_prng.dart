/// 플랫폼·런타임 무관 결정적 PRNG (32bit).
///
/// 출제 순열(Fisher–Yates)을 시드만으로 재현하기 위한 의사난수기다. Dart 기본
/// `Random(seed)` 는 구현체에 따라 결과가 달라질 수 있어(재현 보장 약함) 쓰지
/// 않고, 운세와 같은 FNV-1a 계열로 직접 구현한다.
///
/// 내부는 SplitMix32: 매 호출 상태에 황금비 상수를 더하고 비트 믹싱한다. 같은
/// 시드 → 같은 난수 수열을 어느 플랫폼에서나 동일하게 산출한다.
class QuizPrng {
  int _state;

  /// [seed] 를 FNV-1a 로 한 번 섞어 초기 상태로 삼는다(작은 정수 시드도 잘 퍼지게).
  QuizPrng(int seed) : _state = _fnv1a(seed) & 0xFFFFFFFF;

  /// 다음 32bit 난수(0..2^32-1).
  int _next() {
    // SplitMix32
    _state = (_state + 0x9E3779B9) & 0xFFFFFFFF;
    int z = _state;
    z = ((z ^ (z >> 16)) * 0x21F0AAAD) & 0xFFFFFFFF;
    z = ((z ^ (z >> 15)) * 0x735A2D97) & 0xFFFFFFFF;
    return (z ^ (z >> 15)) & 0xFFFFFFFF;
  }

  /// 0 이상 [bound] 미만의 균등 정수. [bound] 는 양수 전제.
  ///
  /// 2^32 를 [bound] 로 나눈 나머지 구간을 버리는 거부 표집(rejection)으로
  /// modulo 편향을 제거한다.
  int nextInt(int bound) {
    assert(bound > 0);
    final int limit = 0x100000000 - (0x100000000 % bound); // 버릴 상한
    int r;
    do {
      r = _next();
    } while (r >= limit);
    return r % bound;
  }

  /// 문자열·정수 혼합 시드용 FNV-1a(32bit). 시드 초기화에만 사용.
  static int _fnv1a(int seed) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811c9dc5;
    // 시드의 4바이트를 차례로 흡수.
    for (int shift = 0; shift < 32; shift += 8) {
      hash ^= (seed >> shift) & 0xFF;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0xFFFFFFFF;
  }
}
