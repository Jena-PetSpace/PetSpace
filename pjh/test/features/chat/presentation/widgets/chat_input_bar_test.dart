import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/chat/presentation/widgets/chat_input_bar.dart';

void main() {
  testWidgets('전송 요청 직후 입력을 지우지 않고 성공 신호를 기다린다', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              controller: controller,
              onSendText: (value) => submitted = value,
              onSendImage: (_) {},
              onSendMultipleImages: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '보존할 메시지');
    await tester.pump();
    await tester.tap(find.byTooltip('메시지 전송'));
    await tester.pump();

    expect(submitted, '보존할 메시지');
    expect(controller.text, '보존할 메시지');

    final sendButton = find.byTooltip('메시지 전송');
    final photoButton = find.byTooltip('사진 선택');
    expect(tester.getSize(sendButton).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(sendButton).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(photoButton).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(photoButton).height, greaterThanOrEqualTo(44));
  });

  testWidgets('전송 중에는 텍스트와 이미지 재제출을 막는다', (tester) async {
    final controller = TextEditingController(text: '메시지');
    addTearDown(controller.dispose);
    var textCalls = 0;
    var imageCalls = 0;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              controller: controller,
              isSending: true,
              onSendText: (_) => textCalls++,
              onSendImage: (File _) => imageCalls++,
              onSendMultipleImages: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('메시지 전송'), findsNothing);
    await tester.tap(find.byTooltip('사진 선택'));
    await tester.pump();
    expect(textCalls, 0);
    expect(imageCalls, 0);
  });

  testWidgets('SafeArea 하단 inset을 입력창 바깥 여백으로 보존한다', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 24),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ChatInputBar(
                  controller: controller,
                  onSendText: (_) {},
                  onSendImage: (_) {},
                  onSendMultipleImages: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final safeArea = tester.widget<SafeArea>(
      find.ancestor(
        of: find.byKey(const Key('chat_input_safe_area')),
        matching: find.byType(SafeArea),
      ),
    );
    expect(safeArea.top, isFalse);
    expect(safeArea.bottom, isTrue);
    expect(tester.takeException(), isNull);
  });
}
