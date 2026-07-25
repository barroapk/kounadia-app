import "package:flutter/material.dart";
import "../models/match.dart";
import "../services/api_service.dart";

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Match>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _apiService.getTodayMatches();
  }

  void _reload() {
    setState(() {
      _matchesFuture = _apiService.getTodayMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("KOUNADIA")),
      body: FutureBuilder<List<Match>>(
        future: _matchesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      "Chargement des matchs...\n(jusqu'à une minute au premier chargement)",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Impossible de charger les matchs."),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text("Réessayer"),
                    ),
                  ],
                ),
              ),
            );
          }

          final matches = snapshot.data ?? [];

          if (matches.isEmpty) {
            return const Center(child: Text("Aucun match aujourd'hui."));
          }

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _matchesFuture;
            },
            child: ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                return ListTile(
                  title: Text("${match.homeTeam} vs ${match.awayTeam}"),
                  subtitle: Text(match.competition),
                  trailing: Text(
                    match.homeScore != null && match.awayScore != null
                        ? "${match.homeScore} - ${match.awayScore}"
                        : match.status,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
