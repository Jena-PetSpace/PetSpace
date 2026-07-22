import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/chat/domain/entities/chat_message.dart';
import 'package:meong_nyang_diary/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  ChatMessage message({
    String id = 'message-1',
    String senderId = 'user-1',
    String? content = '안녕하세요',
    ChatMessageType type = ChatMessageType.text,
    List<String>? imageUrls,
  }) {
    return ChatMessage(
      id: id,
      roomId: 'room-1',
      senderId: senderId,
      senderName: senderId == 'user-1' ? '나' : '콩떡이네',
      content: content,
      type: type,
      imageUrl: imageUrls?.length == 1 ? imageUrls!.first : null,
      imageUrls: imageUrls,
      createdAt: DateTime(2026, 7, 20, 14, 15),
    );
  }

  Future<void> pumpBubble(
    WidgetTester tester,
    ChatBubble bubble, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Scaffold(body: Center(child: bubble)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('내 메시지와 상대 메시지의 정렬과 표면을 구분한다', (tester) async {
    await pumpBubble(
      tester,
      ChatBubble(
        message: message(),
        isMine: true,
      ),
    );

    final mineFinder = find.byKey(const Key('chat_text_bubble_mine'));
    final mine = tester.widget<Container>(mineFinder);
    final mineDecoration = mine.decoration! as BoxDecoration;
    expect(mineDecoration.color, AppTheme.actionBase);
    expect(tester.getCenter(mineFinder).dx, greaterThan(195));

    await pumpBubble(
      tester,
      ChatBubble(
        message: message(senderId: 'user-2'),
        isMine: false,
        showSenderInfo: true,
      ),
    );

    final otherFinder = find.byKey(const Key('chat_text_bubble_other'));
    final other = tester.widget<Container>(otherFinder);
    final otherDecoration = other.decoration! as BoxDecoration;
    expect(otherDecoration.border, isNotNull);
    expect(tester.getCenter(otherFinder).dx, lessThan(195));
    expect(find.text('콩떡이네'), findsOneWidget);
  });

  testWidgets('시스템 메시지는 중앙 상태 표현으로 렌더한다', (tester) async {
    await pumpBubble(
      tester,
      ChatBubble(
        message: message(
          content: '콩떡이님이 채팅방에 참여했습니다.',
          type: ChatMessageType.system,
        ),
        isMine: false,
      ),
    );

    expect(find.byKey(const Key('chat_system_message')), findsOneWidget);
    expect(find.text('콩떡이님이 채팅방에 참여했습니다.'), findsOneWidget);
  });

  testWidgets('다중 이미지 5장 이상은 +N 오버레이를 표시한다', (tester) async {
    final urls = List.generate(6, (index) => 'https://example.com/$index.jpg');
    await pumpBubble(
      tester,
      ChatBubble(
        message: message(
          type: ChatMessageType.image,
          content: null,
          imageUrls: urls,
        ),
        isMine: true,
      ),
    );

    expect(find.byKey(const Key('chat_multi_image_grid')), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });

  for (final imageCount in [2, 3, 4]) {
    testWidgets(
      '다중 이미지 $imageCount장 레이아웃은 작은 화면에서도 모두 렌더한다',
      (tester) async {
        final urls = List.generate(
          imageCount,
          (index) => 'https://example.com/$imageCount-$index.jpg',
        );
        await pumpBubble(
          tester,
          ChatBubble(
            message: message(
              type: ChatMessageType.image,
              content: null,
              imageUrls: urls,
            ),
            isMine: true,
          ),
          size: const Size(320, 568),
          textScale: 1.5,
        );

        final grid = find.byKey(const Key('chat_multi_image_grid'));
        expect(grid, findsOneWidget);
        expect(
          find.descendant(
            of: grid,
            matching: find.byType(CachedNetworkImage),
          ),
          findsNWidgets(imageCount),
        );
        expect(find.textContaining('+'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('320x568과 150% 글자 크기에서 긴 메시지가 overflow하지 않는다', (tester) async {
    await pumpBubble(
      tester,
      ChatBubble(
        message: message(
          senderId: 'user-2',
          content: '오늘 공원에서 산책할까요? 글자가 커져도 말풍선 안에서 자연스럽게 줄바꿈되어야 합니다.',
        ),
        isMine: false,
        showSenderInfo: true,
      ),
      size: const Size(320, 568),
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('320x568과 200% 글자 크기에서도 메시지 메타가 overflow하지 않는다', (tester) async {
    await pumpBubble(
      tester,
      ChatBubble(
        message: message(
          senderId: 'user-2',
          content: '확대 글자에서도 메시지와 시간이 서로 겹치지 않고 읽혀야 합니다.',
        ),
        isMine: false,
        showSenderInfo: true,
      ),
      size: const Size(320, 568),
      textScale: 2,
    );

    expect(find.text('콩떡이네'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
