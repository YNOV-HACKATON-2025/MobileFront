import 'package:flutter/material.dart';

import '../login_page.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.home, size: 30), onPressed: () {}),
          const SizedBox(width: 20),
          FloatingActionButton(
            onPressed: () {},
            backgroundColor: Colors.white,
            elevation: 5,
            child: const Icon(Icons.mic, size: 28),
          ),
          const SizedBox(width: 20),
          IconButton(icon: const Icon(Icons.person, size: 30), onPressed: () {LoginPage();}),
        ],
      ),
    );
  }
}