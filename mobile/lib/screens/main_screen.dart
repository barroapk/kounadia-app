import "package:flutter/material.dart";
import "matches_screen.dart";
import "predictions_screen.dart";
import "competitions_screen.dart";
import "brvm/brvm_screen.dart";
import "brvm/brvm_compare_screen.dart";
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
    const CompetitionsScreen(),
    const BrvmScreen(),
  ];
  final _titles = const ["KOUNADIA", "Prédiction", "Compétitions", "Bourse"];

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$feature : bientôt disponible")),
    );
  }

  Future<void> _openSearch() async {
    final result = await Navigator.push<SearchResult>(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          availableTeams: _matchesKey.currentState?.currentTeams ?? [],
        ),
      ),
    );

    if (result != null) {
      setState(() => _currentIndex = 0);
      _matchesKey.currentState?.applySearchFilter(result);
    }
  }

  bool get _isBrvmTab => _currentIndex == 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: _isBrvmTab ? _buildBrvmDrawer() : null,
      appBar: AppBar(
        leading: _isBrvmTab
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              )
            : null,
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
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: "Compétitions"),
          NavigationDestination(icon: Icon(Icons.show_chart), label: "Bourse"),
        ],
      ),
    );
  }

  Widget _buildBrvmDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                "Bourse BRVM",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey[800]),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text("Tableau de bord"),
              subtitle: const Text("Marché, indices, classements et actions"),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                "À venir",
                style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              enabled: false,
              leading: Icon(Icons.star_border, color: Colors.grey[400]),
              title: Text("Mes favoris", style: TextStyle(color: Colors.grey[400])),
              subtitle: Text("Actions que je surveille", style: TextStyle(color: Colors.grey[350])),
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text("Comparer des actions"),
              subtitle: const Text("Comparer plusieurs sociétés"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BrvmCompareScreen()),
                );
              },
            ),
            ListTile(
              enabled: false,
              leading: Icon(Icons.school_outlined, color: Colors.grey[400]),
              title: Text("Guide du débutant", style: TextStyle(color: Colors.grey[400])),
              subtitle: Text("Comprendre la Bourse simplement", style: TextStyle(color: Colors.grey[350])),
            ),
            ListTile(
              enabled: false,
              leading: Icon(Icons.info_outline, color: Colors.grey[400]),
              title: Text("Comprendre les indicateurs", style: TextStyle(color: Colors.grey[400])),
              subtitle: Text("SMA, RSI, volatilité, drawdown", style: TextStyle(color: Colors.grey[350])),
            ),
          ],
        ),
      ),
    );
  }
}
