import "dart:async";
import "package:flutter/material.dart";
import "../models/match.dart";
import "../models/search_result.dart";
import "../services/api_service.dart";
import "../services/competition_preferences.dart";
import "../widgets/match_row.dart";
import "../widgets/competition_header.dart";
import "../widgets/empty_state.dart";
import "../widgets/loading_skeleton.dart";
import "../widgets/date_selector_bar.dart";
import "match_detail_screen.dart";

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => MatchesScreenState();
}

class MatchesScreenState extends State<MatchesScreen> {
  static const _liveStatuses = ["LIVE", "IN_PLAY", "PAUSED"];

  final ApiService _apiService = ApiService();
  final CompetitionPreferences _competitionPrefs = CompetitionPreferences();
  DateTime _selectedDate = DateTime.now();
  SearchResult? _activeFilter;

  List<Match>? _matches;
  Set<String> _disabledCompetitions = {};
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

  /// Appelé depuis MainScreen après une sélection dans l'écran de recherche.
  void applySearchFilter(SearchResult result) {
    setState(() => _activeFilter = result);
  }

  void clearFilter() {
    setState(() => _activeFilter = null);
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

  List<Match> _applyFilters(List<Match> matches) {
    var result = matches;

    if (_disabledCompetitions.isNotEmpty) {
      result = result.where((m) => !_disabledCompetitions.contains(m.competition)).toList();
    }

    final filter = _activeFilter;
    if (filter != null) {
      switch (filter.type) {
        case SearchResultType.competition:
          result = result.where((m) => m.competition == filter.value).toList();
          break;
        case SearchResultType.country:
          result = result.where((m) => m.country == filter.value).toList();
          break;
        case SearchResultType.continent:
          result = result.where((m) => m.continent == filter.value).toList();
          break;
      }
    }

    return result;
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
    });
    try {
      final disabled = await _competitionPrefs.getDisabled();
      final data = await _fetch();
      if (!mounted) return;
      setState(() {
        _disabledCompetitions = disabled;
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

  Future<void> _silentRefreshIfLive() async {
    if (!_isToday) return;
    final current = _matches;
    if (current == null) return;
    final hasLive = current.any((m) => _liveStatuses.contains(m.status));
    if (!hasLive) return;

    try {
      final data = await _fetch();
      if (!mounted) return;
      setState(() => _matches = data);
    } catch (_) {}
  }

  void _onDateChanged(DateTime date) {
    setState(() => _selectedDate = date);
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
        if (_activeFilter != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(_activeFilter!.label),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: clearFilter,
              ),
            ),
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
                        ElevatedButton(onPressed: _manualReload, child: const Text("Réessayer")),
                      ],
                    ),
                  ),
                );
              }

              final matches = _applyFilters(_matches ?? []);

              if (matches.isEmpty) {
                return const EmptyState(message: "Aucun match ne correspond.");
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
                        CompetitionHeader(name: competition, emblemUrl: competitionMatches.first.competitionEmblem),
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
                          competitionCode: match.competitionCode,
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
