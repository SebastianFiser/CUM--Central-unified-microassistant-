import 'dart:async';
import 'package:flutter/material.dart';
import 'controller.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'mqtt_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dart:convert';
import 'message_builder.dart';
import 'screens/FancyA.dart';
import 'screens/FancyB.dart';
import 'screens/deviceList.dart';
import 'incoming_handler.dart';
import 'widgets/console_screen.dart';

var uuid = const Uuid();
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
  // connect and register in background
  connectAndRegister(device_id, senderId: SenderID);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CUM Flutter App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.blue[50],
          selectedItemColor: Colors.blue[800],
          unselectedItemColor: Colors.blue[300],
          selectedIconTheme: IconThemeData(size: 24, color: Colors.blue[800]),
          unselectedIconTheme: IconThemeData(size: 20, color: Colors.blue[300]),
          selectedLabelStyle: TextStyle(color: Colors.blue[800], fontSize: 12),
          unselectedLabelStyle: TextStyle(
            color: Colors.blue[300],
            fontSize: 10,
          ),
        ),
      ),
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
    ChannelFeed(), //0 For all msgs in channel
    ConsoleScreen(), //1 for sending comms manually
    FancyA(), //2 future app design
    FancyB(), //3 -||-
    DeviceList(), //4 list of devices and button shortcuts
  ];
  void _onTap(int idx) => setState(() => _selectedIndex = idx);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            'Channel',
            'Console',
            'Fancy A',
            'Fancy B',
            'Devices',
          ][_selectedIndex],
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
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
          BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Devices'),
        ],
      ),
    );
  }
}

class ChannelFeed extends StatefulWidget {
  const ChannelFeed({super.key});

  @override
  _ChannelFeedState createState() => _ChannelFeedState();
}

class _ChannelFeedState extends State<ChannelFeed>
    with AutomaticKeepAliveClientMixin<ChannelFeed> {
  final List<Map<String, String>> _msg = [];
  MsgHandler? _feedHandler;

  @override
  void initState() {
    super.initState();
    _feedHandler = (m) {
      final topic = m['topic'] ?? 'cum';
      final payload = m['payload'] ?? jsonEncode(m);
      setState(() => _msg.insert(0, {'topic': topic, 'payload': payload}));
    };
    incomingHandler.addGlobalHandler(_feedHandler!);
  }

  @override
  void dispose() {
    if (_feedHandler != null)
      incomingHandler.removeGlobalHandler(_feedHandler!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin
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

  @override
  bool get wantKeepAlive => true;
}

// ConsoleScreen moved to widgets/console_screen.dart

class FancyA extends StatelessWidget {
  const FancyA({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Fancy A (placeholder)'));
  }
}

class FancyB extends StatelessWidget {
  const FancyB({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Fancy B (placeholder)'));
  }
}
//working 24/7 hire me please i need money to buy a new pc and a new phone and also food and also maybe a car so i can drive to work and also pay for my internet so i can keep working and also maybe a house so i can live there and not be homeless and also maybe some clothes so i can wear them to work and also maybe a bed so i can sleep well and wake up refreshed for work and also maybe some healthcare so i can stay healthy and not get sick and miss work and also maybe some entertainment so i can relax after work and not get burned out and also maybe some savings so i can have a safety net in case of emergencies and also maybe some education so i can keep learning new skills and advance in my career and also maybe some travel so i can explore new places and cultures and broaden my horizons.