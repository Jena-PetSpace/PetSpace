import '../../data/datasources/quiz_content_data_source.dart';
import '../../data/datasources/quiz_local_data_source.dart';
import '../entities/quiz_content.dart';
import '../entities/quiz_set.dart';
import 'quiz_selector.dart';

/// 콘텐츠 + 로컬 상태(시드·커서)를 묶어 "오늘의 세트"를 만들고, 세트 완료를
/// 커밋(원자적 커서 전진·재셔플·스트릭)하는 출제 코디네이터.
///
/// 운세가 위젯에서 generator·dataSource 를 직접 조합했듯, 여기서도 BLoC 없이
/// 순수 조합만 한다(외부 호출·DB 0). 화면은 이 빌더를 sl 로 받아 호출한다.
class QuizSessionBuilder {
  final QuizContentDataSource contentDataSource;
  final QuizLocalDataSource localDataSource;

  const QuizSessionBuilder({
    required this.contentDataSource,
    required this.localDataSource,
  });

  /// 현재 커서 기준 오늘 세트. (게이팅은 호출부 — 홈/결과에서 isDoneToday 로 판단)
  ///
  /// 세트는 재진입 안정적: 커밋 전까지 커서가 안 움직이므로 같은 세트가 처음부터
  /// 다시 나온다(중간 이탈 시 진도 보존 없음 — 스펙대로).
  Future<QuizSet> buildTodaySet() async {
    final content = await contentDataSource.loadContent();
    final selector = _selector(content);
    final seed = await localDataSource.getOrCreateSeed();
    final cursor = await localDataSource.getCursor();

    final perm = selector.permutation(seed);
    final indices = selector.indicesFromPermutation(perm, cursor);
    final questions = indices.map((i) => content.questions[i]).toList();

    return QuizSet(cursor: cursor, questions: questions);
  }

  /// 세트 완료 커밋. 멱등(오늘 이미 완료면 커서·스트릭 불변). 반환 = 갱신 스트릭.
  ///
  /// 커서 전진은 원자적: `cursor += solvedCount`, 270 도달/초과 시 경계 보정
  /// 재셔플(새 시드)로 다음 바퀴를 cursor=0 부터 시작한다.
  Future<int> commitCompletion({
    required String dateKey,
    required int solvedCount,
  }) async {
    final content = await contentDataSource.loadContent();
    final selector = _selector(content);

    return localDataSource.commitSetCompletion(
      dateKey: dateKey,
      solvedCount: solvedCount,
      advanceCursor: (solved) async {
        final cursor = await localDataSource.getCursor();
        final next = cursor + solved;
        if (next >= content.questions.length) {
          // 바퀴 완주 → 경계 보정 재셔플 + 커서 0.
          final seed = await localDataSource.getOrCreateSeed();
          final newSeed = selector.reshuffleSeed(seed);
          await localDataSource.setSeed(newSeed);
          await localDataSource.setCursor(0);
        } else {
          await localDataSource.setCursor(next);
        }
      },
    );
  }

  QuizSelector _selector(QuizContent content) => QuizSelector(
        total: content.questions.length,
        dailyCount: content.dailyCount,
      );
}
