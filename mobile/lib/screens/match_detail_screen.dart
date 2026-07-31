import "dart:async";
import "package:flutter/material.dart";
import "../models/match_analysis.dart";
import "../models/standings.dart";
import "../services/api_service.dart";
import "../widgets/standings_table.dart";
import "../widgets/match_countdown.dart";
import "../widgets/match_info_card.dart";
import "../widgets/match_header.dart";
import "../widgets/match_statistics_view.dart";
import "../widgets/match_lineups_view.dart";
import "../widgets/match_timeline_view.dart";
import "../widgets/match_summary_card.dart";

class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  final String homeTeam;
  final String awayTeam;
  final String? competitionCode;
  final String? homeTeamCrest;
  final String? awayTeamCrest;
  final String provider;

  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    this.competitionCode,
    this.homeTeamCrest,
    this.awayTeamCrest,
    this.provider = 'football-data',
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late Future<MatchAnalysis> _analysisFuture;
  Future<StandingsResponse?>? _standingsFuture;

  TabController? _tabController;
  int _tabCountForController = 0;
  Timer? _liveRefreshTimer;
  String? _lastKnownStatus;

  Future<MatchAnalysis> _fetchAnalysis() {
    return _apiService.getMatchAnalysis(widget.matchId, provider: widget.provider).then((analysis) {
      _updateRefreshStrategy(analysis.status);
      return analysis;
    });
  }

  /// Décide de la fréquence de rafraîchissement selon le statut réel du match :
  /// jamais pour un match à venir ou terminé, seulement pendant qu'il se joue.
  void _updateRefreshStrategy(String status) {
    if (_lastKnownStatus == status) return;
    _lastKnownStatus = status;

    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = null;

    Duration? interval;
    if (status == "IN_PLAY") {
      interval = const Duration(seconds: 20);
    } else if (status == "PAUSED") {
      interval = const Duration(seconds: 45);
    }

    if (interval != null) {
      _liveRefreshTimer = Timer.periodic(interval, (_) => _reloadAnalysis());
    }
  }

  @override
  void initState() {
    super.initState();
    _analysisFuture = _fetchAnalysis();

    if (widget.competitionCode != null) {
      _standingsFuture = _apiService.getStandings(widget.competitionCode!);
    }

  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _reloadAnalysis() {
    setState(() {
      _analysisFuture = _fetchAnalysis();
    });
  }

  void _ensureTabController(int tabCount) {
    if (_tabController == null || _tabCountForController != tabCount) {
      _tabController?.dispose();
      _tabController = TabController(length: tabCount, vsync: this);
      _tabCountForController = tabCount;
    }
  }

  Widget _formTab(TeamForm home, TeamForm away, String homeTeamName, String awayTeamName) {
    Widget formCard(String label, TeamForm form) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (form.matchesAnalyzed == 0)
                const Text("Pas assez de données historiques pour l'instant.")
              else ...[
                Text(
                  "${form.wins}V - ${form.draws}N - ${form.losses}D sur ${form.matchesAnalyzed} match(s)",
                ),
                Text("Forme : ${form.formPercent}% (${form.points}/${form.maxPoints} pts)"),
                Text(
                  "Buts : ${form.goalsFor} marqués / ${form.goalsAgainst} encaissés (diff. ${form.goalDifference})",
                ),
                Text(
                  "Moyenne : ${form.avgGoalsFor} marqués / ${form.avgGoalsAgainst} encaissés par match",
                ),
                Text("Clean sheets : ${form.cleanSheets} · Sans marquer : ${form.failedToScore}"),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        formCard(homeTeamName, home),
        formCard(awayTeamName, away),
      ],
    );
  }

  Widget _headToHeadTab(HeadToHead h2h) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Confrontations directes", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (!h2h.available)
                  const Text("Aucun historique de confrontation disponible.")
                else
                  Text(
                    "${h2h.totalMatches} match(s) : ${h2h.team1Wins}V - ${h2h.draws}N - ${h2h.team2Wins}D",
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _standingsTab() {
    if (widget.competitionCode == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Classement non disponible pour cette compétition.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return FutureBuilder<StandingsResponse?>(
      future: _standingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        if (data == null || data.standings.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "Classement non disponible pour cette compétition.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return StandingsTable(
          data: data,
          highlightHomeTeam: widget.homeTeam,
          highlightAwayTeam: widget.awayTeam,
          onSeasonChanged: (season) {
            setState(() {
              _standingsFuture = _apiService.getStandings(
                widget.competitionCode ?? '',
                season: season,
              );
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: FutureBuilder<MatchAnalysis>(
        future: _analysisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                    ElevatedButton(onPressed: _reloadAnalysis, child: const Text("Réessayer")),
                  ],
                ),
              ),
            );
          }

          final analysis = snapshot.data!;
          final kickoff = analysis.utcDate != null ? DateTime.tryParse(analysis.utcDate!) : null;
          final isUpcoming = analysis.status == "TIMED" || analysis.status == "SCHEDULED";
          final isLive = analysis.status == "IN_PLAY" || analysis.status == "PAUSED";

          // Construction dynamique des onglets : jamais un onglet vide.
          final tabs = <Tab>[
            const Tab(icon: Icon(Icons.show_chart, size: 18), text: "FORME"),
            const Tab(icon: Icon(Icons.compare_arrows, size: 18), text: "FACE À FACE"),
            const Tab(icon: Icon(Icons.leaderboard_outlined, size: 18), text: "CLASSEMENT"),
          ];
          final tabViews = <Widget>[
            _formTab(analysis.home, analysis.away, analysis.homeTeam, analysis.awayTeam),
            _headToHeadTab(analysis.headToHead),
            _standingsTab(),
          ];

          if (analysis.statistics != null &&
              (analysis.statistics!.home.isNotEmpty || analysis.statistics!.away.isNotEmpty)) {
            tabs.add(const Tab(icon: Icon(Icons.bar_chart, size: 18), text: "STATS"));
            tabViews.add(MatchStatisticsView(
              statistics: analysis.statistics!,
              homeTeam: analysis.homeTeam,
              awayTeam: analysis.awayTeam,
            ));
          }

          if (analysis.lineups != null && analysis.lineups!.isNotEmpty) {
            tabs.add(const Tab(icon: Icon(Icons.groups_outlined, size: 18), text: "COMPOS"));
            tabViews.add(MatchLineupsView(lineups: analysis.lineups!));
          }

          if (analysis.events != null && analysis.events!.isNotEmpty) {
            tabs.add(const Tab(icon: Icon(Icons.timeline, size: 18), text: "CHRONO"));
            tabViews.add(MatchTimelineView(events: analysis.events!, homeTeam: analysis.homeTeam));
          }

          _ensureTabController(tabs.length);

          return Column(
            children: [
              MatchHeader(
                homeTeam: widget.homeTeam,
                awayTeam: widget.awayTeam,
                homeTeamCrest: widget.homeTeamCrest,
                awayTeamCrest: widget.awayTeamCrest,
                statusLabel: isLive ? "EN DIRECT" : (analysis.status == "FINISHED" ? "Terminé" : "À venir"),
                isLive: isLive,
              ),
              if (isUpcoming && kickoff != null) MatchCountdown(kickoff: kickoff),
              MatchInfoCard(venue: analysis.venue, referee: analysis.referee),
              MatchSummaryCard(
                statistics: analysis.statistics,
                events: analysis.events,
                homeTeam: analysis.homeTeam,
                awayTeam: analysis.awayTeam,
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF16A34A),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF16A34A),
                tabs: tabs,
              ),
              Expanded(
                child: TabBarView(controller: _tabController, children: tabViews),
              ),
            ],
          );
        },
      ),
    );
  }
}
