import "package:flutter/material.dart";
import "matches_screen.dart";

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    MatchesScreen(
      mode: MatchesMode.today,
      emptyMessage: "Aucun match aujourd'hui.",
    ),
    MatchesScreen(
      mode: MatchesMode.live,
      emptyMessage: "Aucun match en direct pour le moment.",
    ),
  ];

  final _titles = const ["KOUNADIA", "En direct"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: "Aujourd'hui",
          ),
          NavigationDestination(
            icon: Icon(Icons.circle, color: Colors.red),
            label: "En direct",
          ),
        ],
      ),
    );
  }
}
