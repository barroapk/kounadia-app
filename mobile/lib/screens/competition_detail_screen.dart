import "package:flutter/material.dart";
import "../models/standings.dart";
import "../models/calendar.dart";
import "../services/api_service.dart";
import "../services/last_competition_service.dart";
import "../widgets/standings_table.dart";
import "../widgets/match_row.dart";
import "match_detail_screen.dart";

class CompetitionDetailScreen extends StatefulWidget {
  final String name;
  final String? code;

  const CompetitionDetailScreen({super.key, required this.name, this.code});

  @override
  State<CompetitionDetailScreen> createState() => _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LastCompetitionService _lastCompetitionService = LastCompetitionService();
  late TabController _tabController;
  Future<StandingsResponse?>? _standingsFuture;
  Future<CalendarResponse?>? _calendarFuture;
  int? _selectedMatchday;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lastCompetitionService.setLast(widget.name);
    if (widget.code != null) {
      _standingsFuture = _apiService.getStandings(widget.code!);
      _calendarFuture = _apiService.getCalendar(widget.code!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _unavailable(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _standingsTab() {
    if (widget.code == null) {
      return _unavailable("Classement non disponible pour cette compétition pour l'instant.");
    }

    return FutureBuilder<StandingsResponse?>(
      future: _standingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        if (data == null || data.standings.isEmpty) {
          return _unavailable("Classement indisponible pour le moment.");
        }

        return StandingsTable(data: data);
      },
    );
  }

  Widget _matchdaySelector(CalendarResponse calendar) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: calendar.totalMatchdays,
        itemBuilder: (context, index) {
          final day = index + 1;
          final isSelected = day == (_selectedMatchday ?? calendar.currentMatchday);
          final group = calendar.matchdays.firstWhere(
            (g) => g.matchday == day,
            orElse: () => MatchdayGroup(
              matchday: day,
              matches: [],
              allFinished: false,
              summary: MatchdaySummary(totalMatches: 0, finished: 0, live: 0, scheduled: 0),
            ),
          );

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: ChoiceChip(
              label: Text("J$day"),
              selected: isSelected,
              selectedColor: const Color(0xFF16A34A),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
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

        return Column(
          children: [
            _matchdaySelector(calendar),
            const Divider(height: 1),
            Expanded(
              child: group.matches.isEmpty
                  ? const Center(child: Text("Aucun match cette journée."))
                  : ListView.builder(
                      itemCount: group.matches.length,
                      itemBuilder: (context, index) {
                        final match = group.matches[index];
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
                            if (index < group.matches.length - 1)
                              const Divider(height: 1, indent: 56),
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
            Tab(text: "CLASSEMENT"),
            Tab(text: "CALENDRIER"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _standingsTab(),
          _calendarTab(),
        ],
      ),
    );
  }
}
