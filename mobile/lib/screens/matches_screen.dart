import "package:flutter/material.dart";
import "../models/match.dart";
import "../services/api_service.dart";
import "../widgets/match_row.dart";
import "../widgets/competition_header.dart";
import "../widgets/empty_state.dart";
import "../widgets/loading_skeleton.dart";
import "../widgets/date_selector_bar.dart";
import "match_detail_screen.dart";

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final ApiService _apiService = ApiService();
  DateTime _selectedDate = DateTime.now();
  late Future<List<Match>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _fetch();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  String _formatDateForApi(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  Future<List<Match>> _fetch() {
    if (_isToday) return _apiService.getTodayMatches();
    return _apiService.getMatchesByDate(_formatDateForApi(_selectedDate));
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
      _matchesFuture = _fetch();
    });
  }

  void _reload() {
    setState(() {
      _matchesFuture = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DateSelectorBar(
          selectedDate: _selectedDate,
          onDateChanged: _onDateChanged,
        ),
        const Divider(height: 1),
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

              if (matches.isEmpty) {
                return const EmptyState(message: "Aucun match à cette date.");
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
                        ...competitionMatches.asMap().entries.map((entry) {
                          final match = entry.value;
                          return Column(
                            children: [
                              MatchRow(
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
                              if (entry.key < competitionMatches.length - 1)
                                const Divider(height: 1, indent: 56),
                            ],
                          );
                        }),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
