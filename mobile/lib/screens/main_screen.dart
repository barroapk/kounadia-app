import "package:flutter/material.dart";
import "matches_screen.dart";
import "predictions_screen.dart";
import "settings_screen.dart";
import "search_screen.dart";
import "../models/search_result.dart";
import "knd/deposit_screen.dart";
import "knd/withdrawal_screen.dart";
import "knd/history_screen.dart";

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
    const HistoryScreen(),
  ];
  final _titles = const ["KOUNADIA", "Prédiction", "Historique"];

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

  void _showKndMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.green),
              title: const Text("Dépôt"),
              subtitle: const Text("Alimenter mon compte 1xBet"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DepositScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.orange),
              title: const Text("Retrait"),
              subtitle: const Text("Retirer depuis mon compte 1xBet"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WithdrawalScreen()),
                );
              },
            ),
          ],
        ),
      ),
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
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FloatingActionButton.extended(
            onPressed: () => _showKndMenu(context),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text("Dépôt / Retrait"),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.scoreboard_outlined), label: "Scores"),
          NavigationDestination(icon: Icon(Icons.insights), label: "Prédiction"),
          NavigationDestination(icon: Icon(Icons.history), label: "Historique"),
        ],
      ),
    );
  }
}
