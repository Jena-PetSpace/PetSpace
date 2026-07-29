/// Camera move end event
/// [EN]
/// - Fired when camera movement finishes with final pose values
///
/// [KO]
/// - 카메라 이동이 끝났을 때 최종 상태 값과 함께 발행되는 이벤트
class CameraMoveEndEvent {
  /// From JSON map
  factory CameraMoveEndEvent.fromJson(Map<String, Object?> json) {
    return CameraMoveEndEvent(
      latitude: (json['latitude']! as num).toDouble(),
      longitude: (json['longitude']! as num).toDouble(),
      zoomLevel: (json['zoomLevel']! as num).toDouble(),
      tilt: (json['tilt']! as num).toDouble(),
      rotation: (json['rotation']! as num).toDouble(),
      movedBy: json['movedBy'] as String?,
    );
  }

  /// Create event
  const CameraMoveEndEvent({
    required this.latitude,
    required this.longitude,
    required this.zoomLevel,
    required this.tilt,
    required this.rotation,
    this.movedBy,
  });

  /// Latitude
  final double latitude;

  /// Longitude
  final double longitude;

  /// Zoom level
  final double zoomLevel;

  /// Tilt angle (deg)
  final double tilt;

  /// Rotation angle (deg)
  final double rotation;

  /// Camera movement origin.
  ///
  /// Values emitted by the native implementations are `gesture`,
  /// `programmatic`, or `unknown`. This remains nullable for compatibility
  /// with events from older native implementations. The Android SDK reports
  /// programmatic movement through its `Unknown` gesture type, so this value is
  /// best-effort. Consumers should suppress work only for explicit
  /// `programmatic`; treat `unknown` and null as possible user movement.
  final String? movedBy;

  /// To JSON map
  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'zoomLevel': zoomLevel,
        'tilt': tilt,
        'rotation': rotation,
        if (movedBy != null) 'movedBy': movedBy,
      };
}
