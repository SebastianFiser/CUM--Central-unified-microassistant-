import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

dynamic _client;
bool _dotenvLoaded = false;
String? _lastClientId;
String? _lastServerUri;
final _incomingController = StreamController<Map<String, String>>.broadcast();
Stream<Map<String, String>> get mqttMessageStream => _incomingController.stream;

Future<bool> connect({String clientId = 'flutter_client'}) async {
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
    if (kIsWeb) {
      port =
          int.tryParse(wsPortFromEnv ?? '') ??
          int.tryParse(portFromEnv ?? '') ??
          8884;
    } else {
      port = int.tryParse(portFromEnv ?? '') ?? 1883;
    }
    if (kIsWeb) {
      useWebSocket = true;
      secure = true;
    } else {
      secure = (port == 8883 || port == 8884);
    }
  }

  _lastClientId = clientId;
  if (kIsWeb) {
    // For web builds use the browser client with full server URI
    final serverUri = wsUrl != null && wsUrl.isNotEmpty
        ? wsUrl
        : '${secure ? 'wss' : 'ws'}://$host:$port${path ?? '/mqtt'}';
    print('MQTT(Web) serverUri: $serverUri');
    _lastServerUri = serverUri;
    print('MQTT username: ${username ?? '<none>'}');

    // Some versions of mqtt_client parse the provided server string
    // differently and may fall back to port 1883. To ensure the
    // browser WS connection uses the correct port and path, create
    // the browser client with the host and then set port/path via
    // dynamic properties where available.
    _client = MqttBrowserClient(host, clientId);
    try {
      (_client as dynamic).port = port;
    } catch (_) {
      // ignore if property not present
    }
    try {
      (_client as dynamic).websocketPath = path ?? '/mqtt';
    } catch (_) {}
    try {
      (_client as dynamic).websocketProtocols = ['mqtt'];
    } catch (_) {}
    try {
      (_client as dynamic).secure = secure;
    } catch (_) {}
    try {
      // some implementations expose 'server' as hostname or accept a full URI
      // set it to the full serverUri (including scheme) to avoid "incorrect scheme" parsing
      (_client as dynamic).server = serverUri;
    } catch (_) {}
    String configuredServer;
    int configuredPort;
    String configuredPath;
    try {
      configuredServer = (_client as dynamic).server ?? host;
    } catch (_) {
      configuredServer = host;
    }
    try {
      configuredPort = (_client as dynamic).port ?? port;
    } catch (_) {
      configuredPort = port;
    }
    try {
      configuredPath = (_client as dynamic).websocketPath ?? path ?? '/mqtt';
    } catch (_) {
      configuredPath = path ?? '/mqtt';
    }
    print(
      'MQTT(Web) client configured server=$configuredServer port=$configuredPort path=$configuredPath',
    );
    _client.logging(on: loggingOn);
    _client.keepAlivePeriod = 20;
    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onSubscribed = _onSubscribed;
    // also try to publish a debug message from onConnected to ensure underlying WS is open
  } else {
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
          _incomingController.add({'topic': c[0].topic, 'payload': pt});
        } catch (_) {}
      });
      // Publish a small debug message so we can verify arrival in HiveMQ
      // Also schedule a delayed debug publish to ensure frames are flushed
      void _sendDebugPublish() {
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
      _sendDebugPublish();
      // delayed attempt after 500ms
      Future.delayed(Duration(milliseconds: 500), () => _sendDebugPublish());
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
  } catch (_) {
    print('MQTT onDisconnected');
  }
}

void _onSubscribed(String topic) {
  print('MQTT subscribed to $topic');
}
