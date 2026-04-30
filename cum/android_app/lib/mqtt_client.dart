import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
// import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'message_builder.dart';

dynamic _client;
bool _dotenvLoaded = false;
String? _lastClientId;
String? _lastServerUri;
String? _deviceId;
final _incomingController = StreamController<Map<String, String>>.broadcast();
Stream<Map<String, String>> get mqttMessageStream => _incomingController.stream;
// Heartbeat state
Timer? _heartbeatTimer;
int _heartbeatInterval = 5; // seconds
String? _sessionId;

Future<bool> connect({
  String clientId = 'flutter_client',
  String? deviceId,
}) async {
  if (deviceId != null) {
    _deviceId = deviceId;
  }
  if (!_dotenvLoaded) {
    try {
      await dotenv.load();
    } catch (_) {}
    _dotenvLoaded = true;
  }

  final wsUrl = dotenv.env['HIVEMQ_WS'];
  final hostFromEnv = dotenv.env['HIVEMQ_HOST'];
  final portFromEnv = dotenv.env['HIVEMQ_PORT'];
  final username = dotenv.env['HIVEMQ_USERNAME'];
  final password = dotenv.env['HIVEMQ_PASSWORD'];
  final wsPortFromEnv = dotenv.env['HIVEMQ_WEBSOCKET_PORT'];
  final loggingOn =
      (dotenv.env['MQTT_LOG']?.toLowerCase() == '1' ||
      dotenv.env['MQTT_LOG']?.toLowerCase() == 'true');

  String host;
  int port;
  String? path;
  bool useWebSocket = false;
  bool secure = false;

  if (wsUrl != null && wsUrl.isNotEmpty) {
    final uri = Uri.parse(wsUrl);
    host = uri.host;
    port = (uri.hasPort && uri.port != 0)
        ? uri.port
        : (uri.scheme == 'wss' ? 443 : 80);
    path = uri.path;
    useWebSocket = true;
    secure = uri.scheme == 'wss';
  } else {
    host = hostFromEnv ?? 'localhost';
    port = int.tryParse(portFromEnv ?? '') ?? 1883;
    secure = (port == 8883 || port == 8884);
  }

  _lastClientId = clientId;
  print(
    'MQTT(TCP) host: $host port: $port useWebSocket: $useWebSocket secure: $secure',
  );
  print('MQTT username: ${username ?? '<none>'}');
  _client = MqttServerClient.withPort(host, clientId, port);
  _client.logging(on: loggingOn);
  _client.keepAlivePeriod = 20;
  _client.onConnected = _onConnected;
  _client.onDisconnected = _onDisconnected;
  _client.onSubscribed = _onSubscribed;

  if (useWebSocket) {
    _client.useWebSocket = true;
    _client.websocketProtocols = ['mqtt'];
    // try to set websocket path if available in this mqtt_client version
    if (path != null && path.isNotEmpty) {
      try {
        (_client as dynamic).websocketPath = path;
      } catch (_) {}
    }
  } else {
    _client.secure = secure;
  }

  var connMessage = MqttConnectMessage()
      .withClientIdentifier(clientId)
      .startClean();
  if (username != null && username.isNotEmpty) {
    connMessage = connMessage.authenticateAs(username, password ?? '');
  }
  _client!.connectionMessage = connMessage;

  try {
    await _client!.connect();
    if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
      print('MQTT connected');
      try {
        print(
          'Connection status: ${_client.connectionStatus?.state} (${_client.connectionStatus?.returnCode})',
        );
      } catch (_) {}
      _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );
        print('MQTT <- Topic: ${c[0].topic}, Payload: $pt');
        try {
          _incomingController.add({
            'topic': c[0].topic,
            'payload': pt,
            'time': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      });
      // Subscribe to channel topics so UI receives raw messages
      try {
        // Subscribe to our app namespace; adjust as needed
        _client!.subscribe('cum/#', MqttQos.atMostOnce);
        print('Subscribed to cum/#');
      } catch (e) {
        print('Subscribe failed: $e');
      }
      // Publish a small debug message so we can verify arrival in HiveMQ
      // Also schedule a delayed debug publish to ensure frames are flushed
      void sendDebugPublish() {
        try {
          final debugPayload = jsonEncode({
            'source': 'flutter',
            'clientId': _lastClientId ?? clientId,
            'time': DateTime.now().toIso8601String(),
            'server': _lastServerUri,
          });
          Publish('cum/debug/flutter', debugPayload);
          print('Debug publish scheduled/sent');
        } catch (e) {
          print('Debug publish failed: $e');
        }
      }

      // immediate attempt
      sendDebugPublish();
      // delayed attempt after 500ms
      Future.delayed(
        const Duration(milliseconds: 500),
        () => sendDebugPublish(),
      );
      return true;
    } else {
      print('MQTT connection failed: ${_client!.connectionStatus}');
      _client!.disconnect();
      return false;
    }
  } catch (e) {
    print('MQTT connect exception: $e');
    try {
      _client!.disconnect();
    } catch (_) {}
    return false;
  }
}

String getSessionId() {
  _sessionId ??= makeId();
  return _sessionId!;
}

String? getDeviceId() {
  return _deviceId ?? _lastClientId;
}

//Generates session ID ONCE ONLY (needed for heartbeat logic) why isnt it working ffs
void disconnect() {
  try {
    _client?.disconnect();
  } catch (_) {}
}

void Publish(String topic, String message, {MqttQos qos = MqttQos.atMostOnce}) {
  if (_client == null) {
    print('MQTT client not initialized');
    return;
  }
  try {
    print('Publishing -> Topic: $topic | Payload: $message');
    print('Client state: ${_client.connectionStatus?.state}');
    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      print('WARN: client not connected, publish will likely fail');
    }
  } catch (_) {}
  final builder = MqttClientPayloadBuilder();
  builder.addString(message);
  _client!.publishMessage(topic, qos, builder.payload!);
}

void Subscribe(String topic, {MqttQos qos = MqttQos.atMostOnce}) {
  _client?.subscribe(topic, qos);
}

// callbacks
void _onConnected() {
  print('MQTT onConnected');
}

void _onDisconnected() {
  try {
    print('MQTT onDisconnected, status=${_client?.connectionStatus}');
    _stopHeartbeat();
  } catch (_) {
    print('MQTT onDisconnected');
  }
}

void _onSubscribed(String topic) {
  print('MQTT subscribed to $topic');
}

// Heartbeat control
void _startHeartbeat({String topic = 'cum/command/core'}) {
  _stopHeartbeat();
  _sessionId ??= makeId();
  final sender = _lastClientId ?? 'flutter_client';

  void send() {
    try {
      final map = buildHeartBeat(
        deviceId: _deviceId ?? sender,
        sessionId: _sessionId!,
        senderId: sender,
      );
      Publish(topic, jsonEncode(map), qos: MqttQos.atLeastOnce);
      print('Heartbeat sent: ${map['id']}');
    } catch (e) {
      print('Heartbeat publish failed: $e');
    }
  }

  // send immediately and then periodically
  send();
  _heartbeatTimer = Timer.periodic(
    Duration(seconds: _heartbeatInterval),
    (_) => send(),
  );
}

void _stopHeartbeat() {
  try {
    _heartbeatTimer?.cancel();
  } catch (_) {}
  _heartbeatTimer = null;
}

/// Start heartbeat from external caller (e.g. after sending register)
void startHeartbeat({String topic = 'cum/command/core'}) {
  _startHeartbeat(topic: topic);
}
//why does this file have 47 problems :cry: