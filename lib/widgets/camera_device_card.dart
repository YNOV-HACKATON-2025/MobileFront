import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class CameraDeviceCard extends StatelessWidget {
  final String sensorId;
  final String title;
  final bool status;
  final Color color;
  final Function(bool) onToggle;
  final MqttServerClient client;
  final String topic;

  CameraDeviceCard(this.sensorId, this.title, this.status, this.color, this.onToggle, this.client, this.topic);

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
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  Future<void> updateDatabase(bool value) async {
    var url = Uri.parse('https://hackathon.vanhovev.com/sensors/$sensorId');
    try {
      var response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"value": value ? 1 : 0}),
      );

      if (response.statusCode == 200) {
        print("Valeur de la caméra $sensorId mise à jour dans la base");
      } else {
        print("Erreur mise à jour caméra $sensorId : ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur réseau lors de la mise à jour de la caméra : $e");
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
          Icon(Icons.videocam, size: 40, color: status ? color : Colors.grey),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Caméra", style: TextStyle(color: Colors.grey)),
          const Spacer(),
          FlutterSwitch(
            width: 50,
            height: 25,
            toggleSize: 20,
            value: status,
            borderRadius: 15,
            activeColor: Colors.green,
            inactiveColor: Colors.grey,
            onToggle: handleToggle,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              status ? 'Allumé' : 'Éteint',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}