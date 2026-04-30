import 'dart:async';
import 'dart:convert';
import 'mqtt_client.dart';

typedef MsgMap = Map<String, dynamic>;
typedef MsgHandler = void Function(MsgMap msg);

class IncomingHandler {
  late final StreamSubscription<Map<String, String>> _sub;
  final Map<String, Completer<MsgMap>> _waitingById = {};
  final Map<String, List<MsgHandler>> _handlersByAction = {};
  final List<MsgHandler> _globalHandlers = [];

  IncomingHandler() {
    _sub = mqttMessageStream.listen(_onMessageRaw, onError: (_) {});
  }

  void dispose() {
    try {
      _sub.cancel();
    } catch (_) {}
    for (final c in _waitingById.values) {
      if (!c.isCompleted) c.completeError('Handler disposed');
    }
    _waitingById.clear();
    _handlersByAction.clear();
    _globalHandlers.clear();
  }

  Future<MsgMap> waitForId(String id, {Duration timeout = const Duration(seconds: 5)}) {
    final comp = Completer<MsgMap>();
    _waitingById[id] = comp;
    return comp.future.timeout(timeout, onTimeout: () {
      _waitingById.remove(id);
      throw TimeoutException('timeout waiting for message with id $id');
    });
  }

  void onAction(String actionOrEvent, MsgHandler handler) {
    _handlersByAction.putIfAbsent(actionOrEvent, () => []).add(handler);
  }

  void offAction(String actionOrEvent, MsgHandler handler) {
    final list = _handlersByAction[actionOrEvent];
    list?.remove(handler);
    if (list != null && list.isEmpty) _handlersByAction.remove(actionOrEvent);
  }

  void addGlobalHandler(MsgHandler handler) => _globalHandlers.add(handler);
  void removeGlobalHandler(MsgHandler handler) => _globalHandlers.remove(handler);

  void _onMessageRaw(Map<String, String> raw) {
    final payload = raw['payload'];
    if (payload == null || payload.isEmpty) return;
    MsgMap doc;
    try {
      doc = jsonDecode(payload) as MsgMap;
    } catch (_) {
      return;
    }

    // notify global handlers
    for (final h in List<MsgHandler>.from(_globalHandlers)) {
      try {
        h(doc);
      } catch (_) {}
    }

    // complete waiters by id
    final msgId = doc['id'] as String?;
    if (msgId != null && _waitingById.containsKey(msgId)) {
      // ignore local echoes: if the incoming message comes from this client
      // (same device/client id), don't complete the waiter as it's our own publish
      final sender = doc['sender_id'] as String?;
      try {
        final myId = getDeviceId();
        if (sender != null && myId != null && sender == myId) {
          // skip completing waiters for our own message
        } else {
          final c = _waitingById.remove(msgId);
          if (c != null && !c.isCompleted) c.complete(doc);
        }
      } catch (_) {
        final c = _waitingById.remove(msgId);
        if (c != null && !c.isCompleted) c.complete(doc);
      }
    }

    // dispatch by action or event names
    final type = doc['type'] as String?;
    if (type == 'command') {
      final action = doc['action'] as String?;
      if (action != null) {
        final handlers = _handlersByAction[action];
        if (handlers != null) {
          for (final h in List<MsgHandler>.from(handlers)) {
            try {
              h(doc);
            } catch (_) {}
          }
        }
      }
    } else if (type == 'event') {
      final event = doc['event'] as String?;
      if (event != null) {
        final handlers = _handlersByAction[event];
        if (handlers != null) {
          for (final h in List<MsgHandler>.from(handlers)) {
            try {
              h(doc);
            } catch (_) {}
          }
        }
      }
    }
  }
}

// Top-level singleton instance for easy sharing across widgets
final incomingHandler = IncomingHandler();