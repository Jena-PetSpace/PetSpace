import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/widgets/pet_card.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Pet buildPet({
    String id = 'pet-1',
    String name = 'hyun',
    String? breed = '비글',
    bool includeBirthDate = true,
    PetGender? gender = PetGender.male,
    String? avatarUrl,
  }) {
    return Pet(
      id: id,
      userId: 'user-1',
      name: name,
      type: PetType.dog,
      breed: breed,
      birthDate: includeBirthDate
          ? DateTime.now().subtract(const Duration(days: 180))
          : null,
      gender: gender,
      avatarUrl: avatarUrl,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required Pet pet,
    bool isSelected = false,
    ThemeData? theme,
    Size surface = const Size(390, 844),
    double textScale = 1,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onSetPrimary,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: PetCard(
              pet: pet,
              isSelected: isSelected,
              onEdit: onEdit,
              onDelete: onDelete,
              onSetPrimary: onSetPrimary,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('대표 카드는 action 경계와 대표 chip만 사용하고 정보 위계를 유지한다', (tester) async {
    final pet = buildPet();
    await pumpCard(tester, pet: pet, isSelected: true);

    expect(find.text('hyun'), findsOneWidget);
    expect(find.text('대표'), findsOneWidget);
    expect(find.text('비글'), findsOneWidget);
    expect(find.text('수컷'), findsOneWidget);
    expect(find.text('강아지'), findsOneWidget);

    final nameRect = tester.getRect(
      find.byKey(const Key('pet_card_name_pet-1')),
    );
    final primaryBadgeRect = tester.getRect(
      find.byKey(const Key('pet_card_primary_badge_pet-1')),
    );
    expect(primaryBadgeRect.left - nameRect.right, closeTo(6, 1));

    final cardMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('pet_card_pet-1')),
            matching: find.byType(Material),
          )
          .first,
    );
    final shape = cardMaterial.shape! as RoundedRectangleBorder;
    expect(shape.side.color, AppTheme.actionBase);
    expect(cardMaterial.color, AppTheme.surfaceColor);
    expect(
      tester.getSize(find.byKey(const Key('pet_card_menu_trigger_pet-1'))),
      const Size(44, 44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('미입력 정보와 메뉴 callback을 안전하게 처리한다', (tester) async {
    var primaryCalls = 0;
    var editCalls = 0;
    var deleteCalls = 0;
    final pet = buildPet(
      breed: null,
      includeBirthDate: false,
      gender: null,
    );
    await pumpCard(
      tester,
      pet: pet,
      onSetPrimary: () => primaryCalls++,
      onEdit: () => editCalls++,
      onDelete: () => deleteCalls++,
    );

    expect(find.text('품종 미상'), findsOneWidget);
    expect(find.text('나이 미상'), findsOneWidget);
    expect(find.text('수컷'), findsNothing);
    expect(find.text('암컷'), findsNothing);
    expect(find.byKey(const Key('pet_card_avatar_fallback_pet-1')),
        findsOneWidget);
    expect(find.byKey(const Key('pet_card_primary_badge_pet-1')), findsNothing);

    final menu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('pet_card_menu_pet-1')),
    );
    menu.onSelected!('primary');
    menu.onSelected!('edit');
    menu.onSelected!('delete');
    expect(primaryCalls, 1);
    expect(editCalls, 1);
    expect(deleteCalls, 1);
  });

  testWidgets('긴 이름·150% 글자에서도 overflow 없고 사진 성공·오류 표현을 제공한다', (tester) async {
    const avatarUrl = 'https://example.com/pet.jpg';
    final pet = buildPet(
      name: '아주아주긴반려동물이름이한줄을넘어가는경우',
      avatarUrl: avatarUrl,
    );
    await pumpCard(
      tester,
      pet: pet,
      isSelected: true,
      surface: const Size(320, 568),
      textScale: 1.5,
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byKey(const Key('pet_card_network_image_pet-1')),
    );
    expect(image.imageUrl, avatarUrl);
    final errorWidget = image.errorWidget!(
      tester.element(find.byKey(const Key('pet_card_network_image_pet-1'))),
      avatarUrl,
      Exception('network failure'),
    );
    expect(errorWidget.key, const Key('pet_card_image_error_pet-1'));
    expect(
      find.byKey(const Key('pet_card_primary_badge_pet-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
