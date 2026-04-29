import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client.dart';
import 'package:uuid/uuid.dart';
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

//WHY CANT YOU WORK GOD I DONT UNDERSTAND IT
