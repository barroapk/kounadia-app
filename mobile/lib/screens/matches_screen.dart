import "dart:async";
import "package:flutter/material.dart";
import "../models/match.dart";
import "../models/search_result.dart";
import "../config/country_flags.dart";
import "../config/competitions_catalog.dart";
import "../services/api_service.dart";
import "../services/competition_preferences.dart";
import "../widgets/match_row.dart";
import "../widgets/cached_logo.dart";
import "../widgets/country_card.dart";
import "../widgets/empty_state.dart";
import "../widgets/loading_skeleton.dart";
import "../widgets/date_selector_bar.dart";
import "match_detail_screen.dart";
import "competition_detail_screen.dart";

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

  /// Liste des équipes distinctes parmi les matchs actuellement affichés
  /// (date sélectionnée), utilisée par l'écran de recherche.
  List<String> get currentTeams {
    final matches = _matches ?? [];
    final teams = <String>{};
    for (final m in matches) {
      teams.add(m.homeTeam);
      teams.add(m.awayTeam);
    }
    return teams.toList()..sort();
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
        case SearchResultType.team:
          result = result
              .where((m) => m.homeTeam == filter.value || m.awayTeam == filter.value)
              .toList();
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
          provider: match.provider,
          homeTeamCrest: match.homeTeamCrest,
          awayTeamCrest: match.awayTeamCrest,
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
            key: ValueKey("${match.provider}-${match.id}"),
            match: match,
            onTap: () => _openMatch(match),
          ),
          if (entry.key < matches.length - 1) const Divider(height: 1, indent: 56),
        ],
      );
    }).toList();
  }

  int _minuteSortValue(Match m) {
    final label = m.liveMinuteLabel;
    if (label == null) return -1;
    if (label == "MT") return 45;
    final match = RegExp(r"^(\d+)").firstMatch(label);
    if (match == null) return -1;
    return int.tryParse(match.group(1)!) ?? -1;
  }

  List<Widget> _buildLiveSection(List<Match> liveMatches) {
    if (liveMatches.isEmpty) return [];

    final Map<String, List<Match>> byCompetition = {};
    final List<String> order = [];
    for (final m in liveMatches) {
      if (!byCompetition.containsKey(m.competition)) order.add(m.competition);
      byCompetition.putIfAbsent(m.competition, () => []).add(m);
    }

    for (final competition in order) {
      byCompetition[competition]!.sort(
        (a, b) => _minuteSortValue(b).compareTo(_minuteSortValue(a)),
      );
    }
    order.sort((a, b) => competitionRank(a).compareTo(competitionRank(b)));

    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
            ),
            Text(
              "EN DIRECT (${liveMatches.length})",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    ];

    for (final competition in order) {
      final matches = byCompetition[competition]!;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Row(
            children: [
              CachedLogo(
                url: matches.first.competitionEmblem,
                size: 16,
                fallbackIcon: Icons.emoji_events,
                fallbackColor: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 6),
              Text(
                "$competition (${matches.length})",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
      widgets.addAll(_matchRows(matches));
    }

    widgets.add(const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 4),
    ));

    return widgets;
  }

  Widget _competitionTile(String name, List<Match> matches, {required bool autoOpen}) {
    final hasLive = matches.any((m) => _liveStatuses.contains(m.status));
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            if (hasLive)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                ),
              ),
            CachedLogo(
              url: matches.first.competitionEmblem,
              size: 16,
              fallbackIcon: Icons.emoji_events,
              fallbackColor: const Color(0xFF16A34A),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Text("${matches.length}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
        children: [
          ..._matchRows(matches),
          InkWell(
            onTap: () {
              final competition = COMPETITIONS_CATALOG.firstWhere(
                (c) => c.name == name,
                orElse: () => CompetitionInfo(name: name, continent: '', country: ''),
              );

              final code = competition.code;
              final leagueId = competition.leagueId;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CompetitionDetailScreen(
                    name: name,
                    code: code,
                    leagueId: leagueId,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  "Voir la compétition",
                  style: TextStyle(color: const Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  List<Widget> _buildHierarchySection(List<Match> matches) {
    final Map<String, Map<String, Map<String, List<Match>>>> tree = {};
    final List<String> countryOrder = [];
    final List<String> liveCountryOrder = [];

    for (final m in matches) {
      final continent = m.continent ?? "Autre";
      final country = m.country ?? "Autre";
      tree.putIfAbsent(continent, () => {});
      tree[continent]!.putIfAbsent(country, () => {});
      if (country != "International" && !countryOrder.contains(country)) {
        countryOrder.add(country);
      }
      tree[continent]![country]!.putIfAbsent(m.competition, () => []).add(m);

      if (_liveStatuses.contains(m.status) && country != "International" && !liveCountryOrder.contains(country)) {
        liveCountryOrder.add(country);
      }
    }

    // Règle "pays ouvert par défaut" : priorité aux pays avec un match en direct,
    // sinon les 2 premiers pays rencontrés. Un pays explicitement recherché s'ouvre toujours.
    final autoOpenCountries = liveCountryOrder.isNotEmpty
        ? liveCountryOrder.take(2).toSet()
        : countryOrder.take(2).toSet();

    final searchedCompetition =
        _activeFilter?.type == SearchResultType.competition ? _activeFilter!.value : null;
    final searchedCountry =
        _activeFilter?.type == SearchResultType.country ? _activeFilter!.value : null;

    final continents = tree.keys.toList();

    List<Widget> competitionTiles(Map<String, List<Match>> competitions) {
      final names = competitions.keys.toList()
        ..sort((a, b) => competitionRank(a).compareTo(competitionRank(b)));

      return names.map((name) {
        final compMatches = competitions[name]!;
        final hasLive = compMatches.any((m) => _liveStatuses.contains(m.status));
        final isTopDivision = competitionRank(name) == 1;
        final isSearchedCompetition = searchedCompetition == name;
        return _competitionTile(
          name,
          compMatches,
          autoOpen: isTopDivision || hasLive || isSearchedCompetition,
        );
      }).toList();
    }

    return [
      _sectionLabel("TOUS LES SCORES"),
      ...continents.map((continent) {
        final countries = tree[continent]!;
        final international = countries["International"];
        final realCountries = Map<String, Map<String, List<Match>>>.from(countries)
          ..remove("International");

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(continent, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            if (international != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(children: competitionTiles(international)),
              ),
            ...realCountries.entries.map((countryEntry) {
              final country = countryEntry.key;
              final competitions = countryEntry.value;
              final flagUrl = flagUrlFor(country);
              final matchCount = competitions.values.fold<int>(0, (sum, l) => sum + l.length);
              final hasLiveInCountry = competitions.values.any(
                (list) => list.any((m) => _liveStatuses.contains(m.status)),
              );
              final isSearchedCountry = searchedCountry == country;
              // Un pays doit aussi s'ouvrir si la compétition recherchée s'y trouve.
              final containsSearchedCompetition =
                  searchedCompetition != null && competitions.containsKey(searchedCompetition);

              return CountryCard(
                title: country,
                flagUrl: flagUrl,
                matchCount: matchCount,
                competitionCount: competitions.length,
                initiallyExpanded: true,
                children: competitionTiles(competitions),
              );
            }),
          ],
        );
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F5F7),
      child: Column(
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

                final liveMatches = _isToday
                    ? matches.where((m) => _liveStatuses.contains(m.status)).toList()
                    : <Match>[];

                return RefreshIndicator(
                  onRefresh: _manualReload,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      ..._buildLiveSection(liveMatches),
                      ..._buildHierarchySection(matches),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
