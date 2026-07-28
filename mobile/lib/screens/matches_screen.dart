import "dart:async";
import "package:flutter/material.dart";
import "../models/match.dart";
import "../models/search_result.dart";
import "../config/country_flags.dart";
import "../services/api_service.dart";
import "../services/competition_preferences.dart";
import "../widgets/match_row.dart";
import "../widgets/cached_logo.dart";
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

  void _openMatch(Match match) {
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
  }

  List<Widget> _matchRows(List<Match> matches) {
    return matches.asMap().entries.map((entry) {
      final match = entry.value;
      return Column(
        children: [
          MatchRow(
            key: ValueKey(match.id),
            match: match,
            onTap: () => _openMatch(match),
          ),
          if (entry.key < matches.length - 1) const Divider(height: 1, indent: 56),
        ],
      );
    }).toList();
  }

  Widget _buildHierarchy(List<Match> matches) {
    final Map<String, Map<String, Map<String, List<Match>>>> tree = {};
    final List<String> competitionOrder = [];
    final Set<String> liveCompetitions = {};

    for (final m in matches) {
      final continent = m.continent ?? "Autre";
      final country = m.country ?? "Autre";
      tree.putIfAbsent(continent, () => {});
      tree[continent]!.putIfAbsent(country, () => {});
      if (!tree[continent]![country]!.containsKey(m.competition)) {
        competitionOrder.add(m.competition);
      }
      tree[continent]![country]!.putIfAbsent(m.competition, () => []).add(m);

      if (_liveStatuses.contains(m.status)) {
        liveCompetitions.add(m.competition);
      }
    }

    // Priorité : compétitions avec un match en direct. Sinon, les 2 premières rencontrées.
    final autoOpenCompetitions = liveCompetitions.isNotEmpty
        ? liveCompetitions
        : competitionOrder.take(2).toSet();

    final continents = tree.keys.toList();

    Widget competitionTile(String name, List<Match> compMatches) {
      return ExpansionTile(
        initiallyExpanded: autoOpenCompetitions.contains(name),
        title: Row(
          children: [
            Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
            Text(
              "${compMatches.length}",
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        children: _matchRows(compMatches),
      );
    }

    return ListView.builder(
      itemCount: continents.length,
      itemBuilder: (context, index) {
        final continent = continents[index];
        final countries = tree[continent]!;

        final international = countries["International"];
        final realCountries = Map<String, Map<String, List<Match>>>.from(countries)
          ..remove("International");

        final continentHasAutoOpen = countries.values.any(
          (comps) => comps.keys.any((c) => autoOpenCompetitions.contains(c)),
        );

        return ExpansionTile(
          initiallyExpanded: continentHasAutoOpen,
          title: Text(continent, style: const TextStyle(fontWeight: FontWeight.bold)),
          children: [
            if (international != null)
              ...international.entries.map((e) => competitionTile(e.key, e.value)),
            ...realCountries.entries.map((countryEntry) {
              final country = countryEntry.key;
              final competitions = countryEntry.value;
              final flagUrl = flagUrlFor(country);
              final matchCount = competitions.values.fold<int>(0, (sum, l) => sum + l.length);
              final countryHasAutoOpen =
                  competitions.keys.any((c) => autoOpenCompetitions.contains(c));

              return ExpansionTile(
                initiallyExpanded: countryHasAutoOpen,
                title: Row(
                  children: [
                    if (flagUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CachedLogo(url: flagUrl, size: 20, fallbackIcon: Icons.flag_outlined),
                      ),
                    Expanded(child: Text(country)),
                    Text("$matchCount", style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
                children: competitions.entries
                    .map((compEntry) => competitionTile(compEntry.key, compEntry.value))
                    .toList(),
              );
            }),
          ],
        );
      },
    );
  }

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

              return RefreshIndicator(
                onRefresh: _manualReload,
                child: _buildHierarchy(matches),
              );
            },
          ),
        ),
      ],
    );
  }
}
