import 'package:flutter/services.dart';

enum PhoneFlipEventType { faceDown, pickedUp }

class PhoneFlipEvent {
  final PhoneFlipEventType type;
  final double? z;

  const PhoneFlipEvent({required this.type, this.z});

  factory PhoneFlipEvent.fromMap(Map<dynamic, dynamic> map) {
    final rawType = map['type']?.toString() ?? 'picked_up';
    return PhoneFlipEvent(
      type: rawType == 'face_down'
          ? PhoneFlipEventType.faceDown
          : PhoneFlipEventType.pickedUp,
      z: (map['z'] as num?)?.toDouble(),
    );
  }
}

class PhoneFlipService {
  static const _stateCh = MethodChannel('com.lsz.app/phone_flip');
  static const _eventsCh = EventChannel('com.lsz.app/phone_flip_events');

  static Stream<PhoneFlipEvent> events() {
    return _eventsCh.receiveBroadcastStream().map((event) {
      return PhoneFlipEvent.fromMap(event as Map<dynamic, dynamic>);
    });
  }

  static Future<bool> isFaceDown() async {
    try {
      final value = await _stateCh.invokeMethod<bool>('isFaceDown');
      return value ?? false;
    } catch (_) {
      return false;
    }
  }
}
