import 'quiz_prng.dart';

/// O/X 퀴즈 출제(개인 순열 + 진행 커서) 순수 로직.
///
/// 날짜 기반 전역 출제(모두 같은 문제)를 폐기하고, 사용자마다 다른 순서로
/// 270문항을 도는 방식이다. 핵심 보장:
/// - **개인별 순서 상이:** 최초 1회 생성한 `quiz_seed` 로 순열을 만든다.
/// - **바퀴 내 무중복:** 한 바퀴(270개)를 다 돌기 전 같은 문제가 다시 안 나온다.
/// - **시작 시점 무관:** 날짜가 아니라 커서로 진행해 누가 언제 시작하든 묶이지 않는다.
///
/// 순열은 배열로 저장하지 않는다. 시드만 prefs 에 두고, 매번 [permutation] 으로
/// 결정적으로 재생성한다(시드+길이 같으면 항상 같은 순열). 시드 변화에 강건하도록
/// PRNG 는 운세와 동일 FNV-1a 계열([QuizPrng])을 쓰며 Dart `Random` 은 쓰지 않는다.
class QuizSelector {
  const QuizSelector({required this.total, required this.dailyCount})
      : assert(total > 0),
        assert(dailyCount > 0);

  /// 전체 문항 수(=270).
  final int total;

  /// 한 세트 크기(=4). 커서 전진 단위이자 오늘 세트 길이.
  final int dailyCount;

  /// [seed] 로 결정적 Fisher–Yates 셔플한 인덱스 순열(길이 [total]).
  ///
  /// 같은 (seed, total) → 항상 동일 결과. 배열 저장 대신 매번 재생성하므로
  /// prefs 에는 seed 만 둔다. 표준 Fisher–Yates: 뒤에서부터 j∈[0,i] 와 swap.
  List<int> permutation(int seed) {
    final perm = List<int>.generate(total, (i) => i);
    final rng = QuizPrng(seed);
    for (int i = total - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1); // 0..i 균등
      final tmp = perm[i];
      perm[i] = perm[j];
      perm[j] = tmp;
    }
    return perm;
  }

  /// 현재 [cursor] 위치의 오늘 세트(문항 인덱스 리스트).
  ///
  /// `perm[cursor : cursor+dailyCount]`. 바퀴 끝에 [dailyCount] 미만이 남으면
  /// 남은 만큼만 반환한다(270÷4=67.5 → 마지막 세트는 2문항). 호출부는 반환
  /// 길이를 세트 크기로 보고 채점·커서 전진한다.
  ///
  /// [cursor] 는 0..total-1 범위 전제(완주 시 호출부가 재셔플로 0 리셋).
  List<int> setIndicesAt(int seed, int cursor) {
    final perm = permutation(seed);
    return indicesFromPermutation(perm, cursor);
  }

  /// 이미 만든 [perm] 에서 [cursor] 부터 세트를 끊어낸다(재계산 절약용).
  List<int> indicesFromPermutation(List<int> perm, int cursor) {
    if (cursor < 0 || cursor >= perm.length) return const [];
    final end = (cursor + dailyCount).clamp(0, perm.length);
    return perm.sublist(cursor, end);
  }

  /// 한 바퀴를 다 돈 뒤([cursor] 가 [total] 도달) 다음 바퀴용 새 시드.
  ///
  /// 경계 보정: 직전 바퀴 **마지막 세트** 문항이 새 바퀴 **첫 세트** 에 겹치지
  /// 않을 때까지 시드를 굴린다(라이드 경계 연속 중복 방지). 270÷4 가 나누어
  /// 떨어지지 않아 마지막 세트가 2문항이어도, 그 잔여 문항들 전부를 기준으로
  /// 본다. 유한 횟수(최대 [_reshuffleTries]) 안에 못 찾으면 마지막 후보 사용
  /// (확률적으로 거의 항상 1~2회 내 성공).
  ///
  /// [prevSeed] 직전 시드. 반환 = 새 시드(이 시드로 cursor=0 부터 새 바퀴).
  int reshuffleSeed(int prevSeed) {
    // 직전 바퀴 마지막 세트(잔여 포함)의 문항 집합.
    final prevPerm = permutation(prevSeed);
    final lastSetStart = _lastSetStart();
    final prevTail = prevPerm.sublist(lastSetStart).toSet();

    int candidate = _mix(prevSeed);
    for (int attempt = 0; attempt < _reshuffleTries; attempt++) {
      final perm = permutation(candidate);
      final head = perm.take(dailyCount).toSet();
      if (head.intersection(prevTail).isEmpty) return candidate;
      candidate = _mix(candidate);
    }
    return candidate; // 폴백: 마지막 후보(이론상 도달 드묾)
  }

  /// 마지막 세트의 시작 인덱스. total 이 dailyCount 로 나누어떨어지면
  /// `total - dailyCount`, 아니면 마지막 잔여 세트의 시작.
  int _lastSetStart() {
    final rem = total % dailyCount;
    return rem == 0 ? total - dailyCount : total - rem;
  }

  /// 시드 파생용 결정적 믹스(FNV-1a 1스텝 + 상수). 재셔플 후보 생성에만 사용.
  int _mix(int seed) {
    const int fnvPrime = 0x01000193;
    int h = (seed ^ 0x9e3779b9) & 0xFFFFFFFF;
    h = (h * fnvPrime) & 0xFFFFFFFF;
    h ^= (h >> 15);
    return h & 0x7FFFFFFF;
  }

  static const int _reshuffleTries = 8;
}
