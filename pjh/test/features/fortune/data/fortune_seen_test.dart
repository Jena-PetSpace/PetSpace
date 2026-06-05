import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_seen_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FortuneSeenLocalDataSourceImpl store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = FortuneSeenLocalDataSourceImpl(prefs: prefs);
  });

  group('fortuneDateKey — 로컬 자정 경계', () {
    test('YYYYMMDD 0패딩', () {
      expect(fortuneDateKey(DateTime(2026, 6, 4)), '20260604');
      expect(fortuneDateKey(DateTime(2026, 12, 31)), '20261231');
      expect(fortuneDateKey(DateTime(2026, 1, 9)), '20260109');
    });

    test('자정 직전/직후로 키가 바뀜(미확인 자동 전환의 근거)', () {
      final beforeMidnight = fortuneDateKey(DateTime(2026, 6, 4, 23, 59));
      final afterMidnight = fortuneDateKey(DateTime(2026, 6, 5, 0, 1));
      expect(beforeMidnight, '20260604');
      expect(afterMidnight, '20260605');
      expect(beforeMidnight == afterMidnight, isFalse);
    });
  });

  group('mark / isSeen (pet 단위 분리)', () {
    test('기록 전 false, 기록 후 true', () async {
      expect(await store.isSeen('pet-1', '20260604'), isFalse);
      await store.markSeen('pet-1', '20260604');
      expect(await store.isSeen('pet-1', '20260604'), isTrue);
    });

    test('다른 pet 은 독립(다견·다묘)', () async {
      await store.markSeen('pet-1', '20260604');
      expect(await store.isSeen('pet-2', '20260604'), isFalse);
    });

    test('다른 날짜는 독립(자정 후 미확인)', () async {
      await store.markSeen('pet-1', '20260604');
      expect(await store.isSeen('pet-1', '20260605'), isFalse);
    });
  });

  group('purgePastKeys — 과거 키 정리, 오늘 키 보존', () {
    test('과거 키만 삭제하고 오늘 키는 모두 보존(다견·다묘)', () async {
      // 과거(다른 날) 키들
      await store.markSeen('pet-1', '20260601');
      await store.markSeen('pet-1', '20260603');
      // 오늘 키들 — 여러 pet
      await store.markSeen('pet-1', '20260604');
      await store.markSeen('pet-2', '20260604');

      final removed = await store.purgePastKeys('20260604');
      expect(removed, 2); // 과거 2개만 삭제

      // 오늘 키 보존
      expect(await store.isSeen('pet-1', '20260604'), isTrue);
      expect(await store.isSeen('pet-2', '20260604'), isTrue);
      // 과거 키 삭제됨
      expect(await store.isSeen('pet-1', '20260601'), isFalse);
      expect(await store.isSeen('pet-1', '20260603'), isFalse);
    });

    test('fortune_seen_ 외 다른 키는 건드리지 않음', () async {
      await prefs.setString('other_key', 'keep');
      await prefs.setBool('mbti_draft_pet-1', true);
      await store.markSeen('pet-1', '20260601'); // 과거

      await store.purgePastKeys('20260604');

      expect(prefs.getString('other_key'), 'keep');
      expect(prefs.getBool('mbti_draft_pet-1'), isTrue);
    });

    test('정리할 과거 키 없으면 0 반환(오늘만 있을 때)', () async {
      await store.markSeen('pet-1', '20260604');
      final removed = await store.purgePastKeys('20260604');
      expect(removed, 0);
      expect(await store.isSeen('pet-1', '20260604'), isTrue);
    });

    test('petId 에 날짜처럼 보이는 문자열이 있어도 접미사로만 판별', () async {
      // 키는 fortune_seen_<petId>_<date>. 오늘 접미사 '_20260604' 로 끝나는지로 보존.
      await store.markSeen('pet_20260604', '20260601'); // 과거(오늘 아님)
      await store.markSeen('pet_20260604', '20260604'); // 오늘

      final removed = await store.purgePastKeys('20260604');
      expect(removed, 1);
      expect(await store.isSeen('pet_20260604', '20260604'), isTrue);
      expect(await store.isSeen('pet_20260604', '20260601'), isFalse);
    });
  });
}
