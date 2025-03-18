import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class RadiatorDeviceCard extends StatelessWidget {
  final String topic;
  final String title;
  final double temperature;
  final bool status;
  final Color color;
  final Function(bool) onToggle;
  final MqttServerClient client;
  final String radiatorId;

  RadiatorDeviceCard(
      this.topic, this.title, this.temperature, this.status, this.color, this.onToggle, this.client, this.radiatorId);

  void handleToggle(bool value) {
    onToggle(value);
    sendMqttUpdate(value);
    updateDatabase(value);
  }

  void sendMqttUpdate(bool value) {
    final payload = jsonEncode({
      "sensorId": radiatorId,
      "value": value ? 1 : 0
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  Future<void> updateDatabase(bool value) async {
    var url = Uri.parse('https://hackathon.vanhovev.com/sensors/${radiatorId}');
    try {
      var response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"value": value ? 1 : 0}),
      );

      if (response.statusCode == 200) {
        print("Radiateur de la pièce $topic mis à jour dans la base");
      } else {
        print("Erreur mise à jour radiateur $radiatorId : ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur réseau lors de la mise à jour du radiateur : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: status ? color.withOpacity(0.2) : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Icon(Icons.fireplace, size: 30, color: Colors.orange),
              const SizedBox(height: 4),
              const Text("Chauffage", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              Text("${temperature.toStringAsFixed(1)}°C", style: const TextStyle(fontSize: 16)),
            ],
          ),
          FlutterSwitch(
            width: 50,
            height: 25,
            toggleSize: 20,
            value: status,
            borderRadius: 15,
            activeColor: Colors.orange,
            inactiveColor: Colors.grey,
            onToggle: handleToggle,
          ),
        ],
      ),
    );
  }
}