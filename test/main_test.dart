import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton/main.dart';
import 'package:hackaton/smart_home_screen.dart';

void main() {
  testWidgets('Lancement de l\'application et affichage de SmartHomeScreen', (WidgetTester tester) async {
   // await tester.pumpWidget(const SmartHomeApp());

    expect(find.byType(SmartHomeScreen), findsOneWidget);
    expect(find.text("Hi Arpan"), findsOneWidget);
  });
}
