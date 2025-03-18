import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// MAXIME
import 'smart_home_screen.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Initialiser les plugins Flutter
  runApp(const SmartHomeApp());
// MAXIME2.0
import 'package:http/http.dart' as http;
import 'package:typed_data/src/typed_buffer.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'widgets/device_card.dart';
import 'widgets/category_tab.dart';
import 'login_page.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'widgets/light_device_card.dart';
import 'widgets/radiator_device_card.dart';
import 'package:firebase_core/firebase_core.dart';
//END

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("❌ Erreur lors de l'initialisation de Firebase : $e");
  }
  runApp(SmartHomeApp());
}


class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Home App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      home: SmartHomeScreen(),
    );
  }
}

class SmartHomeScreen extends StatefulWidget {
  @override
  _SmartHomeScreenState createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  String selectedCategory = "Salon";
  double heaterTemperature = 22.0;

  Map<String, List<Map<String, dynamic>>> roomDevices = {};
  Map<String, String> roomNames = {}; // Associer ID -> Nom
  Map<String, List<Map<String, dynamic>>> sensorsByRoom = {};
  late MqttServerClient client;

  void listenForNewSensors() {
    FirebaseFirestore.instance.collection('sensors').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var newSensor = change.doc.data();
          if (newSensor != null) {
            String? roomId = newSensor['roomId'];
            if (roomId == null || roomId.isEmpty) {
              print("⚠️ Capteur détecté sans roomId valide : ${newSensor['name']}");
              return; // Évite d'ajouter un capteur sans roomId
            }

            setState(() {
              sensorsByRoom.putIfAbsent(roomId, () => []);
              sensorsByRoom[roomId]!.add(newSensor);
            });

            // ✅ Vérifie si le nom de la room existe avant d'afficher
            String roomName = roomNames[roomId] ?? "Room inconnue";
            print("🆕 Nouveau capteur détecté : ${newSensor['name']} ajouté à la room $roomName");
          }
        }
      }
    });
  }

  Future<void> connectToMqtt() async {
    client = MqttServerClient(
        '46eccffd0ebc4eb8b5a2ef13663c1c28.s1.eu.hivemq.cloud', ''
    );
    client.port = 8883;
    client.secure = true;
    client.logging(on: false);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .authenticateAs('Ynov-2025', 'Ynov-2025')
        .startClean();

    client.connectionMessage = connMessage;

    try {
      await client.connect();
      print('✅ MQTT Connected');
      fetchInitialSensorValues(); // Exécute directement sans délai
    } catch (e) {
      print('❌ MQTT Connection failed: $e');
      return;
    }

    client.subscribe('#', MqttQos.atMostOnce); // Abonnement à tous les topics

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final recMessage = messages[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);
      print('📩 MQTT Message reçu: ${messages[0].topic} -> $payload');

      try {
        final sensorData = jsonDecode(payload);
        updateSensorData(sensorData);
      } catch (e) {
        print("⚠️ Ignoré : Message non JSON reçu sur MQTT -> $payload");
      }
    });
  }

  Future<void> fetchInitialSensorValues() async {
    var url = Uri.parse('http://localhost:3000/sensors');
    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> sensorsData = jsonDecode(response.body);
        setState(() {
          sensorsByRoom.clear();
          for (var sensor in sensorsData) {
            String roomId = sensor['roomId'];
            if (!sensorsByRoom.containsKey(roomId)) {
              sensorsByRoom[roomId] = [];
            }
            sensorsByRoom[roomId]!.add(sensor);
          }
        });
        print("✅ Valeurs initiales des capteurs chargées depuis l'API");
      } else {
        print("❌ Erreur lors de la récupération des capteurs : ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Erreur réseau : $e");
    }
  }

  Future<void> fetchRooms() async {
    var url = Uri.parse('http://localhost:3000/rooms');
    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> roomsData = jsonDecode(response.body);
        setState(() {
          roomDevices.clear();
          roomNames.clear();
          Set<String> addedRooms = {}; // Ajout d'un Set pour éviter les doublons

          for (var room in roomsData) {
            if (!addedRooms.contains(room['id'])) {
              roomDevices[room['id']] = [];
              roomNames[room['id']] = room['name'];
              addedRooms.add(room['id']); // Marque la room comme ajoutée
            }
          }

          if (roomDevices.isNotEmpty) {
            selectedCategory = roomNames.isNotEmpty ? roomNames.values.first : "UnknownRoom";
          }
        });
      } else {
        print("Erreur lors de la récupération des rooms : ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur réseau : $e");
    }
  }

  Future<void> fetchSensors() async {
    var url = Uri.parse('http://localhost:3000/sensors');
    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> sensorsData = jsonDecode(response.body);
        setState(() {
          sensorsByRoom.clear();
          for (var sensor in sensorsData) {
            String roomId = sensor['roomId'];
            if (!sensorsByRoom.containsKey(roomId)) {
              sensorsByRoom[roomId] = [];
            }
            sensorsByRoom[roomId]!.add(sensor);
          }
        });
      } else {
        print("Erreur lors de la récupération des capteurs : ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur réseau : $e");
    }
  }

  void updateSensorData(Map<String, dynamic> sensorData) {
    String sensorId = sensorData['sensorId'];

    setState(() {
      sensorsByRoom.forEach((roomId, sensors) {
        for (var sensor in sensors) {
          if (sensor['id'] == sensorId) {
            sensor['value'] = double.tryParse(sensorData['value'].toString()) ?? 0.0; // ✅ Correction ici
            sensor['unit'] = sensorData.containsKey('unit') ? sensorData['unit'] : '';
          }
        }
      });
    });

    // Enregistrer en base de données
    updateSensorInDatabase(sensorData);
  }

  Future<void> updateSensorInDatabase(Map<String, dynamic> sensorData) async {
    var url = Uri.parse('http://localhost:3000/sensors/${sensorData['sensorId']}');

    try {
      var response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "value": sensorData['value'],
          "unit": sensorData.containsKey('unit') ? sensorData['unit'] : ""
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Valeur du capteur ${sensorData['sensorId']} mise à jour dans la base");
      } else {
        print("❌ Erreur mise à jour capteur ${sensorData['sensorId']} : ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Erreur réseau lors de la mise à jour du capteur : $e");
    }
  }

Future<void> updateRoomTemperature(double value) async {
  try {
    // Mettre à jour la température dans la base de données via l'API backend NestJS
    var url = Uri.parse('http://localhost:3000/rooms/$selectedCategory');
    try {
      var response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"temperature": value}),
      );
      if (response.statusCode == 200) {
        print("✅ Température de la room $selectedCategory mise à jour dans la base");
        final roomPayload = utf8.encode(jsonEncode({
          "roomId": selectedCategory,
          "temperature": value
        }));

        String roomName = roomNames[selectedCategory] ?? "UnknownRoom";
        client.publishMessage(
            "$roomName/temperature", // Respecte le format demandé
            MqttQos.atLeastOnce,
            Uint8Buffer()..addAll(Uint8List.fromList(utf8.encode(jsonEncode({
              "roomName": roomName,
              "sensorName": "room",
              "type": "temperature",
              "value": value
            }))))
        );

        print("📩 MQTT Message envoyé: $selectedCategory/temperature -> $value");

        // Mettre à jour la température de tous les radiateurs dans la pièce
        if (sensorsByRoom.containsKey(selectedCategory)) {
          for (var sensor in sensorsByRoom[selectedCategory]!) {
            if (sensor["type"] == "radiator") {
              String radiatorId = sensor["id"];

              // Mise à jour via API backend NestJS
              var sensorUrl = Uri.parse('http://localhost:3000/sensors/$radiatorId');
              var sensorResponse = await http.put(
                sensorUrl,
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"value": value}),
              );
              if (sensorResponse.statusCode == 200) {
                print("✅ Température du radiateur $radiatorId mise à jour dans la base");
              } else {
                print("❌ Erreur mise à jour radiateur $radiatorId : ${sensorResponse.statusCode}");
              }

              // Envoyer via MQTT
              final payload = utf8.encode(jsonEncode({
                "sensorId": radiatorId,
                "roomId": selectedCategory,
                "temperature": value
              }));

              String roomName = roomNames[selectedCategory] ?? "UnknownRoom";
              client.publishMessage(
                  "$roomName/$radiatorId/temperature",
                  MqttQos.atLeastOnce,
                  Uint8Buffer()..addAll(Uint8List.fromList(utf8.encode(jsonEncode({
                    "roomName": roomName,
                    "sensorName": radiatorId,
                    "type": "temperature",
                    "value": value
                  }))))
              );

              print("📩 MQTT Message envoyé:$selectedCategory/$radiatorId/temperature -> $value");
            }
          }
        }
      } else {
        print("❌ Erreur lors de la mise à jour de la température de la room: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Erreur réseau lors de la mise à jour de la température: $e");
    }

    // Mettre à jour la température de tous les radiateurs dans la pièce
    if (sensorsByRoom.containsKey(selectedCategory)) {
      for (var sensor in sensorsByRoom[selectedCategory]!) {
        if (sensor["type"] == "radiator") {
          String radiatorId = sensor["id"];

          // Mise à jour via API backend NestJS
          var sensorUrl = Uri.parse('http://localhost:3000/sensors/$radiatorId');
          var sensorResponse = await http.put(
            sensorUrl,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"value": value}),
          );
          if (sensorResponse.statusCode == 200) {
            print("✅ Température du radiateur $radiatorId mise à jour dans la base");
          } else {
            print("❌ Erreur mise à jour radiateur $radiatorId : ${sensorResponse.statusCode}");
          }

          // Envoyer via MQTT
          final payload = utf8.encode(jsonEncode({
            "sensorId": radiatorId,
            "roomId": selectedCategory,
            "temperature": value
          }));

          client.publishMessage(
            "$selectedCategory/radiator/temperature",
            MqttQos.atLeastOnce,
            Uint8Buffer()..addAll(Uint8List.fromList(payload))
          );

          print("📩 MQTT Message envoyé: $selectedCategory/radiator/temperature -> $value");
        }
      }
    }
  } catch (e) {
    print("❌ Erreur lors de la mise à jour de la température: $e");
  }
}

  @override
  void initState() {
    super.initState();
    fetchRooms().then((_) {
      fetchSensors().then((_) {
        listenForNewSensors(); // 🔥 Maintenant, ça s'exécute après le chargement initial des sensors
        // ✅ S'assurer que `selectedCategory` a un nom valide
        if (roomNames.containsValue("Salon")) {
          setState(() {
            selectedCategory = roomNames.entries.firstWhere((entry) => entry.value == "Salon", orElse: () => MapEntry("", "Salon")).key;
          });
        } else if (roomNames.isNotEmpty) {
          setState(() {
            selectedCategory = roomNames.keys.first;
          });
        } else {
          setState(() {
            selectedCategory = "UnknownRoom"; // Valeur par défaut si aucune pièce n'est trouvée
          });
        }
      });
    });
    connectToMqtt();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey[100],
        title: const Text(
          "Hi Arpan",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: roomDevices.keys.map((roomId) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              selectedCategory = roomId; // Toujours utiliser l'ID pour les sensors
                            }),
                            child: CategoryTab(
                              title: roomNames[roomId] ?? "Unknown", // Affiche le nom de la room
                              isActive: selectedCategory == roomId,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: sensorsByRoom.containsKey(selectedCategory)
                          ? sensorsByRoom[selectedCategory]!.map((sensor) {
                      if (sensor["type"] == "light") {
                          return LightDeviceCard(
                            sensor["id"],
                            sensor["name"],
                            sensor["value"] == 1,
                            Colors.yellow,
                            (newValue) {
                              setState(() {
                                sensor["value"] = newValue ? 1 : 0;
                              });
                            },
                            client,
                            sensor["topic"]
                          );
                        } else if (sensor["type"] == "radiator") {
                        return RadiatorDeviceCard(
                            sensor["topic"],
                            sensor["name"],
                            double.tryParse(sensor["value"].toString()) ?? 20.0,  // ✅ Correction ici
                            sensor["status"] == 1,
                            Colors.redAccent,
                            (newValue) {
                              setState(() {
                                sensor["status"] = newValue ? 1 : 0;
                              });
                            },
                            client
                          );
                        } else {
                          return DeviceCard(
                            sensor["name"],
                            sensor["type"],
                            true,
                            Icons.sensors,
                            Colors.blue,
                            sensor.containsKey("unit") && sensor["unit"] != null
                                ? "${double.tryParse(sensor["value"].toString()) ?? 0} ${sensor["unit"].toString().replaceAll("Â", "").trim()}"
                                : "${double.tryParse(sensor["value"].toString()) ?? 0}", // ✅ Correction ici
                          );
                        }
                      }).toList()
                          : [Center(child: Text("Aucun capteur disponible"))],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (sensorsByRoom[selectedCategory]?.any((sensor) => sensor["type"] == "radiator") ?? false)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Column(
                children: [
                  const Text("Adjust Heater Temperature", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Slider(
                    value: heaterTemperature,
                    min: 16,
                    max: 30,
                    divisions: 14,
                    label: heaterTemperature.round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        heaterTemperature = value;
                      });
                      updateRoomTemperature(value);
                    },
                  ),
                  Text("${heaterTemperature.round()}°C", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.home, size: 30), onPressed: () {}),
            const SizedBox(width: 20),
            FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.mic, size: 28),
              backgroundColor: Colors.white,
              elevation: 5,
            ),
            const SizedBox(width: 20),
            IconButton(
              icon: const Icon(Icons.person, size: 30),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
          ],
        ),
      ),
      home: SmartHomeScreen(),
    );
  }
}
