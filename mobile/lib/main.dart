import "package:flutter/material.dart";
import "screens/main_screen.dart";

void main() {
  runApp(const KounadiaApp());
}

class KounadiaApp extends StatelessWidget {
  const KounadiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "KOUNADIA",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
