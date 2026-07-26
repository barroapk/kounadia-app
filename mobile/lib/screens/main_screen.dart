import "package:flutter/material.dart";
import "matches_screen.dart";
import "predictions_screen.dart";

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [MatchesScreen(), PredictionsScreen()];
  final _titles = const ["KOUNADIA", "Prédiction"];

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$feature : bientôt disponible")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
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
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.scoreboard_outlined), label: "Scores"),
          NavigationDestination(icon: Icon(Icons.insights), label: "Prédiction"),
        ],
      ),
    );
  }
}
