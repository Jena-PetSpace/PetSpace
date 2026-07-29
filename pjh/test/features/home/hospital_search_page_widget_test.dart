import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/config/injection_container.dart' show sl;
import 'package:meong_nyang_diary/core/place_search/kakao_local_data_source.dart';
import 'package:meong_nyang_diary/core/place_search/place_search_query.dart';
import 'package:meong_nyang_diary/core/place_search/saved_place_local_data_source.dart';
import 'package:meong_nyang_diary/features/home/presentation/pages/hospital_search_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockClient client;

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    client = MockClient((request) async {
      return http.Response.bytes(
        utf8.encode(
          jsonEncode(<String, Object>{
            'documents': <Object>[
              <String, String>{
                'id': 'place-phone',
                'place_name': '튼튼동물병원',
                'category_name': '의료,건강 > 동물병원',
                'road_address_name': '서울 중구 세종대로 1',
                'address_name': '서울 중구 태평로 1',
                'phone': '02-111-2222',
                'x': '126.9782',
                'y': '37.5667',
                'place_url': 'https://place.map.kakao.com/1',
                'distance': '152',
              },
              <String, String>{
                'id': 'place-no-phone',
                'place_name': '편안동물병원',
                'category_name': '의료,건강 > 동물병원',
                'road_address_name': '서울 중구 세종대로 2',
                'address_name': '서울 중구 태평로 2',
                'phone': '',
                'x': '126.9784',
                'y': '37.5669',
                'place_url': 'https://place.map.kakao.com/2',
                'distance': '198',
              },
            ],
            'meta': <String, Object>{
              'is_end': true,
              'pageable_count': 2,
            },
          }),
        ),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    sl.registerSingleton<KakaoLocalDataSource>(
      KakaoLocalDataSource(client: client, apiKey: 'test-key'),
    );
    sl.registerSingleton<SavedPlaceLocalDataSource>(
      SavedPlaceLocalDataSource(preferences: preferences),
    );
  });

  tearDown(() async {
    client.close();
    await sl.reset();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool pushedRoute = false,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget buildPlacePage() {
      return HospitalSearchPage(
        mapBuilder: (_) => const ColoredBox(
          key: ValueKey<String>('fake-map'),
          color: Color(0xFFEAF1F7),
        ),
      );
    }

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) {
          return MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child!,
              );
            },
            initialRoute: pushedRoute ? '/place' : null,
            routes: pushedRoute
                ? <String, WidgetBuilder>{
                    '/': (_) => const SizedBox.shrink(),
                    '/place': (_) => buildPlacePage(),
                  }
                : const <String, WidgetBuilder>{},
            home: pushedRoute ? null : buildPlacePage(),
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> replaceSearchClient(
    Future<http.Response> Function(http.Request request) handler,
  ) async {
    client.close();
    await sl.unregister<KakaoLocalDataSource>();
    client = MockClient(handler);
    sl.registerSingleton<KakaoLocalDataSource>(
      KakaoLocalDataSource(client: client, apiKey: 'test-key'),
    );
  }

  test('시트 상수와 거리 기준 문구가 정본 계약을 유지한다', () {
    expect(kPlaceSheetSnapSizes, <double>[0.12, 0.42, 0.88]);
    expect(
      placeDistanceOriginLabel(PlaceSearchOriginType.device),
      '현재 위치 기준',
    );
    expect(
      placeDistanceOriginLabel(PlaceSearchOriginType.mapCenter),
      '지도 중심 기준',
    );
    expect(
      placeDistanceOriginLabel(PlaceSearchOriginType.manual),
      '검색 기준',
    );
    expect(
      placeDistanceOriginLabel(PlaceSearchOriginType.fallback),
      '서울시청 주변 결과',
    );
  });

  test('마커와 카드가 공유할 순번 helper가 같은 번호를 만든다', () {
    const places = <HospitalPlace>[
      HospitalPlace(
        id: 'a',
        name: '첫 장소',
        address: '',
        phone: '',
        lat: 37.5,
        lng: 127,
        category: '동물병원',
      ),
      HospitalPlace(
        id: 'b',
        name: '둘째 장소',
        address: '',
        phone: '',
        lat: 37.6,
        lng: 127.1,
        category: '동물병원',
      ),
    ];
    final markers = buildPlaceMarkerOptions(
      places: places,
      selectedPlaceId: 'b',
    );

    expect(markers[0].text, '${placeOrdinal(0)}');
    expect(markers[1].text, '${placeOrdinal(1)}');
    expect(markers[0].styleId, isNot(markers[1].styleId));
  });

  testWidgets('보호된 검색·5개 카테고리와 단일 스크롤 시트를 유지한다', (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const ValueKey<String>('fake-map')), findsOneWidget);
    expect(find.text('병원, 시설 이름으로 검색'), findsOneWidget);
    for (final label in <String>['내 장소', '동물병원', '약국', '카페', '미용실']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.bySemanticsLabel('장소 화면 닫기'), findsOneWidget);
  });

  testWidgets('시트를 중간→전체→축소 방향으로 실제 drag할 수 있다', (tester) async {
    await pumpPage(tester);

    final scrollView = find.byType(CustomScrollView);
    final initialHeight = tester.getSize(scrollView).height;
    await tester.drag(scrollView, const Offset(0, -360));
    await tester.pumpAndSettle();
    final expandedHeight = tester.getSize(scrollView).height;
    expect(expandedHeight, greaterThan(initialHeight + 40));

    await tester.drag(scrollView, const Offset(0, 520));
    await tester.pumpAndSettle();
    final collapsedHeight = tester.getSize(scrollView).height;
    expect(collapsedHeight, lessThan(expandedHeight - 40));
  });

  testWidgets('검색 중 검색창 포커스는 결과 시트를 즉시 축소한다', (tester) async {
    final response = Completer<http.Response>();
    await replaceSearchClient((_) => response.future);
    await pumpPage(tester);

    final scrollView = find.byType(CustomScrollView);
    final initialHeight = tester.getSize(scrollView).height;
    await tester.tap(find.text('동물병원'));
    await tester.pump();
    await tester.showKeyboard(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 320));

    expect(
      tester.getSize(scrollView).height,
      lessThan(initialHeight - 40),
    );

    response.complete(
      http.Response(
        '{"documents":[],"meta":{"is_end":true,"pageable_count":0}}',
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      ),
    );
    await tester.pump();
  });

  testWidgets('검색 중 시스템 뒤로가기는 결과 시트를 즉시 축소한다', (tester) async {
    final response = Completer<http.Response>();
    await replaceSearchClient((_) => response.future);
    await pumpPage(tester, pushedRoute: true);

    final scrollView = find.byType(CustomScrollView);
    final initialHeight = tester.getSize(scrollView).height;
    await tester.tap(find.text('동물병원'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump(const Duration(milliseconds: 320));

    expect(
      tester.getSize(scrollView).height,
      lessThan(initialHeight - 40),
    );

    response.complete(
      http.Response(
        '{"documents":[],"meta":{"is_end":true,"pageable_count":0}}',
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      ),
    );
    await tester.pump();
  });

  testWidgets('검색 중 뒤로 접은 시트는 성공 결과가 와도 접힘을 유지한다', (tester) async {
    final response = Completer<http.Response>();
    await replaceSearchClient((_) => response.future);
    await pumpPage(tester, pushedRoute: true);

    final scrollView = find.byType(CustomScrollView);
    final initialHeight = tester.getSize(scrollView).height;
    await tester.tap(find.text('동물병원'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump(const Duration(milliseconds: 320));
    final collapsedHeight = tester.getSize(scrollView).height;
    expect(collapsedHeight, lessThan(initialHeight - 40));

    response.complete(
      http.Response.bytes(
        utf8.encode(
          jsonEncode(<String, Object>{
            'documents': <Object>[
              <String, String>{
                'id': 'success-after-collapse',
                'place_name': '접힘 유지 동물병원',
                'category_name': '의료,건강 > 동물병원',
                'road_address_name': '서울 중구 세종대로 1',
                'address_name': '서울 중구 태평로 1',
                'phone': '02-111-2222',
                'x': '126.9782',
                'y': '37.5667',
                'place_url': 'https://place.map.kakao.com/1',
                'distance': '152',
              },
            ],
            'meta': <String, Object>{
              'is_end': true,
              'pageable_count': 1,
            },
          }),
        ),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('접힘 유지 동물병원'), findsOneWidget);
    expect(
      tester.getSize(scrollView).height,
      lessThan(initialHeight - 40),
    );
  });

  testWidgets('검색창에서 실행한 성공 검색은 결과 시트를 연다', (tester) async {
    await pumpPage(tester);

    final scrollView = find.byType(CustomScrollView);
    final initialHeight = tester.getSize(scrollView).height;
    final searchField = find.byType(TextField);
    await tester.showKeyboard(searchField);
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump(const Duration(milliseconds: 320));
    final collapsedHeight = tester.getSize(scrollView).height;
    expect(collapsedHeight, lessThan(initialHeight - 40));

    await tester.enterText(searchField, '동물병원');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('튼튼동물병원'), findsOneWidget);
    expect(
      tester.getSize(scrollView).height,
      greaterThan(collapsedHeight + 40),
    );
  });

  testWidgets('새 카테고리 검색 실패는 이전 목록을 지우고 재시도를 표시한다', (tester) async {
    await replaceSearchClient((request) async {
      if (request.url.queryParameters['query'] != '동물병원') {
        throw http.ClientException('offline');
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode(<String, Object>{
            'documents': <Object>[
              <String, String>{
                'id': 'previous-place',
                'place_name': '이전 동물병원',
                'category_name': '의료,건강 > 동물병원',
                'road_address_name': '서울 중구 세종대로 1',
                'address_name': '서울 중구 태평로 1',
                'phone': '02-111-2222',
                'x': '126.9782',
                'y': '37.5667',
                'place_url': 'https://place.map.kakao.com/1',
                'distance': '152',
              },
            ],
            'meta': <String, Object>{
              'is_end': true,
              'pageable_count': 1,
            },
          }),
        ),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    await pumpPage(tester);

    await tester.tap(find.text('동물병원'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('이전 동물병원'), findsOneWidget);

    await tester.tap(find.text('약국'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('이전 동물병원'), findsNothing);
    expect(find.text('네트워크 연결을 확인해주세요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('직접 검색 실패는 시트를 열어 재시도 버튼을 노출한다', (tester) async {
    await replaceSearchClient((_) async {
      throw http.ClientException('offline');
    });
    await pumpPage(tester);

    final searchField = find.byType(TextField);
    await tester.showKeyboard(searchField);
    await tester.enterText(searchField, '실패 검색');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('다시 시도'), findsOneWidget);
    final retryButton = find.widgetWithText(TextButton, '다시 시도');
    expect(
      retryButton.hitTestable(),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(CustomScrollView)).height,
      greaterThan(240),
    );
  });

  testWidgets('선택 상세는 전화 유무에 맞게 재배치하고 저장 상태를 바꾼다', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('동물병원'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('튼튼동물병원'), findsOneWidget);
    expect(find.text('편안동물병원'), findsOneWidget);

    await tester.tap(find.text('편안동물병원'));
    await tester.pumpAndSettle();
    expect(find.text('목록으로'), findsOneWidget);
    expect(find.text('길찾기'), findsOneWidget);
    expect(find.text('전화'), findsNothing);
    expect(find.text('저장'), findsOneWidget);
    expect(find.text('공유'), findsOneWidget);
    expect(find.text('상세'), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('저장 취소'), findsOneWidget);

    await tester.tap(find.text('목록으로'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('튼튼동물병원'));
    await tester.pumpAndSettle();
    expect(find.text('전화'), findsOneWidget);
  });

  testWidgets('320x568·textScale 3.0에서 overflow가 없다', (tester) async {
    await pumpPage(
      tester,
      size: const Size(320, 568),
      textScale: 3,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });
}
