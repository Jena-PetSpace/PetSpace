/// 인증 화면에서 공통으로 사용하는 입력 검증 규칙.
abstract final class AuthInputValidators {
  static final RegExp _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  static bool isValidEmail(String value) {
    return _emailPattern.hasMatch(value.trim());
  }

  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일을 입력해주세요.';
    if (!isValidEmail(email)) return '올바른 이메일 주소를 입력해주세요.';
    return null;
  }
}
