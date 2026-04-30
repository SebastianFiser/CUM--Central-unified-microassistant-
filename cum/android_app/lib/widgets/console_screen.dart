import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../incoming_handler.dart';
import '../mqtt_client.dart';

class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({Key? key}) : super(key: key);
  @override
  _ConsoleScreenState createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  final TextEditingController _ctl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, dynamic>> _history = [];

  String _makeId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _addHistory(String type, String text, {String? id}) {
    setState(() => _history.insert(0, {'type': type, 'text': text, 'id': id}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(
          0,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
    });
  }

  Future<void> _send(String line) async {
    final id = _makeId();
    _addHistory('sent', '> $line', id: id);
    _addHistory('pending', '… waiting for reply (id=$id)', id: id);

    final msg = {
      'id': id,
      'sender_id': 'flutter',
      'type': 'command',
      'action': 'console_exec',
      'payload': {'text': line},
    };

    try {
      // TODO: replace with your publish helper
      Publish('cum/command/core', jsonEncode(msg), qos: MqttQos.atLeastOnce);

      // wait for reply using incomingHandler.waitForId if available
      final reply = await incomingHandler.waitForId(
        id,
        timeout: const Duration(seconds: 5),
      );
      final resp =
          (reply['payload'] as Map?)?['text'] ??
          jsonEncode(reply['payload'] ?? {});
      setState(() {
        _history.removeWhere((h) => h['type'] == 'pending' && h['id'] == id);
        _history.insert(0, {'type': 'recv', 'text': '< $resp', 'id': id});
      });
    } catch (e) {
      setState(() {
        _history.removeWhere((h) => h['type'] == 'pending' && h['id'] == id);
        _history.insert(0, {
          'type': 'err',
          'text': '< No reply (timeout/error): $e',
          'id': id,
        });
      });
    }
  }

  Color _colorForType(String t) {
    switch (t) {
      case 'sent':
        return Colors.blue.shade700;
      case 'recv':
        return Colors.green.shade700;
      case 'pending':
        return Colors.orange.shade700;
      case 'err':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            reverse: true,
            itemCount: _history.length,
            itemBuilder: (ctx, i) {
              final item = _history[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: _colorForType(item['type']),
                  radius: 12,
                ),
                title: Text(
                  item['text'],
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              );
            },
          ),
        ),
        Divider(height: 1),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (v) {
                      if (v.trim().isEmpty) return;
                      _send(v.trim());
                      _ctl.clear();
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Enter command (e.g. ping 6UT9, msg 6UT9 hello)',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    final text = _ctl.text.trim();
                    if (text.isEmpty) return;
                    _send(text);
                    _ctl.clear();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
