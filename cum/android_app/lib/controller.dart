import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'message_builder.dart';

var uuid = const Uuid();
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

void buildRegisterCommand(
  String deviceId, {
  String? senderId,
  String? sessionId,
}) {
  final sid = senderId ?? generateSenderId(deviceId);
  final message = buildRegisterPayload(
    deviceId: deviceId,
    senderId: sid,
    sessionId: sessionId,
  );
  final String encMsg = jsonEncode(message);
  Publish(COMMAND_TOPIC, encMsg, qos: MqttQos.atLeastOnce);
}

void connectAndRegister(String deviceId, {String? senderId}) async {
  // allow caller to provide a sender/client id, otherwise generate one
  final sid = senderId ?? generateSenderId(deviceId);
  final ok = await connect(clientId: sid, deviceId: deviceId);
  if (ok) {
    final session = getSessionId();
    buildRegisterCommand(deviceId, senderId: sid, sessionId: session);
    // Wait a short moment to give the register message a chance to arrive
    // at the broker/core before heartbeats start (reduces race causing stale heartbeat)
    await Future.delayed(const Duration(milliseconds: 300));
    startHeartbeat();
  } else {
    print('MQTT connect failed; registration skipped');
  }
}

/// Fetch short_id for a given `deviceId` from core.
/// Uses the `list_devices` command and listens for `devices_list` or
/// `device_registered` events on the shared MQTT stream.
Future<String?> fetchShortId(
  String deviceId, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final completer = Completer<String?>();
  StreamSubscription? sub;

  sub = mqttMessageStream.listen((msg) {
    try {
      final payloadStr = msg['payload'] ?? '';
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      if (data['type'] == 'event') {
        final ev = data['event'];
        final pl = data['payload'] as Map<String, dynamic>;
        if (ev == 'devices_list') {
          final deviceEntry = pl[deviceId];
          if (deviceEntry != null) {
            final short = (deviceEntry['meta'] ?? {})['short_id'];
            if (short != null) {
              if (!completer.isCompleted) completer.complete(short as String?);
              sub?.cancel();
            }
          }
        } else if (ev == 'device_registered' || ev == 'heartbeat_ack') {
          final dev = (data['payload'] ?? {}) as Map<String, dynamic>;
          if (dev['device_id'] == deviceId && dev.containsKey('short_id')) {
            if (!completer.isCompleted)
              completer.complete(dev['short_id'] as String?);
            sub?.cancel();
          }
        }
      }
    } catch (_) {}
  });

  // Send list_devices command to core
  final req = {
    'id': make_id(),
    'sender_id': getDeviceId() ?? 'flutter_client',
    'session_id': getSessionId(),
    'type': 'command',
    'action': 'list_devices',
    'payload': {},
  };
  Publish(COMMAND_TOPIC, jsonEncode(req));

  try {
    return await completer.future.timeout(
      timeout,
      onTimeout: () {
        sub?.cancel();
        return null;
      },
    );
  } finally {
    try {
      await sub?.cancel();
    } catch (_) {}
  }
}
