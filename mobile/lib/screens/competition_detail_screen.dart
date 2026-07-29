import "package:flutter/material.dart";
import "../models/standings.dart";
import "../models/calendar.dart";
import "../models/match.dart";
import "../services/api_service.dart";
import "../services/last_competition_service.dart";
import "../services/season_preference_service.dart";
import "../widgets/standings_table.dart";
import "../widgets/match_row.dart";
import "match_detail_screen.dart";

class CompetitionDetailScreen extends StatefulWidget {
  final String name;
  final String? code;
  final String? highlightHomeTeam;
  final String? highlightAwayTeam;

  const CompetitionDetailScreen({
    super.key,
    required this.name,
    this.code,
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
    _calendarFuture = widget.code != null ? _apiService.getCalendar(widget.code!) : null;
    _loadStandingsWithLastSeason();
  }

  Future<void> _loadStandingsWithLastSeason() async {
    if (widget.code == null) return;
    final lastSeason = await _seasonPreferenceService.getLastSeason(widget.code!);
    if (!mounted) return;
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
    setState(() {
      _standingsFuture = _apiService.getStandings(widget.code!, season: startYear);
    });
    _seasonPreferenceService.setLastSeason(widget.code!, startYear);
  }

  Widget _unavailable(String message) {
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center)),
    );
  }

  Widget _standingsTab() {
    if (widget.code == null) {
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

  Widget _matchdaySelector(CalendarResponse calendar) {
    final realMatchdays = calendar.matchdays.map((g) => g.matchday).toList();

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: realMatchdays.length,
        itemBuilder: (context, index) {
          final day = realMatchdays[index];
          final isSelected = day == (_selectedMatchday ?? calendar.currentMatchday);
          final group = calendar.matchdays.firstWhere((g) => g.matchday == day);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: ChoiceChip(
              label: Text("J$day"),
              selected: isSelected,
              selectedColor: const Color(0xFF16A34A),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12),
              avatar: group.summary.live > 0
                  ? const CircleAvatar(backgroundColor: Color(0xFFDC2626), radius: 4)
                  : null,
              onSelected: (_) => setState(() => _selectedMatchday = day),
            ),
          );
        },
      ),
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

  Widget _calendarTab() {
    if (widget.code == null) {
      return _unavailable("Calendrier non disponible pour cette compétition pour l'instant.");
    }

    return FutureBuilder<CalendarResponse?>(
      future: _calendarFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final calendar = snapshot.data;
        if (calendar == null || calendar.matchdays.isEmpty) {
          return _unavailable("Calendrier indisponible pour le moment.");
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
            _matchdaySelector(calendar),
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
