import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/device_card.dart';
import 'widgets/category_tab.dart';
import 'login_page.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';


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

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initRecorder();
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
    _filePath = '${tempDir.path}/recording.m4a';  // 📌 Enregistre en `.m4a`

    await _recorder!.startRecorder(toFile: _filePath, codec: Codec.aacMP4); // 📌 `Codec.aacMP4`
    setState(() => _isRecording = true);
  }


  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    setState(() => _isRecording = false);
    print("✅ Enregistrement terminé : $_filePath");

    if (_filePath != null) {
      // ✅ Envoi vers le serveur et copie locale simultanément
      await Future.wait([
        _uploadAudio(_filePath!),  // Envoi du fichier au serveur
      ]);
    }
  }

  Future<void> _uploadAudio(String filePath) async {
    var url = Uri.parse('http://10.70.4.83:3000/speech/transcribe');  // Remplace par l'IP de ton PC si nécessaire
    print("test");
    var request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath(
      'audio',
      filePath,
      contentType: MediaType('audio', 'mpeg'),  // 📌 Utilise `audio/mpeg` pour MP3
    ));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseBody);
        setState(() {
          _transcription = jsonResponse['transcription'] ?? "Transcription échouée.";
        });
        print("✅ Audio transcrit : $_transcription");
      } else {
        setState(() {
          _transcription = "Erreur lors de la transcription.";
        });
        print("❌ Échec de la transcription : ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _transcription = "Erreur de connexion au serveur.";
      });
      print("❌ Erreur d'envoi : $e");
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
          "Hi Arpan",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // 🔹 Ajout de la transcription au-dessus de "Bienvenue sur SmartHome"
          Text(
            "🗣️ $_transcription",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          // 🔹 Garde le texte original
          const Center(child: Text("Bienvenue sur SmartHome")),
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
