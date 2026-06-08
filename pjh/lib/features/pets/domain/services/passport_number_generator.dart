import 'dart:math';

/// 펫 여권번호 생성기 (도메인 순수 로직, 외부 의존 0).
///
/// 형식: `P` + 영문 대문자 2 + 숫자 5 (총 8자). 예: `PAB12345`
/// 실제 여권과 헷갈리지 않는 펫 전용 더미 번호.
///
/// 유니크 보장은 호출부(Repository)에서 INSERT UNIQUE 충돌 시
/// 재생성(최대 N회)으로 처리한다. 본 생성기는 "형식에 맞는 후보"만 만든다.
class PassportNumberGenerator {
  /// 주입 가능한 난수원(테스트에서 시드 고정 가능).
  final Random _random;

  PassportNumberGenerator({Random? random})
      : _random = random ?? Random.secure();

  /// 혼동 가능한 글자(0/O, 1/I 등) 포함 — 단순성 우선. 필요 시 제한 가능.
  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _digits = '0123456789';

  /// 여권번호 형식 정규식: P + 영문 대문자 2 + 숫자 5.
  static final RegExp pattern = RegExp(r'^P[A-Z]{2}\d{5}$');

  /// 형식에 맞는 새 여권번호 1개 생성.
  String generate() {
    final buffer = StringBuffer('P');
    for (var i = 0; i < 2; i++) {
      buffer.write(_letters[_random.nextInt(_letters.length)]);
    }
    for (var i = 0; i < 5; i++) {
      buffer.write(_digits[_random.nextInt(_digits.length)]);
    }
    return buffer.toString();
  }

  /// 주어진 문자열이 여권번호 형식에 맞는지 검사.
  static bool isValid(String? value) =>
      value != null && pattern.hasMatch(value);
}
