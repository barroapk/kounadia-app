import "package:flutter/material.dart";
import "../models/standings.dart";
import "../models/calendar.dart";
import "../models/match.dart";
import "../services/api_service.dart";
import "../services/last_competition_service.dart";
import "../services/season_preference_service.dart";
import "../widgets/standings_table.dart";
import "../widgets/match_row.dart";
import "../widgets/matchday_selector.dart";
import "match_detail_screen.dart";

class CompetitionDetailScreen extends StatefulWidget {
  final String name;
  final String? code;
  final int? leagueId;
  final String? highlightHomeTeam;
  final String? highlightAwayTeam;

  const CompetitionDetailScreen({
    super.key,
    required this.name,
    this.code,
    this.leagueId,
    this.highlightHomeTeam,
    this.highlightAwayTeam,
  });

  @override
  State<CompetitionDetailScreen> createState() => _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LastCompetitionService _lastCompetitionService = LastCompetitionService();
  final SeasonPreferenceService _seasonPreferenceService = SeasonPreferenceService();
  late TabController _tabController;
  Future<StandingsResponse?>? _standingsFuture;
  Future<CalendarResponse?>? _calendarFuture;
  int? _selectedMatchday;
  String _calendarSearch = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lastCompetitionService.setLast(widget.name);
    final competitionId = widget.code ?? widget.leagueId?.toString();

    _calendarFuture = competitionId != null
        ? _apiService.getCalendar(competitionId)
        : null;

    // Démarre l'appel du classement immédiatement (saison courante)
    if (competitionId != null) {
      _standingsFuture = _apiService.getStandings(competitionId);
    }
    _applyLastSeasonIfAny();
  }

  Future<void> _applyLastSeasonIfAny() async {
    // Les préférences de saison concernent uniquement football-data.org.
    if (widget.code == null) return;

    final lastSeason = await _seasonPreferenceService.getLastSeason(widget.code!);
    if (!mounted || lastSeason == null) return;

    setState(() {
      _standingsFuture = _apiService.getStandings(widget.code!, season: lastSeason);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSeasonChanged(String startYear) {
    if (widget.code == null) return;

    setState(() {
      _standingsFuture = _apiService.getStandings(widget.code!, season: startYear);
    });
    _seasonPreferenceService.setLastSeason(widget.code!, startYear);
  }

  void _onCalendarSeasonChanged(String season) {
    final competitionId = widget.code ?? widget.leagueId?.toString();
    if (competitionId == null) return;

    setState(() {
      _selectedMatchday = null; // Repart sur la journée en cours de la nouvelle saison.
      _calendarFuture = _apiService.getCalendar(competitionId, season: season);
    });
  }

  Widget _unavailable(String message) {
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center)),
    );
  }

  Widget _standingsTab() {
    if (widget.code == null && widget.leagueId == null) {
      return _unavailable("Classement non disponible pour cette compétition pour l'instant.");
    }

    return FutureBuilder<StandingsResponse?>(
      future: _standingsFuture,
      builder: (context, snapshot) {
        if (_standingsFuture == null || snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        if (data == null || data.standings.isEmpty) {
          return _unavailable("Classement indisponible pour le moment.");
        }

        return StandingsTable(
          data: data,
          highlightHomeTeam: widget.highlightHomeTeam,
          highlightAwayTeam: widget.highlightAwayTeam,
          onSeasonChanged: _onSeasonChanged,
        );
      },
    );
  }

  static const _weekdays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"];
  static const _months = [
    "janvier", "février", "mars", "avril", "mai", "juin",
    "juillet", "août", "septembre", "octobre", "novembre", "décembre",
  ];

  String _dateLabel(DateTime date) {
    final weekday = _weekdays[date.weekday - 1];
    final month = _months[date.month - 1];
    return "${weekday[0].toUpperCase()}${weekday.substring(1)} ${date.day} $month";
  }

  Map<String, List<Match>> _groupByDate(List<Match> matches) {
    final Map<String, List<Match>> grouped = {};
    for (final m in matches) {
      final date = DateTime.tryParse(m.utcDate)?.toLocal();
      final label = date != null ? _dateLabel(date) : "Date inconnue";
      grouped.putIfAbsent(label, () => []).add(m);
    }
    return grouped;
  }

  Widget _calendarSeasonSelector(CalendarResponse calendar) {
    final currentSeason = calendar.season ??
        (calendar.availableSeasons.isNotEmpty ? calendar.availableSeasons.first.value : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text("Saison : ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: currentSeason,
            underline: const SizedBox(),
            isDense: true,
            items: calendar.availableSeasons
                .map((season) => DropdownMenuItem(value: season.value, child: Text(season.label, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (value) {
              if (value != null && value != currentSeason) {
                _onCalendarSeasonChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _calendarTab() {
    if (widget.code == null && widget.leagueId == null) {
      return _unavailable("Calendrier non disponible pour cette compétition pour l'instant.");
    }

    return FutureBuilder<CalendarResponse?>(
      future: _calendarFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final calendar = snapshot.data;
        if (calendar == null) {
          return _unavailable("Calendrier indisponible pour le moment.");
        }

        if (calendar.matchdays.isEmpty) {
          return Column(
            children: [
              if (calendar.availableSeasons.isNotEmpty) _calendarSeasonSelector(calendar),
              Expanded(
                child: _unavailable("Aucun calendrier disponible pour cette saison."),
              ),
            ],
          );
        }

        final selectedDay = _selectedMatchday ?? calendar.currentMatchday;
        final group = calendar.matchdays.firstWhere(
          (g) => g.matchday == selectedDay,
          orElse: () => calendar.matchdays.first,
        );

        final query = _calendarSearch.trim().toLowerCase();
        final filteredMatches = query.isEmpty
            ? group.matches
            : group.matches
                .where((m) =>
                    m.homeTeam.toLowerCase().contains(query) || m.awayTeam.toLowerCase().contains(query))
                .toList();

        final groupedByDate = _groupByDate(filteredMatches);
        final dateLabels = groupedByDate.keys.toList();

        return Column(
          children: [
            if (calendar.availableSeasons.isNotEmpty)
              _calendarSeasonSelector(calendar),

            MatchdaySelector(
              calendar: calendar,
              selectedDay: selectedDay,
              onSelected: (day) => setState(() => _selectedMatchday = day),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Filtrer par équipe...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (value) => setState(() => _calendarSearch = value),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filteredMatches.isEmpty
                  ? const Center(child: Text("Aucun match ne correspond."))
                  : ListView.builder(
                      itemCount: dateLabels.length,
                      itemBuilder: (context, dateIndex) {
                        final label = dateLabels[dateIndex];
                        final dateMatches = groupedByDate[label]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            ...dateMatches.asMap().entries.map((entry) {
                              final match = entry.value;
                              return Column(
                                children: [
                                  MatchRow(
                                    key: ValueKey("cal-${match.provider}-${match.id}"),
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
                                            homeTeamCrest: match.homeTeamCrest,
                                            awayTeamCrest: match.awayTeamCrest,
                                            provider: match.provider,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (entry.key < dateMatches.length - 1)
                                    const Divider(height: 1, indent: 56),
                                ],
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sans code football-data.org, ni classement ni calendrier ne sont possibles
    // aujourd'hui : un seul message honnête plutôt que 2 onglets vides côte à côte.
    if (widget.code == null && widget.leagueId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(title: Text(widget.name)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text(
                  "Classement et calendrier bientôt disponibles pour cette compétition.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  "En attendant, vous pouvez suivre les matchs en direct et les résultats dans l'onglet Scores.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.sports_soccer, size: 18),
                  label: const Text("Retour"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text(widget.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.leaderboard_outlined), text: "CLASSEMENT"),
            Tab(icon: Icon(Icons.calendar_month_outlined), text: "CALENDRIER"),
          ],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [_standingsTab(), _calendarTab()]),
    );
  }
}
