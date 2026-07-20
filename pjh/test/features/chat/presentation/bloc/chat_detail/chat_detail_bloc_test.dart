import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/chat/domain/entities/chat_message.dart';
import 'package:meong_nyang_diary/features/chat/domain/usecases/get_chat_messages.dart';
import 'package:meong_nyang_diary/features/chat/domain/usecases/send_image_message.dart';
import 'package:meong_nyang_diary/features/chat/domain/usecases/send_message.dart';
import 'package:meong_nyang_diary/features/chat/domain/usecases/send_multi_image_message.dart';
import 'package:meong_nyang_diary/features/chat/domain/usecases/update_last_read.dart';
import 'package:meong_nyang_diary/features/chat/presentation/bloc/chat_detail/chat_detail_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetChatMessages extends Mock implements GetChatMessages {}

class _MockSendMessage extends Mock implements SendMessage {}

class _MockSendImageMessage extends Mock implements SendImageMessage {}

class _MockSendMultiImageMessage extends Mock
    implements SendMultiImageMessage {}

class _MockUpdateLastRead extends Mock implements UpdateLastRead {}

ChatMessage _message(String id, {String content = 'hello'}) => ChatMessage(
      id: id,
      roomId: 'room-1',
      senderId: 'user-1',
      content: content,
      createdAt: DateTime(2026, 7, 20),
    );

void main() {
  late _MockGetChatMessages getMessages;
  late _MockSendMessage sendMessage;
  late _MockSendImageMessage sendImage;
  late _MockSendMultiImageMessage sendMultiImage;
  late _MockUpdateLastRead updateRead;
  late ChatDetailBloc bloc;

  setUpAll(() {
    registerFallbackValue(const GetChatMessagesParams(roomId: 'fallback'));
    registerFallbackValue(const SendMessageParams(
      roomId: 'fallback',
      senderId: 'fallback',
      content: 'fallback',
    ));
    registerFallbackValue(SendImageMessageParams(
      roomId: 'fallback',
      senderId: 'fallback',
      imageFile: File('fallback.jpg'),
    ));
    registerFallbackValue(SendMultiImageMessageParams(
      roomId: 'fallback',
      senderId: 'fallback',
      images: [File('fallback.jpg')],
    ));
    registerFallbackValue(const UpdateLastReadParams(
      roomId: 'fallback',
      userId: 'fallback',
    ));
  });

  setUp(() {
    getMessages = _MockGetChatMessages();
    sendMessage = _MockSendMessage();
    sendImage = _MockSendImageMessage();
    sendMultiImage = _MockSendMultiImageMessage();
    updateRead = _MockUpdateLastRead();
    bloc = ChatDetailBloc(
      getChatMessages: getMessages,
      sendMessage: sendMessage,
      sendImageMessage: sendImage,
      sendMultiImageMessage: sendMultiImage,
      updateLastRead: updateRead,
    );
    when(() => getMessages(any()))
        .thenAnswer((_) async => const Right(<ChatMessage>[]));
  });

  tearDown(() => bloc.close());

  Future<void> load() async {
    bloc.add(const ChatDetailLoadRequested(roomId: 'room-1'));
    await bloc.stream.firstWhere((state) => state is ChatDetailLoaded);
  }

  test('텍스트 전송 실패 outcome이 원문을 보존하고 재시도할 수 있다', () async {
    var attempts = 0;
    when(() => sendMessage(any())).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) {
        return const Left(ServerFailure(message: '전송 실패'));
      }
      return Right(_message('m-1'));
    });
    await load();

    bloc.add(const ChatDetailSendTextRequested(
      roomId: 'room-1',
      senderId: 'user-1',
      content: '보존할 초안',
    ));
    final failed = await bloc.stream
        .where((state) => state is ChatDetailLoaded)
        .cast<ChatDetailLoaded>()
        .firstWhere(
          (state) => state.sendOutcome?.status == ChatSendStatus.failure,
        );

    expect(failed.sendOutcome?.text, '보존할 초안');
    expect(failed.messages, isEmpty);

    bloc.add(const ChatDetailRetryLastSendRequested());
    final succeeded = await bloc.stream
        .where((state) => state is ChatDetailLoaded)
        .cast<ChatDetailLoaded>()
        .firstWhere(
          (state) => state.sendOutcome?.status == ChatSendStatus.success,
        );

    expect(succeeded.messages.single.id, 'm-1');
    verify(() => sendMessage(any())).called(2);
  });

  test('다중 이미지는 전용 UseCase를 거치는 하나의 pending 계약을 쓴다', () async {
    when(() => sendMultiImage(any()))
        .thenAnswer((_) async => Right(_message('images')));
    await load();
    final images = [File('one.jpg'), File('two.jpg')];

    bloc.add(ChatDetailSendMultipleImagesRequested(
      roomId: 'room-1',
      senderId: 'user-1',
      images: images,
    ));
    final succeeded = await bloc.stream
        .where((state) => state is ChatDetailLoaded)
        .cast<ChatDetailLoaded>()
        .firstWhere(
          (state) => state.sendOutcome?.status == ChatSendStatus.success,
        );

    expect(succeeded.sendOutcome?.kind, ChatSendKind.multiImage);
    expect(
      succeeded.sendOutcome?.images.map((file) => file.path),
      ['one.jpg', 'two.jpg'],
    );
    verify(() => sendMultiImage(any())).called(1);
  });

  test('과거 메시지 로딩 중 수신한 실시간 메시지를 보존한다', () async {
    final loadMoreCompleter = Completer<Either<Failure, List<ChatMessage>>>();
    var requestCount = 0;
    when(() => getMessages(any())).thenAnswer((_) {
      requestCount++;
      if (requestCount == 1) {
        return Future.value(
          Right(
            List.generate(
              30,
              (index) => _message('current-$index'),
            ),
          ),
        );
      }
      return loadMoreCompleter.future;
    });

    await load();
    bloc.add(const ChatDetailLoadMoreRequested(roomId: 'room-1'));
    await bloc.stream
        .where((state) => state is ChatDetailLoaded)
        .cast<ChatDetailLoaded>()
        .firstWhere((state) => state.isLoadingMore);

    bloc.add(ChatDetailNewMessageReceived(message: _message('realtime')));
    await bloc.stream
        .where((state) => state is ChatDetailLoaded)
        .cast<ChatDetailLoaded>()
        .firstWhere(
          (state) => state.messages.first.id == 'realtime',
        );

    loadMoreCompleter.complete(Right([_message('older')]));
    final completed = await bloc.stream
        .where((state) => state is ChatDetailLoaded)
        .cast<ChatDetailLoaded>()
        .firstWhere((state) => !state.isLoadingMore);

    expect(completed.messages.first.id, 'realtime');
    expect(completed.messages.map((message) => message.id), contains('older'));
    expect(completed.messages.last.id, 'older');
    expect(completed.messages, hasLength(32));
  });
}
