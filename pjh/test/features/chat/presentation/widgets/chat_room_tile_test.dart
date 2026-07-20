import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/chat/domain/entities/chat_room.dart';
import 'package:meong_nyang_diary/features/chat/presentation/widgets/chat_room_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('과거 로컬 음소거 값이 있어도 가짜 알림 끔 아이콘을 노출하지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'chat_notification_room-1': false,
    });
    final room = ChatRoom(
      id: 'room-1',
      type: ChatRoomType.group,
      name: '산책 모임',
      createdBy: 'user-1',
      createdAt: DateTime(2026, 7, 20),
      updatedAt: DateTime(2026, 7, 20),
    );
    var morePressed = 0;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: ChatRoomTile(
              room: room,
              currentUserId: 'user-1',
              onTap: () {},
              onMorePressed: () => morePressed++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('산책 모임'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);

    final more = find.byKey(const Key('chat_room_more_room-1'));
    expect(more, findsOneWidget);
    final size = tester.getSize(more);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    await tester.tap(more);
    expect(morePressed, 1);
  });
}
