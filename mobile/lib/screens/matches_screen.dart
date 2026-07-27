import "dart:async";
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
  static const _liveStatuses = ["LIVE", "IN_PLAY", "PAUSED"];

  final ApiService _apiService = ApiService();
  DateTime _selectedDate = DateTime.now();

  List<Match>? _matches;
  bool _isInitialLoading = true;
  String? _errorMessage;
  Timer? _backgroundTimer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _backgroundTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _silentRefreshIfLive();
    });
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    super.dispose();
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

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _fetch();
      if (!mounted) return;
      setState(() {
        _matches = data;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isInitialLoading = false;
      });
    }
  }

  /// Actualisation silencieuse : ne touche à rien si aucun match n'est
  /// actuellement en direct dans la liste affichée, pour ne pas consommer
  /// de requêtes inutilement. Ne montre jamais de chargement à l'utilisateur.
  Future<void> _silentRefreshIfLive() async {
    final current = _matches;
    if (current == null) return;
    final hasLive = current.any((m) => _liveStatuses.contains(m.status));
    if (!hasLive) return;

    try {
      final data = await _fetch();
      if (!mounted) return;
      setState(() {
        _matches = data;
      });
    } catch (_) {
      // Échec silencieux : on garde l'affichage actuel plutôt que de
      // perturber l'utilisateur pour un rafraîchissement en arrière-plan.
    }
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadInitial();
  }

  Future<void> _manualReload() => _loadInitial();

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
          child: Builder(
            builder: (context) {
              if (_isInitialLoading) {
                return const LoadingSkeleton();
              }

              if (_errorMessage != null && _matches == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Erreur : $_errorMessage"),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _manualReload,
                          child: const Text("Réessayer"),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final matches = _matches ?? [];

              if (matches.isEmpty) {
                return const EmptyState(message: "Aucun match à cette date.");
              }

              final Map<String, List<Match>> grouped = {};
              for (final m in matches) {
                grouped.putIfAbsent(m.competition, () => []).add(m);
              }
              final competitions = grouped.keys.toList();

              return RefreshIndicator(
                onRefresh: _manualReload,
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
                                key: ValueKey(match.id),
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
