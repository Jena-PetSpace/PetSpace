// Wave 1A 교차 리뷰 보완 addendum 회귀 테스트.
// 공용 scaffold/section/tile/state의 라이트·다크 surface/text 선택,
// loading/empty/error·action callback, disabled tile tap 차단,
// 좁은 화면·150% text scale 무예외, 44px 최소 터치 영역을 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/widgets/pet_card.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_page_scaffold.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_settings_components.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_state_view.dart';

void main() {
  final ThemeData darkRef = AppTheme.darkTheme;

  Widget wrap(Widget home, {bool dark = false, double textScale = 1.0}) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    );
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  group('PetSpacePageScaffold', () {
    testWidgets('라이트: v2 배경·surface·brandDeep 제목(heading 17 역할) 유지',
        (tester) async {
      await tester.pumpWidget(wrap(
        const PetSpacePageScaffold(title: '설정', body: SizedBox()),
      ));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppTheme.backgroundColor);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, AppTheme.surfaceColor);

      expect(textColor(tester, '설정'), AppTheme.brandDeep);
    });

    testWidgets('다크: Theme scaffoldBackground/surface/onSurface 우선',
        (tester) async {
      await tester.pumpWidget(wrap(
        const PetSpacePageScaffold(title: '설정', body: SizedBox()),
        dark: true,
      ));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, darkRef.scaffoldBackgroundColor);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, darkRef.colorScheme.surface);

      expect(textColor(tester, '설정'), darkRef.colorScheme.onSurface);
    });
  });

  group('PetSpaceSettingsSection', () {
    Widget section() => const PetSpacePageScaffold(
          title: '설정',
          body: PetSpaceSettingsSection(
            title: '섹션 라벨',
            children: [PetSpaceSettingsTile(title: '항목')],
          ),
        );

    Material sectionCard(WidgetTester tester) => tester.widget<Material>(
          find
              .descendant(
                of: find.byType(PetSpaceSettingsSection),
                matching: find.byType(Material),
              )
              .first,
        );

    testWidgets('라이트: surface 카드·border·textMuted 라벨 유지', (tester) async {
      await tester.pumpWidget(wrap(section()));

      final card = sectionCard(tester);
      expect(card.color, AppTheme.surfaceColor);
      expect(
        (card.shape as RoundedRectangleBorder).side.color,
        AppTheme.border,
      );
      expect(textColor(tester, '섹션 라벨'), AppTheme.textMuted);
    });

    testWidgets('다크: Theme surface/outlineVariant/onSurfaceVariant 우선',
        (tester) async {
      await tester.pumpWidget(wrap(section(), dark: true));

      final card = sectionCard(tester);
      expect(card.color, darkRef.colorScheme.surface);
      expect(
        (card.shape as RoundedRectangleBorder).side.color,
        darkRef.colorScheme.outlineVariant,
      );
      expect(textColor(tester, '섹션 라벨'), darkRef.colorScheme.onSurfaceVariant);
    });
  });

  group('PetSpaceSettingsTile', () {
    testWidgets('onTap 호출 + 최소 44px 높이', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        PetSpacePageScaffold(
          title: '설정',
          body: PetSpaceSettingsSection(
            children: [
              PetSpaceSettingsTile(title: '항목', onTap: () => tapped = true),
            ],
          ),
        ),
      ));

      expect(tester.getSize(find.byType(PetSpaceSettingsTile)).height,
          greaterThanOrEqualTo(44));

      await tester.tap(find.text('항목'));
      expect(tapped, isTrue);
    });

    testWidgets('enabled=false: tap 차단', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        PetSpacePageScaffold(
          title: '설정',
          body: PetSpaceSettingsSection(
            children: [
              PetSpaceSettingsTile(
                title: '비활성 항목',
                enabled: false,
                onTap: () => tapped = true,
              ),
            ],
          ),
        ),
      ));

      await tester.tap(find.text('비활성 항목'));
      expect(tapped, isFalse);
    });

    testWidgets('다크: 본문 텍스트 onSurface 우선, destructive는 errorColor 유지',
        (tester) async {
      await tester.pumpWidget(wrap(
        const PetSpacePageScaffold(
          title: '설정',
          body: PetSpaceSettingsSection(
            children: [
              PetSpaceSettingsTile(title: '일반 항목'),
              PetSpaceSettingsTile(title: '위험 항목', destructive: true),
            ],
          ),
        ),
        dark: true,
      ));

      expect(textColor(tester, '일반 항목'), darkRef.colorScheme.onSurface);
      expect(textColor(tester, '위험 항목'), AppTheme.errorColor);
    });
  });

  group('PetSpaceStateView', () {
    testWidgets('loading: 인디케이터 표시', (tester) async {
      await tester.pumpWidget(wrap(
        const PetSpacePageScaffold(
          title: '상태',
          body: PetSpaceStateView.loading(),
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('empty: 라이트 title/message 시각값 유지', (tester) async {
      await tester.pumpWidget(wrap(
        const PetSpacePageScaffold(
          title: '상태',
          body: PetSpaceStateView.empty(
            icon: Icons.pets,
            title: '비어 있음',
            message: '항목이 없습니다',
          ),
        ),
      ));

      expect(textColor(tester, '비어 있음'), AppTheme.primaryTextColor);
      expect(textColor(tester, '항목이 없습니다'), AppTheme.textMuted);
    });

    testWidgets('empty 다크: Theme onSurface/onSurfaceVariant 우선',
        (tester) async {
      await tester.pumpWidget(wrap(
        const PetSpacePageScaffold(
          title: '상태',
          body: PetSpaceStateView.empty(
            icon: Icons.pets,
            title: '비어 있음',
            message: '항목이 없습니다',
          ),
        ),
        dark: true,
      ));

      expect(textColor(tester, '비어 있음'), darkRef.colorScheme.onSurface);
      expect(
          textColor(tester, '항목이 없습니다'), darkRef.colorScheme.onSurfaceVariant);
    });

    testWidgets('error: action 버튼 44px 이상 + onAction 호출', (tester) async {
      var actionCalled = false;
      await tester.pumpWidget(wrap(
        PetSpacePageScaffold(
          title: '상태',
          body: PetSpaceStateView.error(
            message: '문제가 발생했습니다',
            actionLabel: '다시 시도',
            onAction: () => actionCalled = true,
          ),
        ),
      ));

      final button = find.widgetWithText(ElevatedButton, '다시 시도');
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));

      await tester.tap(button);
      expect(actionCalled, isTrue);
    });
  });

  group('좁은 화면·150% text scale', () {
    testWidgets('320×568 + 1.5배: 예외 없음 + 타일 44px 유지', (tester) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(
        PetSpacePageScaffold(
          title: '아주 길게 쓴 설정 화면 제목',
          body: ListView(
            children: const [
              PetSpaceSettingsSection(
                title: '섹션 라벨이 다소 길어지는 경우의 확인',
                children: [
                  PetSpaceSettingsTile(
                    icon: Icons.pets_outlined,
                    title: '아주 길게 작성된 설정 항목 제목이 줄바꿈되는 경우',
                    subtitle: '보조 설명 문구도 충분히 길게 작성해 좁은 화면에서 검증한다',
                  ),
                  PetSpaceSettingsTile(title: '짧은 항목'),
                ],
              ),
              PetSpaceStateView.empty(
                icon: Icons.pets,
                title: '등록된 항목이 없습니다',
                message: '충분히 긴 안내 문구를 넣어 좁은 화면과 큰 글자에서 확인합니다',
              ),
            ],
          ),
        ),
        textScale: 1.5,
      ));

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(PetSpaceSettingsTile).first).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('PetCard 팝업 트리거: 320 폭(ScreenUtil 축소)에서도 44×44 이상',
        (tester) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final pet = Pet(
        id: 'p1',
        userId: 'u1',
        name: '보리',
        type: PetType.dog,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(wrap(
        PetSpacePageScaffold(
          title: '반려동물 관리',
          body: ListView(children: [PetCard(pet: pet)]),
        ),
      ));

      final trigger = tester.getSize(find.byType(PopupMenuButton<String>));
      expect(trigger.width, greaterThanOrEqualTo(44));
      expect(trigger.height, greaterThanOrEqualTo(44));
    });
  });
}
