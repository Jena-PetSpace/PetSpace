import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/shared/models/petspace_icon_asset.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_icon.dart';

void main() {
  testWidgets('컬러 기능 아이콘은 래스터 원본으로 렌더링한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetSpaceIcon(asset: PetSpaceIconAsset.quickPlace, size: 30),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 30);
    expect(image.height, 30);
    expect(
      (image.image as AssetImage).assetName,
      PetSpaceIconAsset.quickPlace.path,
    );
  });

  testWidgets('단색 SVG 아이콘은 IconTheme 색상을 적용한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IconTheme(
            data: IconThemeData(color: Colors.teal),
            child: PetSpaceIcon(asset: PetSpaceIconAsset.actionClose, size: 24),
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, 24);
    expect(svg.height, 24);
    expect(svg.colorFilter, isNotNull);
  });

  testWidgets('지정한 접근성 라벨을 한 번만 노출한다', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetSpaceIcon(
            asset: PetSpaceIconAsset.quickQuiz,
            semanticLabel: 'O/X 퀴즈',
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('O/X 퀴즈'), findsOneWidget);
    semantics.dispose();
  });
}
