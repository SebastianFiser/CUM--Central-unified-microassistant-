import 'package:flutter/material.dart';

class DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final VoidCallback? onPing;
  final VoidCallback? onMessage;

  const DeviceCard({
    Key? key,
    required this.device,
    this.onPing,
    this.onMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final online = device['status'] == 'online';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: online
              ? Colors.green.shade400
              : Colors.grey.shade400,
          child: Text(
            device['name']?.isNotEmpty == true
                ? device['name'][0].toUpperCase()
                : '?',
          ),
        ),
        title: Text(device['name'] ?? device['device_id'] ?? 'Unknown'),
        subtitle: Row(
          children: [
            if (device['short_id'] != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  device['short_id'],
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            Text(
              online ? 'Online' : 'Offline',
              style: TextStyle(color: online ? Colors.green : Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.wifi_tethering, color: Colors.blue),
              onPressed: onPing,
            ),
            IconButton(
              icon: Icon(Icons.message, color: Colors.teal),
              onPressed: onMessage,
            ),
          ],
        ),
        onTap: () {
          final short = device['short_id'] ?? '—';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Short id: $short')));
        },
      ),
    );
  }
}
