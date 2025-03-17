import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/device_card.dart';
import 'widgets/category_tab.dart';
import 'login_page.dart';
import 'register_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // 🔥 Ajoute cette ligne pour initialiser les plugins Flutter
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

  Map<String, List<Map<String, dynamic>>> roomDevices = {};
  Map<String, String> roomNames = {}; // Associer ID -> Nom
  Map<String, List<Map<String, dynamic>>> sensorsByRoom = {};

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
            selectedCategory = roomDevices.keys.first;
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

  @override
  void initState() {
    super.initState();
    fetchRooms();
    fetchSensors();
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
                            return DeviceCard(
                              sensor["name"],
                              sensor["type"],
                              true, // Par défaut activé
                              Icons.sensors,
                              Colors.blue,
                              (val) {},
                            );
                          }).toList()
                        : [Center(child: Text("Aucun capteur disponible"))],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    );
  }
}
