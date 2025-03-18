import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'smart_home_screen.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;

  Future<void> login() async {
    var url = Uri.parse('https://hackathon.vanhovev.com/authentification/login');

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text,
          "password": passwordController.text,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        var data = jsonDecode(response.body);


        if (data.containsKey("user") &&
            data["user"].containsKey("stsTokenManager") &&
            data["user"]["stsTokenManager"].containsKey("accessToken")) {
          String token = data["user"]["stsTokenManager"]["accessToken"];


          final storage = FlutterSecureStorage();

          // Stocker le token
          await storage.write(key: "token", value: token);


          String? savedToken = await storage.read(key: "token");
          print("Token récupéré : $savedToken");

          // Redirection vers la HomePage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SmartHomeApp()),
          );
        } else {
          print("Erreur : Aucun token JWT reçu du serveur.");

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Erreur de connexion"),
                content: Text("Le serveur n'a pas renvoyé de token."),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("OK"),
                  ),
                ],
              );
            },
          );
        }
      } else {
        print("Erreur de connexion : ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Erreur réseau : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Connexion")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              obscureText: !isPasswordVisible,
              decoration: InputDecoration(
                labelText: "Mot de passe",
                suffixIcon: IconButton(
                  icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: Text("Se connecter"),
            ),
          ],
        ),
      ),
    );
  }
}