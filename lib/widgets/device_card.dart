import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';

class DeviceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool status;
  final IconData icon;
  final Color color;
  final String? sensorValue;

  DeviceCard(this.title, this.subtitle, this.status, this.icon, this.color, [this.sensorValue]);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: status ? color.withOpacity(0.2) : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 40, color: status ? color : Colors.grey),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
          if (sensorValue != null)
            Text(sensorValue ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }
}
