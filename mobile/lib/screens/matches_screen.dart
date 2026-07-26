import "package:flutter/material.dart";
import "../models/match.dart";
import "../services/api_service.dart";
import "../widgets/match_card.dart";
import "match_detail_screen.dart";

enum MatchesMode { today, live }

class MatchesScreen extends StatefulWidget {
  final MatchesMode mode;
  final String emptyMessage;

  const MatchesScreen({
    super.key,
    required this.mode,
    required this.emptyMessage,
  });

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Match>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _fetch();
  }

  Future<List<Match>> _fetch() {
    return widget.mode == MatchesMode.today
        ? _apiService.getTodayMatches()
        : _apiService.getLiveMatches();
  }

  void _reload() {
    setState(() {
      _matchesFuture = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Match>>(
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
                    "Chargement...\n(jusqu'à une minute au premier chargement)",
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
                  Text("Erreur : ${snapshot.error}"),
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
          return Center(child: Text(widget.emptyMessage));
        }

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _matchesFuture;
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              return MatchCard(
                match: match,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MatchDetailScreen(
                        matchId: match.id,
                        homeTeam: match.homeTeam,
                        awayTeam: match.awayTeam,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
