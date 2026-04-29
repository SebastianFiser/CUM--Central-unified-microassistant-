import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'mqtt_client.dart';
import 'package:uuid/uuid.dart';

var uuid = Uuid();
String COMMAND_TOPIC = "cum/command/core";

String make_id() {
  return uuid.v4();
}

String _shortNumericSuffix() {
  final hex = uuid.v4().replaceAll('-', '').substring(0, 6);
  final num =
      int.tryParse(hex, radix: 16) ?? DateTime.now().millisecondsSinceEpoch;
  return (num % 10000).toString().padLeft(4, '0');
}

String _platformName() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
  }
  // Fallback for any unknown or future platforms
  return 'unknown';
}

String generateSenderId(String deviceId) {
  final base = deviceId
      .split('_')
      .firstWhere((s) => s.isNotEmpty, orElse: () => 'device');
  final platform = _platformName();
  final suffix = _shortNumericSuffix();
  return '$base-$platform-$suffix';
}

void buildRegisterCommand(String device_id, {String? senderId}) {
  final sid = senderId ?? generateSenderId(device_id);
  final message = {
    'id': make_id(),
    'sender_id': sid,
    'session_id': make_id(),
    'type': 'command',
    'action': 'register',
    'payload': {
      'device_id': device_id,
      'meta': {'kind': 'flutter_app'},
    },
  };
  final String enc_msg = jsonEncode(message);
  Publish(COMMAND_TOPIC, enc_msg);
}

void connectAndRegister(String device_id, {String? senderId}) async {
  // allow caller to provide a sender/client id, otherwise generate one
  final sid = senderId ?? generateSenderId(device_id);
  final ok = await connect(clientId: sid);
  if (ok) {
    buildRegisterCommand(device_id, senderId: sid);
  } else {
    print('MQTT connect failed; registration skipped');
  }
}
