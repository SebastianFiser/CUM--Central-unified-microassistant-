import 'package:uuid/uuid.dart';

final _uuid = Uuid();

String makeId() => _uuid.v4();

Map<String, dynamic> buildRegisterPayload({
  required String deviceId,
  required String senderId,
  String? sessionId,
}) {
  final sid = sessionId ?? makeId();
  return {
    'id': makeId(),
    'sender_id': senderId,
    'session_id': sid,
    'type': 'command',
    'action': 'register',
    'payload': {
      'device_id': deviceId,
      'meta': {'kind': 'flutter_app'},
    },
  };
}

Map<String, dynamic> buildHeartBeat({
  required String deviceId,
  required String sessionId,
  required String senderId,
}) {
  return {
    'id': makeId(),
    'sender_id': senderId,
    'session_id': sessionId,
    'type': 'command',
    'action': 'heartbeat',
    'payload': {
      'device_id': deviceId,
      'time': DateTime.now().toIso8601String(),
    },
  };
}

// Build a ping command matching device.py semantics
Map<String, dynamic> buildPing({
  required String deviceId,
  required String senderId,
  required String sessionId,
  String? messageId,
}) {
  return {
    'id': messageId ?? makeId(),
    'sender_id': senderId,
    'session_id': sessionId,
    'type': 'command',
    'action': 'ping',
    'payload': {},
  };
}
