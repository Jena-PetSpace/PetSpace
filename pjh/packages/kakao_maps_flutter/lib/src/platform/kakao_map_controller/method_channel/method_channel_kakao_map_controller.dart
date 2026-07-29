part of '../kakao_map_controller.dart';

class MethodChannelKakaoMapController extends KakaoMapControllerPlatform {
  MethodChannelKakaoMapController._(MethodChannel? channel)
      : _channel = channel {
    // Keep readiness errors observable to explicit awaiters without allowing an
    // unobserved native initialization failure to escape into the root zone.
    _readyCompleter.future.ignore();
  }

  factory MethodChannelKakaoMapController.create(int viewId) {
    final channel = MethodChannel(
      'view.method_channel.kakao_maps_flutter#$viewId',
    );
    final controller = MethodChannelKakaoMapController._(channel);
    channel.setMethodCallHandler(controller._handleMethodCall);
    unawaited(controller._probeReadyState());
    return controller;
  }

  /// Default platform-interface placeholder.
  ///
  /// Controllers created for platform views are intentionally not stored here;
  /// each view owns its own channel, readiness state, and event streams.
  static MethodChannelKakaoMapController get instance => _defaultInstance;

  static final MethodChannelKakaoMapController _defaultInstance =
      MethodChannelKakaoMapController._(null);

  final MethodChannel? _channel;
  final Completer<void> _readyCompleter = Completer<void>();

  /// Completes when the native Kakao map reports that it is ready.
  Future<void> get ready => _readyCompleter.future;

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onMapReady') {
      _completeReady();
      return;
    }

    if (call.method == 'onMapError') {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.completeError(
          StateError('Kakao map failed to initialize: ${call.arguments}'),
        );
      }
      return;
    }

    if (call.method == 'onLabelClicked') {
      final event = LabelClickEvent.fromJson(_asStringKeyedMap(call.arguments));
      onLabelClicked(event);
      return;
    }

    if (call.method == 'onInfoWindowClicked') {
      final event = InfoWindowClickEvent.fromJson(
        _asStringKeyedMap(call.arguments),
      );
      onInfoWindowClicked(event);
      return;
    }

    if (call.method == 'onCameraMoveEnd') {
      final event = CameraMoveEndEvent.fromJson(
        _asStringKeyedMap(call.arguments),
      );
      onCameraMoveEnd(event);
      return;
    }

    throw UnimplementedError(
      '[Flutter:MethodChannelKakaoMapController] ${call.method} not implemented',
    );
  }

  Future<void> _probeReadyState() async {
    final channel = _channel;
    if (channel == null) return;

    try {
      final isReady = await channel.invokeMethod<bool>('isMapReady');
      if (isReady == true) _completeReady();
    } on MissingPluginException {
      // Older native implementations do not expose the readiness probe.
      // Their onMapReady event still completes [ready].
    } on PlatformException {
      // A transient probe failure must not replace the authoritative native
      // onMapReady/onMapError callbacks.
    }
  }

  void _completeReady() {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  @override
  Future<T> _callMethod<T>(KakaoMapMethodCall<T> methodCall) async {
    final channel = _channel;
    if (channel == null) {
      throw StateError('Kakao map controller is not bound to a platform view');
    }

    await ready;
    final result = await channel.invokeMethod(
      methodCall.name,
      methodCall.encode(),
    );

    return methodCall.decode(_normalizeStandardCodec(result));
  }

  static Object? _normalizeStandardCodec(Object? value) {
    if (value is Map) {
      return value.map<String, Object?>(
        (key, dynamic val) =>
            MapEntry(key.toString(), _normalizeStandardCodec(val)),
      );
    }
    if (value is List) {
      return value.map<Object?>((e) => _normalizeStandardCodec(e)).toList();
    }
    return value;
  }

  static Map<String, Object?> _asStringKeyedMap(Object? arguments) {
    final normalized = _normalizeStandardCodec(arguments);
    return (normalized! as Map).cast<String, Object?>();
  }

  @override
  void dispose() {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.completeError(
        StateError('Kakao map controller was disposed before it became ready'),
      );
    }
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }
}
