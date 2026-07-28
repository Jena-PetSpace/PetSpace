import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> sendNativeMethod(
    String channelName,
    String method, [
    Object? arguments,
  ]) {
    return messenger.handlePlatformMessage(
      channelName,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (ByteData? _) {},
    );
  }

  tearDown(() async {
    for (final viewId in <int>[1, 11, 22, 33, 44, 55]) {
      final channel = MethodChannel(
        'view.method_channel.kakao_maps_flutter#$viewId',
      );
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  test(
    'waits for the native ready signal before invoking map commands',
    () async {
      const channelName = 'view.method_channel.kakao_maps_flutter#1';
      const channel = MethodChannel(channelName);
      final calls = <String>[];

      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'isMapReady') return false;
        if (call.method == 'getZoomLevel') return 13;
        return null;
      });

      final controller = KakaoMapController(viewId: 1);
      addTearDown(controller.dispose);
      var completed = false;
      final zoomFuture = controller.getZoomLevel().then((value) {
        completed = true;
        return value;
      });

      await Future<void>.delayed(Duration.zero);
      expect(calls, contains('isMapReady'));
      expect(calls, isNot(contains('getZoomLevel')));
      expect(completed, isFalse);

      await sendNativeMethod(channelName, 'onMapReady', true);

      expect(await zoomFuture, 13);
      expect(calls, contains('getZoomLevel'));
    },
  );

  test(
    'routes native events to the controller that owns the view channel',
    () async {
      const firstChannelName = 'view.method_channel.kakao_maps_flutter#11';
      const secondChannelName = 'view.method_channel.kakao_maps_flutter#22';
      const firstChannel = MethodChannel(firstChannelName);
      const secondChannel = MethodChannel(secondChannelName);

      messenger.setMockMethodCallHandler(
        firstChannel,
        (call) async => call.method == 'isMapReady' ? true : null,
      );
      messenger.setMockMethodCallHandler(
        secondChannel,
        (call) async => call.method == 'isMapReady' ? true : null,
      );

      final first = KakaoMapController(viewId: 11);
      final second = KakaoMapController(viewId: 22);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final firstEvents = <CameraMoveEndEvent>[];
      final secondEvents = <CameraMoveEndEvent>[];
      final firstSub = first.onCameraMoveEndStream.listen(firstEvents.add);
      final secondSub = second.onCameraMoveEndStream.listen(secondEvents.add);

      await Future.wait(<Future<void>>[first.ready, second.ready]);
      await sendNativeMethod(
        firstChannelName,
        'onCameraMoveEnd',
        <String, Object?>{
          'latitude': 37.5,
          'longitude': 127,
          'zoomLevel': 14,
          'tilt': 0,
          'rotation': 0,
          'movedBy': 'gesture',
        },
      );
      await Future<void>.delayed(Duration.zero);

      expect(firstEvents, hasLength(1));
      expect(firstEvents.single.movedBy, 'gesture');
      expect(secondEvents, isEmpty);

      await firstSub.cancel();
      await secondSub.cancel();
    },
  );

  test('reports native initialization errors through ready', () async {
    const channelName = 'view.method_channel.kakao_maps_flutter#33';
    const channel = MethodChannel(channelName);

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isMapReady' ? false : null,
    );

    final controller = KakaoMapController(viewId: 33);
    addTearDown(controller.dispose);
    final readyExpectation = expectLater(
      controller.ready,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('failed to initialize'),
        ),
      ),
    );

    await sendNativeMethod(channelName, 'onMapError', 'sdk unavailable');

    await readyExpectation;
  });

  test('fails pending commands when disposed before ready', () async {
    const channelName = 'view.method_channel.kakao_maps_flutter#44';
    const channel = MethodChannel(channelName);

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isMapReady' ? false : null,
    );

    final controller = KakaoMapController(viewId: 44);
    final zoomExpectation = expectLater(
      controller.getZoomLevel(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('disposed before it became ready'),
        ),
      ),
    );

    await Future<void>.delayed(Duration.zero);
    controller.dispose();

    await zoomExpectation;
  });

  test('falls back to onMapReady when the readiness probe is unavailable',
      () async {
    const channelName = 'view.method_channel.kakao_maps_flutter#55';
    const channel = MethodChannel(channelName);
    final calls = <String>[];

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'isMapReady') {
        throw MissingPluginException('older native package');
      }
      if (call.method == 'getZoomLevel') return 12;
      return null;
    });

    final controller = KakaoMapController(viewId: 55);
    addTearDown(controller.dispose);
    final zoomFuture = controller.getZoomLevel();

    await Future<void>.delayed(Duration.zero);
    expect(calls, contains('isMapReady'));
    expect(calls, isNot(contains('getZoomLevel')));

    await sendNativeMethod(channelName, 'onMapReady', true);

    expect(await zoomFuture, 12);
  });
}
