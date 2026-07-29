import "package:flutter/material.dart";
import "../models/match_analysis.dart";
import "../models/standings.dart";
import "../services/api_service.dart";
import "../widgets/standings_table.dart";
import "../widgets/match_countdown.dart";
import "../widgets/match_info_card.dart";

class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  final String homeTeam;
  final String awayTeam;
  final String? competitionCode;

  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    this.competitionCode,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  late Future<MatchAnalysis> _analysisFuture;
  Future<StandingsResponse?>? _standingsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _analysisFuture = _apiService.getMatchAnalysis(widget.matchId);

    if (widget.competitionCode != null) {
      _standingsFuture = _apiService.getStandings(widget.competitionCode!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reloadAnalysis() {
    setState(() {
      _analysisFuture = _apiService.getMatchAnalysis(widget.matchId);
    });
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

        // Réutilise le même tableau premium que l'onglet Compétitions,
        // avec les deux équipes de ce match marquées visuellement.
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
      appBar: AppBar(
        title: Text("${widget.homeTeam} vs ${widget.awayTeam}"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "FORME"),
            Tab(text: "FACE À FACE"),
            Tab(text: "CLASSEMENT"),
          ],
        ),
      ),
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

          return Column(
            children: [
              if (isUpcoming && kickoff != null) MatchCountdown(kickoff: kickoff),
              MatchInfoCard(venue: analysis.venue, referee: analysis.referee),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _formTab(analysis.home, analysis.away, analysis.homeTeam, analysis.awayTeam),
                    _headToHeadTab(analysis.headToHead),
                    _standingsTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
