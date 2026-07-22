import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/health/domain/entities/health_record.dart';
import 'package:meong_nyang_diary/features/health/presentation/widgets/health_record_data.dart';

HealthRecord _rec(
  HealthRecordType type, {
  Map<String, dynamic> data = const {},
  String title = '제목',
  String? description,
}) =>
    HealthRecord(
      id: 'r',
      petId: 'p',
      userId: 'u',
      recordType: type,
      title: title,
      description: description,
      recordDate: DateTime(2026, 6, 14),
      status: HealthRecordStatus.completed,
      data: data,
      createdAt: DateTime(2026, 6, 14),
      updatedAt: DateTime(2026, 6, 14),
    );

void main() {
  // ── data 구성 (타입별 직렬화) ────────────────────────────────────────────
  group('buildHealthRecordData', () {
    test('체중: weight_kg + bcs', () {
      final d = buildHealthRecordData(
        type: HealthRecordType.weight,
        weightKg: 5.2,
        bcs: 5,
      );
      expect(d, {'weight_kg': 5.2, 'bcs': 5});
    });

    test('체중: bcs 없으면 키 제외', () {
      final d =
          buildHealthRecordData(type: HealthRecordType.weight, weightKg: 5.2);
      expect(d, {'weight_kg': 5.2});
      expect(d.containsKey('bcs'), false);
    });

    test('투약: 빈 문자열 필드는 제외', () {
      final d = buildHealthRecordData(
        type: HealthRecordType.medication,
        medName: '심장약',
        dosage: '   ',
        frequency: '매일',
      );
      expect(d, {'med_name': '심장약', 'frequency': '매일'});
    });

    test('검진: cost int + result', () {
      final d = buildHealthRecordData(
        type: HealthRecordType.checkup,
        hospital: '튼튼동물병원',
        result: '정상',
        cost: 50000,
      );
      expect(d['hospital'], '튼튼동물병원');
      expect(d['cost'], 50000);
    });

    test('수술: surgery_name 필수 키', () {
      final d = buildHealthRecordData(
        type: HealthRecordType.surgery,
        surgeryName: '중성화',
        hospital: 'A병원',
      );
      expect(d, {'surgery_name': '중성화', 'hospital': 'A병원'});
    });

    test('예방접종: vaccine_type + hospital', () {
      final d = buildHealthRecordData(
        type: HealthRecordType.vaccination,
        vaccineType: '종합백신',
        hospital: 'B병원',
      );
      expect(d, {'vaccine_type': '종합백신', 'hospital': 'B병원'});
    });
  });

  // ── 숫자 파싱 ──────────────────────────────────────────────────────────────
  group('parseWeightKg / parseCost', () {
    test('체중 소수 파싱', () => expect(parseWeightKg('5.2'), 5.2));
    test('체중 0/음수/문자 → null', () {
      expect(parseWeightKg('0'), null);
      expect(parseWeightKg('-1'), null);
      expect(parseWeightKg('abc'), null);
    });
    test('비용 콤마 제거 파싱', () => expect(parseCost('50,000'), 50000));
    test('비용 빈값 → null', () => expect(parseCost('  '), null));
    test('비용 음수/문자 → null', () {
      expect(parseCost('-1'), null);
      expect(parseCost('만원'), null);
    });
  });

  // ── 자동 제목 ──────────────────────────────────────────────────────────────
  group('weightTitle', () {
    test('소수', () => expect(weightTitle(5.2), '체중 5.2kg'));
    test('정수는 정수 표기', () => expect(weightTitle(5.0), '체중 5kg'));
  });

  // ── 카드 부제 (하위호환 fallback) ──────────────────────────────────────────
  group('recordCardSubtitle', () {
    test('체중: data 있으면 "5.2kg · BCS 5"', () {
      final s = recordCardSubtitle(
          _rec(HealthRecordType.weight, data: {'weight_kg': 5.2, 'bcs': 5}));
      expect(s, '5.2kg · BCS 5');
    });

    test('투약: "약명 용량/주기"', () {
      final s = recordCardSubtitle(_rec(HealthRecordType.medication, data: {
        'med_name': '심장약',
        'dosage': '5mg',
        'frequency': '매일',
      }));
      expect(s, '심장약 5mg/매일');
    });

    test('빈 data(기존 레코드) → title fallback (안 깨짐)', () {
      final s = recordCardSubtitle(
          _rec(HealthRecordType.weight, data: const {}, title: '몸무게 측정'));
      expect(s, '몸무게 측정');
    });

    test('빈 data + 빈 title → description fallback', () {
      final s = recordCardSubtitle(_rec(HealthRecordType.checkup,
          data: const {}, title: '', description: '연 1회 검진'));
      expect(s, '연 1회 검진');
    });

    test('예방접종: "종류 · 병원"', () {
      final s = recordCardSubtitle(_rec(HealthRecordType.vaccination,
          data: {'vaccine_type': '광견병', 'hospital': 'C병원'}));
      expect(s, '광견병 · C병원');
    });
  });

  group('recordCardDisplayTitle / recordCardDetail', () {
    test('체중은 기록 이름과 BCS를 중복 없이 분리한다', () {
      final record = _rec(
        HealthRecordType.weight,
        title: '체중 5.4kg',
        data: const {'weight_kg': 5.4, 'bcs': 5},
      );
      expect(recordCardDisplayTitle(record), '체중 5.4kg');
      expect(recordCardDetail(record), 'BCS 5');
    });

    test('예방접종은 백신 이름과 병원을 분리한다', () {
      final record = _rec(
        HealthRecordType.vaccination,
        title: '종합 예방접종',
        data: const {
          'vaccine_type': '종합 예방접종',
          'hospital': '제나동물병원',
        },
      );
      expect(recordCardDisplayTitle(record), '종합 예방접종');
      expect(recordCardDetail(record), '제나동물병원');
    });

    test('빈 legacy 제목과 data도 안전한 유형명으로 표시한다', () {
      final record = _rec(
        HealthRecordType.vaccination,
        title: '',
        data: const {},
      );
      expect(recordCardDisplayTitle(record), '예방접종');
      expect(recordCardDetail(record), '세부 내용 없음');
    });
  });
}
