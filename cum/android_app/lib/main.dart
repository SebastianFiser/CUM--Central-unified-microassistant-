import 'dart:async';
import 'package:flutter/material.dart';
import 'controller.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'mqtt_client.dart';
import 'dart:convert';
import 'screens/FancyA.dart';
import 'screens/FancyB.dart';

var uuid = Uuid();
String device_id = 'flutter_device_${make_id()}';
late String SenderID;

String make_id() {
  return uuid.v4();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  // generate sender/client id now that bindings are initialized
  SenderID = generateSenderId(device_id);
  runApp(const MyApp());
  connectAndRegister(device_id, senderId: SenderID);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CUM Flutter App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    ChannelFeed(), //0
    ConsoleScreen(), //1
    FancyA(), //2
    FancyB(), //3
  ];
  void _onTap(int idx) => setState(() => _selectedIndex = idx);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ['Channel', 'Console', 'Fancy A', 'Fancy B'][_selectedIndex],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: 'Channel'),
          BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Console'),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone_android),
            label: 'Fancy A',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone_iphone),
            label: 'Fancy B',
          ),
        ],
      ),
    );
  }
}

class ChannelFeed extends StatefulWidget {
  @override
  _ChannelFeedState createState() => _ChannelFeedState();
}

class _ChannelFeedState extends State<ChannelFeed> {
  final List<Map<String, String>> _msg = [];
  StreamSubscription<Map<String, String>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = mqttMessageStream.listen((m) {
      setState(() => _msg.insert(0, m));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _msg.length,
      itemBuilder: (_, i) {
        final m = _msg[i];
        return ListTile(
          title: Text(m['topic'] ?? 'No topic'),
          subtitle: Text(m['payload'] ?? 'No payload'),
        );
      },
    );
  }
}

class ConsoleScreen extends StatefulWidget {
  @override
  _ConsoleScreenState createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final List<String> _history = [];

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final payload = jsonEncode({
      'id': make_id(),
      'sender_id': SenderID,
      'session_id': make_id(),
      'type': 'command',
      'action': 'echo',
      'payload': {'message': text},
    });
    Publish('cum/command/core', payload);
    setState(() {
      _history.insert(0, '> $text');
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext ctx) => Column(
    children: [
      Expanded(
        child: ListView.builder(
          itemCount: _history.length,
          itemBuilder: (_, i) => ListTile(title: Text(_history[i])),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Enter command',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(onPressed: _send, child: Text('Send')),
          ],
        ),
      ),
    ],
  );
}

class FancyA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Fancy A (placeholder)'));
  }
}

class FancyB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Fancy B (placeholder)'));
  }
}
