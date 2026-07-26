import "package:flutter/material.dart";
import "matches_screen.dart";

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$feature : bientôt disponible")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "KOUNADIA",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _comingSoon(context, "Recherche"),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _comingSoon(context, "Notifications"),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => _comingSoon(context, "Profil"),
          ),
        ],
      ),
      body: const MatchesScreen(),
    );
  }
}
