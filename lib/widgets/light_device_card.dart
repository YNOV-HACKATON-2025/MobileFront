import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class LightDeviceCard extends StatelessWidget {
  final String sensorId;
  final String title;
  final bool status;
  final Color color;
  final Function(bool) onToggle;
  final MqttServerClient client;
  final String topic; // Remplace roomName par topic

  LightDeviceCard(this.sensorId, this.title, this.status, this.color, this.onToggle, this.client, this.topic);

  void handleToggle(bool value) {
    onToggle(value);
    sendMqttUpdate(value);
    updateDatabase(value);
  }

  void sendMqttUpdate(bool value) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode({
      "sensorId": sensorId,
      "value": value ? 1 : 0
    }));
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!); // Utilise topic au lieu de roomName/$title
  }

  Future<void> updateDatabase(bool value) async {
    var url = Uri.parse('http://localhost:3000/sensors/$sensorId');
    try {
      var response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"value": value ? 1 : 0}),
      );

      if (response.statusCode == 200) {
        print("✅ Valeur du capteur $sensorId mise à jour dans la base");
      } else {
        print("❌ Erreur mise à jour capteur $sensorId : ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Erreur réseau lors de la mise à jour du capteur : $e");
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
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
          Text(status ? 'Allumé' : 'Éteint', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
