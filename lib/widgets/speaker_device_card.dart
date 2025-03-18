import 'package:flutter/material.dart';

class SpeakerDeviceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool status;
  final Color color;
  final String? sensorValue;

  SpeakerDeviceCard(this.title, this.status, this.color, this.subtitle, [this.sensorValue]);

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
          Icon(Icons.speaker, size: 40, color: status ? color : Colors.grey),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Enceinte", style: TextStyle(color: Colors.grey)),
          if (sensorValue != null)
            Text(sensorValue ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }
}
