import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/place_search/kakao_local_data_source.dart';
import 'package:meong_nyang_diary/core/place_search/place_search_query.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/location_picker_page.dart';

class _MockKakaoLocalDataSource extends Mock implements KakaoLocalDataSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      PlaceSearchQuery(
        originType: PlaceSearchOriginType.fallback,
        latitude: 37.5665,
        longitude: 126.978,
        radiusM: null,
        keyword: '테스트',
        category: 'location_picker',
        page: 1,
        size: 15,
      ),
    );
  });

  PlaceSearchPage pageWith(int count) {
    return PlaceSearchPage(
      items: List.generate(
        count,
        (index) => PlaceSearchItem(
          providerPlaceId: 'place-$index',
          name: '테스트 장소 ${index + 1}',
          category: '장소',
          address: '서울특별시 종로구 아주 긴 테스트 주소 ${index + 1}',
          phone: '',
          latitude: 37.56 + index * 0.001,
          longitude: 126.97 + index * 0.001,
          placeUrl: '',
        ),
      ),
      isEnd: true,
      pageableCount: count,
    );
  }

  Widget picker(
    KakaoLocalDataSource dataSource, {
    bool initialMapFailed = false,
    double textScale = 1,
    Future<bool> Function(int retryAttempt)? mapRetryEvaluator,
  }) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: LocationPickerPage(
          localSearch: dataSource,
          skipLocationBootstrap: true,
          initialMapFailed: initialMapFailed,
          mapPlaceholderBuilder: (_) => const ColoredBox(
            color: Color(0xFFE9EEF4),
          ),
          mapRetryEvaluator: mapRetryEvaluator,
        ),
      ),
    );
  }

  Future<void> pumpPicker(
    WidgetTester tester,
    KakaoLocalDataSource dataSource, {
    bool initialMapFailed = false,
    double textScale = 1,
    Size size = const Size(390, 844),
    Future<bool> Function(int retryAttempt)? mapRetryEvaluator,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      picker(
        dataSource,
        initialMapFailed: initialMapFailed,
        textScale: textScale,
        mapRetryEvaluator: mapRetryEvaluator,
      ),
    );
  }

  Future<void> submitSearch(
    WidgetTester tester,
    String query,
  ) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('초기 상태는 미선택이고 공개 범위를 명확히 안내한다', (tester) async {
    final dataSource = _MockKakaoLocalDataSource();
    await pumpPicker(tester, dataSource);
    await tester.pump();

    expect(find.text('위치를 검색해 추가하세요'), findsOneWidget);
    expect(find.text('게시물에는 시·군·구까지만 공개돼요.'), findsOneWidget);
    expect(find.textContaining('위치 권한이 없어'), findsOneWidget);
    final complete = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '완료'),
    );
    expect(complete.onPressed, isNull);
  });

  testWidgets('검색 성공 3건은 헤더·타일·선택 완료 상태를 함께 갱신한다', (tester) async {
    final dataSource = _MockKakaoLocalDataSource();
    when(() => dataSource.search(any())).thenAnswer(
      (_) async => pageWith(3),
    );
    await pumpPicker(tester, dataSource);

    await submitSearch(tester, '테스트 장소');

    expect(find.textContaining('검색한 결과 3개'), findsOneWidget);
    expect(find.text('테스트 장소 1'), findsOneWidget);
    expect(find.text('테스트 장소 2'), findsOneWidget);
    expect(find.text('테스트 장소 3'), findsOneWidget);
    await tester.tap(find.text('테스트 장소 1'));
    await tester.pump();
    final complete = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '완료'),
    );
    expect(complete.onPressed, isNotNull);
  });

  testWidgets('오프라인은 빈 결과와 다른 복구 상태를 표시한다', (tester) async {
    final dataSource = _MockKakaoLocalDataSource();
    when(() => dataSource.search(any())).thenThrow(
      const KakaoLocalSearchException(KakaoLocalFailureKind.offline),
    );
    await pumpPicker(tester, dataSource);

    await submitSearch(tester, '오프라인 장소');

    expect(find.text('네트워크 연결을 확인해 주세요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('검색 결과가 없습니다'), findsNothing);
  });

  testWidgets('검색 시간 초과는 네트워크 단절과 다른 문구를 표시한다', (tester) async {
    final dataSource = _MockKakaoLocalDataSource();
    when(() => dataSource.search(any())).thenThrow(
      const KakaoLocalSearchException(KakaoLocalFailureKind.timeout),
    );
    await pumpPicker(tester, dataSource);

    await submitSearch(tester, '느린 장소');

    expect(find.text('검색 시간이 초과됐어요'), findsWidgets);
    expect(find.text('네트워크 연결을 확인해 주세요'), findsNothing);
  });

  testWidgets('성공 뒤 실패하면 직전 장소 목록을 제거한다', (tester) async {
    final dataSource = _MockKakaoLocalDataSource();
    var calls = 0;
    when(() => dataSource.search(any())).thenAnswer((_) async {
      calls += 1;
      if (calls == 1) return pageWith(3);
      throw const KakaoLocalSearchException(KakaoLocalFailureKind.offline);
    });
    await pumpPicker(tester, dataSource);

    await submitSearch(tester, '첫 검색');
    expect(find.text('테스트 장소 1'), findsOneWidget);
    await submitSearch(tester, '두번째 검색');

    expect(find.text('테스트 장소 1'), findsNothing);
    expect(find.text('네트워크 연결을 확인해 주세요'), findsOneWidget);
  });

  testWidgets('검색 성공 0건은 오류가 아닌 빈 결과로 표시한다', (tester) async {
    final dataSource = _MockKakaoLocalDataSource();
    when(() => dataSource.search(any())).thenAnswer(
      (_) async => pageWith(0),
    );
    await pumpPicker(tester, dataSource);

    await submitSearch(tester, '없는 장소');

    expect(find.text('검색 결과가 없습니다'), findsOneWidget);
    expect(find.text('장소를 검색하지 못했어요'), findsNothing);
  });

  testWidgets('지도 실패에서도 목록 전용 상태로 검색하고 선택할 수 있다', (tester) async {
    final dataSource = _MockKakaoLocalDataSource();
    when(() => dataSource.search(any())).thenAnswer(
      (_) async => pageWith(1),
    );
    await pumpPicker(tester, dataSource, initialMapFailed: true);
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const Key('location_picker_list_only_badge')),
      findsOneWidget,
    );
    expect(find.textContaining('목록에서 선택합니다'), findsOneWidget);

    await submitSearch(tester, '목록 장소');
    await tester.tap(find.text('테스트 장소 1'));
    await tester.pump();
    final complete = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '완료'),
    );
    expect(complete.onPressed, isNotNull);
  });

  testWidgets('첫 지도 재시도가 성공하면 지도 상태로 복귀한다', (tester) async {
    final dataSource = _MockKakaoLocalDataSource();
    final attempts = <int>[];
    await pumpPicker(
      tester,
      dataSource,
      initialMapFailed: true,
      mapRetryEvaluator: (attempt) async {
        attempts.add(attempt);
        return true;
      },
    );
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(
      find.byKey(const Key('location_picker_list_retry_button')),
    );
    await tester.pumpAndSettle();

    expect(attempts, [1]);
    expect(find.text('지도를 불러오지 못했어요.'), findsNothing);
    expect(
      find.byKey(const Key('location_picker_list_only_badge')),
      findsNothing,
    );
  });

  testWidgets('지도 재시도가 두 번 실패하면 목록 전용으로 고정하고 검색은 유지한다', (
    tester,
  ) async {
    final dataSource = _MockKakaoLocalDataSource();
    when(() => dataSource.search(any())).thenAnswer(
      (_) async => pageWith(1),
    );
    final attempts = <int>[];
    await pumpPicker(
      tester,
      dataSource,
      initialMapFailed: true,
      mapRetryEvaluator: (attempt) async {
        attempts.add(attempt);
        return false;
      },
    );
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(
      find.byKey(const Key('location_picker_list_retry_button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('location_picker_list_retry_button')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('location_picker_list_retry_button')),
    );
    await tester.pumpAndSettle();

    expect(attempts, [1, 2]);
    expect(
      find.byKey(const Key('location_picker_list_retry_button')),
      findsNothing,
    );
    expect(
      find.text('지도 재시도를 마쳐 이 화면에서는 목록만 사용해요'),
      findsOneWidget,
    );
    expect(
      find.text('이 화면에서는 목록으로 계속할 수 있어요.'),
      findsOneWidget,
    );

    await submitSearch(tester, '목록 고정 장소');
    await tester.tap(find.text('테스트 장소 1'));
    await tester.pump();
    final complete = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '완료'),
    );
    expect(complete.onPressed, isNotNull);
  });

  testWidgets('320x568 200% 글자에서도 핵심 입력과 선택 액션이 잘리지 않는다', (tester) async {
    final dataSource = _MockKakaoLocalDataSource();
    when(() => dataSource.search(any())).thenAnswer(
      (_) async => pageWith(1),
    );

    await pumpPicker(
      tester,
      dataSource,
      initialMapFailed: true,
      textScale: 2,
      size: const Size(320, 568),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await submitSearch(tester, '긴 장소 이름');

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('테스트 장소 1'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('확정 결과는 기존 네 필드 계약을 유지한다', (tester) async {
    final dataSource = _MockKakaoLocalDataSource();
    when(() => dataSource.search(any())).thenAnswer(
      (_) async => pageWith(1),
    );
    LocationPickResult? result;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<LocationPickResult>(
                    MaterialPageRoute(
                      builder: (_) => LocationPickerPage(
                        localSearch: dataSource,
                        skipLocationBootstrap: true,
                        initialMapFailed: true,
                        mapPlaceholderBuilder: (_) => const SizedBox.expand(),
                      ),
                    ),
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await submitSearch(tester, '결과 장소');
    await tester.tap(find.text('테스트 장소 1'));
    await tester.pump();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(result?.name, '테스트 장소 1');
    expect(result?.address, '서울특별시 종로구 아주 긴 테스트 주소 1');
    expect(result?.lat, 37.56);
    expect(result?.lng, 126.97);
  });
}
