import "package:flutter/material.dart";
import "matches_screen.dart";
import "predictions_screen.dart";
import "settings_screen.dart";
import "search_screen.dart";
import "../models/search_result.dart";

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _matchesKey = GlobalKey<MatchesScreenState>();

  late final List<Widget> _screens = [
    MatchesScreen(key: _matchesKey),
    const PredictionsScreen(),
  ];
  final _titles = const ["KOUNADIA", "Prédiction"];

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$feature : bientôt disponible")),
    );
  }

  Future<void> _openSearch() async {
    final result = await Navigator.push<SearchResult>(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );

    if (result != null) {
      setState(() => _currentIndex = 0);
      _matchesKey.currentState?.applySearchFilter(result);
    }
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
            onPressed: _openSearch,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _comingSoon(context, "Notifications"),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
