import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../mqtt_client.dart';
import '../controller.dart';
import '../message_builder.dart';
import '../incoming_handler.dart';
import '../widgets/device_card.dart';

class DeviceList extends StatefulWidget {
  const DeviceList({super.key});

  @override
  _DeviceListState createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList> {
  final Map<String, Map<String, dynamic>> _devices = {};
  final Set<String> _fetching = {};

  // handlers we register on incomingHandler
  void _onDeviceRegistered(MsgMap m) {
    final payload = (m['payload'] as Map?) ?? {};
    final did = payload['device_id'] as String?;
    final short = payload['short_id'] as String?;
    final name = payload['name'] as String? ?? payload['meta']?['name'] as String?;
    if (did != null) {
      _upsertDevice(did, {'status': 'online', 'short_id': short, 'name': name});
    }
  }

  void _onHeartbeatAck(MsgMap m) {
    final payload = (m['payload'] as Map?) ?? {};
    final did = payload['device_id'] as String?;
    final short = payload['short_id'] as String?;
    if (did != null) {
      _upsertDevice(did, {'status': 'online', 'short_id': short});
    }
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
      // merge optional fields
      if (patch.containsKey('short_id') && patch['short_id'] != null) {
        cur['short_id'] = patch['short_id'];
      }
      if (patch.containsKey('name') && patch['name'] != null) {
        cur['name'] = patch['name'];
      }
      _devices[deviceId] = cur;
    });

    // If we don't have a short_id yet, fetch it (once).
    final curEntry = _devices[deviceId]!;
    if ((curEntry['short_id'] == null || (curEntry['short_id'] as String).isEmpty) && !_fetching.contains(deviceId)) {
      _fetching.add(deviceId);
      fetchShortId(deviceId).then((short) {
        setState(() {
          final e = _devices[deviceId] ?? {'device_id': deviceId};
          if (short != null) e['short_id'] = short;
          _devices[deviceId] = e;
        });
      }).whenComplete(() {
        _fetching.remove(deviceId);
      });
    }
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
        return DeviceCard(
          device: info,
          onPing: () async {
            final session = getSessionId();
            final msgId = make_id();
            final msgMap = buildPing(
              deviceId: id,
              senderId: 'ui',
              sessionId: session,
              messageId: msgId,
            );
            final msg = jsonEncode(msgMap);
            Publish('cum/command/core', msg, qos: MqttQos.atLeastOnce);

            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ping sent to $id')));

            try {
              final reply = await incomingHandler.waitForId(
                msgId,
                timeout: const Duration(seconds: 5),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Pong received from ${reply['sender_id'] ?? 'device'}')),
              );
            } catch (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No pong (timeout) from $id')),
              );
            }
          },
          onMessage: () {
            // TODO: open quick message dialog for device
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Message action for $id')));
          },
        );
      },
    );
  }

  String _buildSubtitle(Map<String, dynamic> info) {
    final status = info['status'] as String? ?? 'unknown';
    final last = info['last_seen'] as DateTime?;
    final short = info['short_id'] as String?;
    final name = info['name'] as String?;
    final shortDisplay = short != null && short.isNotEmpty
        ? 'Short: $short'
        : (_fetching.contains(info['device_id']) ? 'Short: loading...' : 'Short: —');
    final nameDisplay = name != null ? '$name • ' : '';
    return '$nameDisplay$status • Last: ${_formatTime(last)} • $shortDisplay';
  }
}
