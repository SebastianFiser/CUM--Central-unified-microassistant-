import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../mqtt_client.dart';
import '../message_builder.dart';

class DeviceList extends StatefulWidget {
  const DeviceList({super.key});

  @override
  _DeviceListState createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList> {
  final Map<String, Map<String, dynamic>> _devices = {};
  StreamSubscription<Map<String, String>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = mqttMessageStream.listen(_handleMessage);
  }

  void _handleMessage(Map<String, String> m) {
    final payloadStr = m['payload'] ?? '{}';
    Map<String, dynamic> doc;
    try {
      doc = jsonDecode(payloadStr) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = doc['type'];
    if (type == 'event') {
      final event = doc['event'];
      if (event == 'device_registered') {
        final did = doc['payload']?['device_id'] as String?;
        if (did != null) {
          _upsertDevice(did, {'status': 'online'});
        }
      } else if (event == 'heartbeat_ack') {
        final did = doc['payload']?['device_id'] as String?;
        if (did != null) {
          _upsertDevice(did, {'status': 'online'});
        }
      }
    } else if (type == 'command') {
      final action = doc['action'];
      if (action == 'heartbeat') {
        final did = doc['payload']?['device_id'] as String?;
        if (did != null) {
          _upsertDevice(did, {'status': 'online'});
        }
      } else if (action == 'register') {
        final did = doc['payload']?['device_id'] as String?;
        if (did != null) {
          _upsertDevice(did, {'status': 'online'});
        }
      }
    }
  }

  void _upsertDevice(String deviceId, Map<String, dynamic> patch) {
    final now = DateTime.now();
    setState(() {
      final cur = _devices[deviceId] ?? {'device_id': deviceId};
      cur['last_seen'] = now;
      cur['status'] = patch['status'] ?? cur['status'] ?? 'unknown';
      _devices[deviceId] = cur;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  String _formatTime(DateTime? t) {
    if (t == null) return '-';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ids = _devices.keys.toList()..sort();
    return ListView.builder(
      itemCount: ids.length,
      itemBuilder: (_, i) {
        final id = ids[i];
        final info = _devices[id]!;
        final last = info['last_seen'] as DateTime?;
        final status = info['status'] as String? ?? 'unknown';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: status == 'online' ? Colors.green : Colors.grey,
            child: Text(id.substring(0, 1).toUpperCase()),
          ),
          title: Text(id),
          subtitle: Text('status: $status • Last: ${_formatTime(last)}'),
          trailing: IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              final session = getSessionId();
              final msgMap = buildPing(
                deviceId: id,
                senderId: 'ui',
                sessionId: session,
              );
              final msg = jsonEncode(msgMap);
              Publish('cum/command/core', msg, qos: MqttQos.atLeastOnce);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Ping sent to $id')));
            },
          ),
        );
      },
    );
  }
}
