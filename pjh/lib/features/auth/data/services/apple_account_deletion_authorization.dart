import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Apple 계정 탈퇴 재인증에서만 사용하는 단기 자격 증명이다.
///
/// authorization code와 nonce는 메모리에서 Edge Function으로 즉시 전달하며
/// 로컬 저장소, 로그, 분석 이벤트에 남기지 않는다.
class AppleAccountDeletionAuthorization {
  const AppleAccountDeletionAuthorization({
    required this.authorizationCode,
    required this.rawNonce,
  });

  final String authorizationCode;
  final String rawNonce;

  Map<String, String> toRequestBody() => {
        'appleAuthorizationCode': authorizationCode,
        'appleNonce': rawNonce,
      };
}

class AppleAccountDeletionPolicy {
  const AppleAccountDeletionPolicy._();

  static bool hasAppleIdentity(Iterable<String> providers) {
    return providers.any((provider) => provider.toLowerCase() == 'apple');
  }

  static String hashNonce(String rawNonce) {
    return sha256.convert(utf8.encode(rawNonce)).toString();
  }
}
