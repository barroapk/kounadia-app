import "package:flutter/material.dart";
import "../models/match_analysis.dart";
import "../services/api_service.dart";

class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  final String homeTeam;
  final String awayTeam;

  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<MatchAnalysis> _analysisFuture;

  @override
  void initState() {
    super.initState();
    _analysisFuture = _apiService.getMatchAnalysis(widget.matchId);
  }

  void _reload() {
    setState(() {
      _analysisFuture = _apiService.getMatchAnalysis(widget.matchId);
    });
  }

  Widget _formRow(String label, TeamForm form) {
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

  Widget _headToHeadCard(HeadToHead h2h) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.homeTeam} vs ${widget.awayTeam}")),
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
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text("Réessayer"),
                    ),
                  ],
                ),
              ),
            );
          }

          final analysis = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _formRow(analysis.homeTeam, analysis.home),
              _formRow(analysis.awayTeam, analysis.away),
              _headToHeadCard(analysis.headToHead),
              const SizedBox(height: 12),
              const Text(
                "Ces chiffres reflètent les performances récentes enregistrées, sans garantir un résultat.",
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}
