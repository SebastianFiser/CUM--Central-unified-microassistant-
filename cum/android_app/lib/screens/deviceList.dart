import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../mqtt_client.dart';
import '../message_builder.dart';
import '../incoming_handler.dart';

class DeviceList extends StatefulWidget {
  const DeviceList({super.key});

  @override
  _DeviceListState createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList> {
  final Map<String, Map<String, dynamic>> _devices = {};

  // handlers we register on incomingHandler
  void _onDeviceRegistered(MsgMap m) {
    final did = (m['payload'] as Map?)?['device_id'] as String?;
    if (did != null) _upsertDevice(did, {'status': 'online'});
  }

  void _onHeartbeatAck(MsgMap m) {
    final did = (m['payload'] as Map?)?['device_id'] as String?;
    if (did != null) _upsertDevice(did, {'status': 'online'});
  }

  @override
  void initState() {
    super.initState();
    // use centralized incoming handler
    incomingHandler.onAction('device_registered', _onDeviceRegistered);
    incomingHandler.onAction('heartbeat_ack', _onHeartbeatAck);
    // also listen to command actions that indicate device presence
    incomingHandler.onAction('register', (m) {
      final did = (m['payload'] as Map?)?['device_id'] as String?;
      if (did != null) _upsertDevice(did, {'status': 'online'});
    });
    incomingHandler.onAction('heartbeat', (m) {
      final did = (m['payload'] as Map?)?['device_id'] as String?;
      if (did != null) _upsertDevice(did, {'status': 'online'});
    });
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
    // remove handlers
    incomingHandler.offAction('device_registered', _onDeviceRegistered);
    incomingHandler.offAction('heartbeat_ack', _onHeartbeatAck);
    incomingHandler.offAction('register', (m) {});
    incomingHandler.offAction('heartbeat', (m) {});
    super.dispose();
  }

  String _formatTime(DateTime? t) {
    if (t == null) return '-';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final allIds = _devices.keys.toList()..sort();
    final local = getDeviceId();
    // show all devices except the local app instance; ensure `core` is present
    final ids = allIds.where((id) => id != local).toList();
    if (!ids.contains('core')) ids.insert(0, 'core');
    return ListView.builder(
      itemCount: ids.length,
      itemBuilder: (_, i) {
        final id = ids[i];
        final info = _devices.containsKey(id)
            ? _devices[id]!
            : {'device_id': id, 'status': 'offline', 'last_seen': null};
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
            icon: const Icon(Icons.send_outlined),
            onPressed: () async {
              final session = getSessionId();
              final msgId = makeId();
              final msgMap = buildPing(
                deviceId: id,
                senderId: 'ui',
                sessionId: session,
                messageId: msgId,
              );
              final msg = jsonEncode(msgMap);
              Publish('cum/command/core', msg, qos: MqttQos.atLeastOnce);

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Ping sent to $id')));

              // await pong reply matching message id
              try {
                final reply = await incomingHandler.waitForId(
                  msgId,
                  timeout: const Duration(seconds: 5),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Pong received from ${reply['sender_id'] ?? 'device'}',
                    ),
                  ),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No pong (timeout) from $id')),
                );
              }
            },
          ),
        );
      },
    );
  }
}
