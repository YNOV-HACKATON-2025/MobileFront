import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/device_card.dart';
import 'widgets/category_tab.dart';
import 'login_page.dart';

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

  final Map<String, List<Map<String, dynamic>>> roomDevices = {
    "Salon": [
      {"name": "Lighting", "details": "10 Spotlights", "status": true, "icon": Icons.lightbulb, "color": Colors.deepPurple},
      {"name": "Smart TV", "details": "1 device", "status": false, "icon": Icons.tv, "color": Colors.grey},
      {"name": "LG AC", "details": "2 devices", "status": true, "icon": Icons.ac_unit, "color": Colors.black},
      {"name": "Heater", "details": "Set temperature", "status": true, "icon": Icons.thermostat, "color": Colors.red},
    ],
    "Cuisine": [
      {"name": "Lighting", "details": "5 Spotlights", "status": false, "icon": Icons.lightbulb, "color": Colors.orange},
      {"name": "Refrigerator", "details": "1 device", "status": true, "icon": Icons.kitchen, "color": Colors.blue},
      {"name": "Oven", "details": "1 device", "status": false, "icon": Icons.local_fire_department, "color": Colors.red},
      {"name": "Heater", "details": "Set temperature", "status": true, "icon": Icons.thermostat, "color": Colors.red},
    ],
    "Chambre": [
      {"name": "Lighting", "details": "3 Spotlights", "status": true, "icon": Icons.lightbulb, "color": Colors.yellow},
      {"name": "Air Purifier", "details": "1 device", "status": false, "icon": Icons.air, "color": Colors.cyan},
      {"name": "Smart Clock", "details": "1 device", "status": false, "icon": Icons.access_time, "color": Colors.grey},
      {"name": "Heater", "details": "Set temperature", "status": true, "icon": Icons.thermostat, "color": Colors.red},
    ],
    "Salle de bain": [
      {"name": "Lighting", "details": "2 Spotlights", "status": false, "icon": Icons.lightbulb, "color": Colors.purple},
      {"name": "Water Heater", "details": "1 device", "status": true, "icon": Icons.water_damage, "color": Colors.blue},
      {"name": "Exhaust Fan", "details": "1 device", "status": false, "icon": Icons.wind_power, "color": Colors.black},
      {"name": "Heater", "details": "Set temperature", "status": true, "icon": Icons.thermostat, "color": Colors.red},
    ],
  };

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: roomDevices.keys.map((room) {
                      return GestureDetector(
                        onTap: () => setState(() => selectedCategory = room),
                        child: CategoryTab(title: room, isActive: selectedCategory == room),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: roomDevices[selectedCategory]!.map((device) {
                        return DeviceCard(
                          device["name"],
                          device["details"],
                          device["status"],
                          device["icon"],
                          device["color"],
                              (val) {
                            setState(() {
                              device["status"] = val;
                            });
                          },
                        );
                      }).toList(),
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
