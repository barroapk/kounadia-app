import "package:flutter/material.dart";
import "../models/match.dart";
import "../services/api_service.dart";
import "../widgets/match_card.dart";
import "../widgets/competition_header.dart";
import "../widgets/empty_state.dart";
import "../widgets/loading_skeleton.dart";
import "match_detail_screen.dart";

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  late Future<List<Match>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _matchesFuture = _apiService.getTodayMatches();
  }

  void _reload() {
    setState(() {
      _matchesFuture = _apiService.getTodayMatches();
    });
  }

  List<Match> _filter(List<Match> matches, List<String> statuses) {
    return matches.where((m) => statuses.contains(m.status)).toList();
  }

  Widget _groupedList(List<Match> matches, String emptyMessage) {
    if (matches.isEmpty) {
      return EmptyState(message: emptyMessage);
    }

    final Map<String, List<Match>> grouped = {};
    for (final m in matches) {
      grouped.putIfAbsent(m.competition, () => []).add(m);
    }

    final competitions = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _matchesFuture;
      },
      child: ListView.builder(
        itemCount: competitions.length,
        itemBuilder: (context, index) {
          final competition = competitions[index];
          final competitionMatches = grouped[competition]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompetitionHeader(name: competition),
              ...competitionMatches.map(
                (match) => MatchCard(
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF16A34A),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF16A34A),
          tabs: const [
            Tab(text: "LIVE"),
            Tab(text: "À VENIR"),
            Tab(text: "TERMINÉS"),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<Match>>(
            future: _matchesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingSkeleton();
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

              return TabBarView(
                controller: _tabController,
                children: [
                  _groupedList(
                    _filter(matches, ["IN_PLAY", "PAUSED"]),
                    "Aucun match en direct pour le moment.",
                  ),
                  _groupedList(
                    _filter(matches, ["TIMED", "SCHEDULED"]),
                    "Aucun match à venir aujourd'hui.",
                  ),
                  _groupedList(
                    _filter(matches, ["FINISHED"]),
                    "Aucun match terminé aujourd'hui.",
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
