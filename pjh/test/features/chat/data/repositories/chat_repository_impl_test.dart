import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/core/services/block_service.dart';
import 'package:meong_nyang_diary/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:meong_nyang_diary/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRemoteDataSource extends Mock implements ChatRemoteDataSource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockBlockService extends Mock implements BlockService {}

void main() {
  late _MockChatRemoteDataSource dataSource;
  late _MockNetworkInfo networkInfo;
  late ChatRepositoryImpl repository;

  setUp(() {
    dataSource = _MockChatRemoteDataSource();
    networkInfo = _MockNetworkInfo();
    repository = ChatRepositoryImpl(
      remoteDataSource: dataSource,
      networkInfo: networkInfo,
      blockService: _MockBlockService(),
    );
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
  });

  test('메시지 전송 예외의 내부 상세를 Failure에 노출하지 않는다', () async {
    when(() => dataSource.sendMessage(
          roomId: any(named: 'roomId'),
          senderId: any(named: 'senderId'),
          content: any(named: 'content'),
        )).thenThrow(StateError('postgres secret detail'));

    final result = await repository.sendMessage(
      roomId: 'room-1',
      senderId: 'user-1',
      content: 'hello',
    );

    final failure = result.fold((value) => value, (_) => fail('실패여야 합니다'));
    expect(failure, isA<ServerFailure>());
    expect(failure.message, contains('메시지 전송에 실패했습니다'));
    expect(failure.message, isNot(contains('postgres secret detail')));
    expect(failure.message, isNot(contains('StateError')));
  });

  test('검색 예외는 결과 없음이 아니라 안전한 Failure로 전달한다', () async {
    when(() => dataSource.searchUsers(any()))
        .thenThrow(Exception('supabase query detail'));

    final result = await repository.searchUsers('콩');

    final failure = result.fold((value) => value, (_) => fail('실패여야 합니다'));
    expect(failure, isA<ServerFailure>());
    expect(failure.message, '사용자 검색에 실패했습니다. 다시 시도해주세요.');
    expect(failure.message, isNot(contains('supabase query detail')));
  });
}
