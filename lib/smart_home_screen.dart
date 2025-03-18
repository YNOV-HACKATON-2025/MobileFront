import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:typed_data/src/typed_buffer.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'widgets/device_card.dart';
import 'widgets/speaker_device_card.dart';
import 'widgets/category_tab.dart';
import 'login_page.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'widgets/light_device_card.dart';
import 'widgets/radiator_device_card.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import 'widgets/camera_device_card.dart';
import 'widgets/fan_device_card.dart';

void main() {
  runApp(SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  String _transcription = "Appuyez sur le micro pour parler...";

  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _filePath;

  Map<String, List<Map<String, dynamic>>> roomDevices = {};
  Map<String, String> roomNames = {}; // Associer ID -> Nom
  Map<String, String> roomTopics = {}; // Associer ID -> Topic
  Map<String, List<Map<String, dynamic>>> sensorsByRoom = {};
  Map<String, double> roomTemperatures = {};
  late MqttServerClient client;


  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initRecorder();
    fetchRooms().then((_) {
      fetchSensors().then((_) {
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

  void listenForNewSensors() {
    FirebaseFirestore.instance.collection('sensors').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var newSensor = change.doc.data();
          if (newSensor != null) {
            String? roomId = newSensor['roomId'];
            if (roomId == null || roomId.isEmpty) {
              print("Capteur détecté sans roomId valide : ${newSensor['name'] ?? "Inconnu"}");
              continue;
            }

            setState(() {
              sensorsByRoom.putIfAbsent(roomId, () => []);
              sensorsByRoom[roomId]!.add({
                "id": newSensor["id"] ?? "unknown_id",
                "name": newSensor["name"] ?? "Capteur inconnu",
                "type": newSensor["type"] ?? "unknown",
                "value": newSensor["value"] ?? 20.0,
                "unit": newSensor["unit"] ?? "",
                "roomId": roomId,
              });
            });

            String roomName = roomNames[roomId] ?? "Room inconnue";
            print("Nouveau capteur détecté : ${newSensor['name'] ?? "Inconnu"} ajouté à la room $roomName");
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
      print('MQTT Connected');
      fetchInitialSensorValues();
    } catch (e) {
      print('MQTT Connection failed: $e');
      return;
    }

    client.subscribe('#', MqttQos.atMostOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final recMessage = messages[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);
      print('MQTT Message reçu: ${messages[0].topic} -> $payload');

      try {
        final sensorData = jsonDecode(payload);
        updateSensorData(sensorData);
      } catch (e) {
        print("Ignoré : Message non JSON reçu sur MQTT -> $payload");
      }
    });
  }

  Future<void> fetchInitialSensorValues() async {
    var url = Uri.parse('https://hackathon.vanhovev.com/sensors');
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
        print("Valeurs initiales des capteurs chargées depuis l'API");
      } else {
        print("Erreur lors de la récupération des capteurs : ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur réseau : $e");
    }
  }

  Future<void> fetchRooms() async {
    var url = Uri.parse('https://hackathon.vanhovev.com/rooms');
    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> roomsData = jsonDecode(response.body);
        setState(() {
          roomDevices.clear();
          roomNames.clear();
          roomTemperatures.clear();
          Set<String> addedRooms = {};

          for (var room in roomsData) {
            if (!addedRooms.contains(room['id'])) {
              roomDevices[room['id']] = [];
            roomNames[room['id']] = room['name'];
            roomTopics[room['id']] = room['topic'] ?? "default_topic";
              addedRooms.add(room['id']);

              double roomTemp = double.tryParse(room["temperature"].toString()) ?? 20.0;
              roomTemperatures[room['id']] = roomTemp;
            }
          }

          if (roomDevices.isNotEmpty) {
            selectedCategory = roomNames.isNotEmpty ? roomNames.keys.first : "UnknownRoom";
          }

          // Assigne la température correcte pour la pièce sélectionnée
          heaterTemperature = roomTemperatures[selectedCategory] ?? 20.0;
        });
      } else {
        print("Erreur lors de la récupération des rooms : ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur réseau : $e");
    }
  }

  Future<void> fetchSensors() async {
    var url = Uri.parse('https://hackathon.vanhovev.com/sensors');
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
            if (sensor["type"] == "radiator") {
              if (sensorData.containsKey("temperature")) {
                sensor["temperature"] = double.tryParse(sensorData["temperature"].toString()) ?? 20.0;
              }
              if (sensorData.containsKey("value")) {
                sensor["status"] = sensorData["value"] == 1; // ✅ Toujours booléen !
              }
            } else {
              sensor["value"] = double.tryParse(sensorData["value"].toString()) ?? 0.0;
            }
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
    var url = Uri.parse('https://hackathon.vanhovev.com/sensors/${sensorData['sensorId']}');

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
        print("Valeur du capteur ${sensorData['sensorId']} mise à jour dans la base");
      } else {
        print("Erreur mise à jour capteur ${sensorData['sensorId']} : ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur réseau lors de la mise à jour du capteur : $e");
    }
  }

  Future<void> updateRoomTemperature(double value) async {
    setState(() {
      heaterTemperature = value;
      roomTemperatures[selectedCategory] = value;
    });

    var url = Uri.parse('https://hackathon.vanhovev.com/rooms/$selectedCategory');
    try {
      var response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"temperature": value}),
      );

      if (response.statusCode == 200) {
        print("Température de la room $selectedCategory mise à jour dans la base");
        final builder = MqttClientPayloadBuilder();
        builder.addString(jsonEncode({
          "roomId": selectedCategory,
          "temperature": value
        }));
        client.publishMessage(
          "${roomTopics[selectedCategory]}/temperature",
          MqttQos.atLeastOnce,
          builder.payload!
        );
        print("MQTT Message envoyé: $selectedCategory/temperature -> $value");
      } else {
        print("Erreur lors de la mise à jour de la température de la room: ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur réseau lors de la mise à jour de la température: $e");
    }
  }

  Future<void> _initRecorder() async {
    await _recorder!.openRecorder();
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _startRecording() async {
    if (!await Permission.microphone.isGranted) {
      await Permission.microphone.request();
    }

    Directory tempDir = await getTemporaryDirectory();
    _filePath = '${tempDir.path}/recording.m4a';

    await _recorder!.startRecorder(toFile: _filePath, codec: Codec.aacMP4);
    setState(() => _isRecording = true);
  }


  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    setState(() => _isRecording = false);
    print("✅ Enregistrement terminé : $_filePath");

    if (_filePath != null) {

      await Future.wait([
        _uploadAudio(_filePath!),
      ]);
    }
  }

  Future<void> _uploadAudio(String filePath) async {
    var url = Uri.parse('https://hackathon.vanhovev.com/speech/transcribe');
    print("test");
    var request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      filePath,
      contentType: MediaType('audio', 'mpeg'),
    ));

    try {
      var response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        var responseBody = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseBody);
        setState(() {
          _transcription = jsonResponse['transcription'] ?? "Transcription échouée.";
        });
        print("Audio transcrit : $_transcription");
        if (jsonResponse.containsKey('sensorName') && jsonResponse.containsKey('value')) {
          String sensorName = jsonResponse['sensorName'];
          bool isOn = jsonResponse['value'] == 1;

          showStatusAlert(context, sensorName, isOn);
        }
      } else {
        setState(() {
          _transcription = "Erreur lors de la transcription.";
        });
        print("Échec de la transcription : ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _transcription = "Erreur de connexion au serveur.";
      });
      print("Erreur d'envoi : $e");
    }
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey[100],
        title: const Text(
          "Bonjour Kake",
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
                              selectedCategory = roomId;
                              heaterTemperature = roomTemperatures.containsKey(selectedCategory)
                                  ? roomTemperatures[selectedCategory]!  // Utilise la dernière valeur réglée
                                  : roomTemperatures[selectedCategory] ?? 20.0;  // Ou la valeur en base par défaut
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
                              heaterTemperature,
                              sensor["value"] == 1,
                              Colors.redAccent,
                                  (newValue) {
                                setState(() {
                                  sensor["value"] = newValue ? 1 : 0;
                                });
                              },
                              client,
                              sensor["id"],
                          );
                        } else if (sensor["type"] == "speaker") {
                          return SpeakerDeviceCard(
                            sensor["name"],
                            sensor["value"] == 1, // Status basé sur la valeur du capteur
                            Colors.blueAccent,
                            "Enceinte",
                            sensor.containsKey("unit") && sensor["unit"] != null
                                ? "${double.tryParse(sensor["value"].toString()) ?? 0} ${sensor["unit"].toString().replaceAll("Â", "").trim()}"
                                : "${double.tryParse(sensor["value"].toString()) ?? 0}",
                          );
                        } else if (sensor["type"] == "camera") {
                          return CameraDeviceCard(
                            sensor["id"],
                            sensor["name"],
                            sensor["value"] == 1, // Basé sur le champ value (1 = allumé, 0 = éteint)
                            Colors.blueAccent,
                                (newValue) {
                              setState(() {
                                sensor["value"] = newValue ? 1 : 0;
                              });
                            },
                            client,
                            sensor["topic"],
                          );
                        } else if (sensor["type"] == "fan") {
                          return FanDeviceCard(
                            sensor["id"],
                            sensor["name"],
                            sensor["value"] == 1, // Basé sur le champ value (1 = allumé, 0 = éteint)
                            Colors.blueAccent,
                            (newValue) {
                              setState(() {
                                sensor["value"] = newValue ? 1 : 0;
                              });
                            },
                            client,
                            sensor["topic"],
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
                                : "${double.tryParse(sensor["value"].toString()) ?? 0}",
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
                  const Text("Température de la pièce", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              onPressed: () async {
                if (_isRecording) {
                  await _stopRecording();
                } else {
                  await _startRecording();
                }
              },
              backgroundColor: Colors.white,
              elevation: 5,
              child: Icon(_isRecording ? Icons.stop : Icons.mic, size: 28),

            ),
            const SizedBox(width: 30),
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
    );
  }
}

  void showStatusAlert(BuildContext context, String sensorName, bool isOn) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Statut mis à jour"),
          content: Text("$sensorName est maintenant ${isOn ? 'allumé' : 'éteint'}"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }