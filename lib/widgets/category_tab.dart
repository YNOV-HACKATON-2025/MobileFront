import 'package:flutter/material.dart';

class CategoryTab extends StatelessWidget {
  final String title;
  final bool isActive;

  CategoryTab({required this.title, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isActive ? Colors.black : Colors.grey,
      ),
    );
  }
}
