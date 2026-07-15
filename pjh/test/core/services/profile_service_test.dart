import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:meong_nyang_diary/core/services/image_upload_service.dart';
import 'package:meong_nyang_diary/core/services/profile_service.dart';

class _MockSupabaseClient extends Mock implements supa.SupabaseClient {}

class _MockGoTrueClient extends Mock implements supa.GoTrueClient {}

class _MockSupabaseUser extends Mock implements supa.User {}

class _MockImageUploadService extends Mock implements ImageUploadService {}

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockSupabaseUser user;
  late ProfileService service;

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    user = _MockSupabaseUser();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.id).thenReturn('user-1');
    service = ProfileService(
      supabase: client,
      imageUploadService: _MockImageUploadService(),
    );
  });

  test('getProfileStats는 조회 실패를 실제 0으로 바꾸지 않고 상향 전달한다', () async {
    when(() => client.from('posts')).thenThrow(StateError('network-down'));

    await expectLater(
      service.getProfileStats(),
      throwsA(isA<StateError>()),
    );
  });

  test('프로필 완성도는 이름과 사진이 모두 있을 때만 true다', () {
    expect(
      service.isProfileComplete({
        'display_name': '정현',
        'photo_url': 'https://example.com/profile.jpg',
      }),
      isTrue,
    );
    expect(
      service.isProfileComplete({
        'display_name': '정현',
        'photo_url': '',
      }),
      isFalse,
    );
  });
}
