import "package:flutter/material.dart";
import "../models/match.dart";
import "../widgets/match_card.dart";

class DesignPreviewScreen extends StatelessWidget {
  const DesignPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sampleMatches = [
      Match(
        id: 1,
        competition: "Ligue 1",
        homeTeam: "Paris Saint-Germain",
        awayTeam: "Olympique de Marseille",
        homeScore: null,
        awayScore: null,
        status: "TIMED",
        minute: null,
        utcDate: DateTime.now().toIso8601String(),
      ),
      Match(
        id: 2,
        competition: "UEFA Champions League",
        homeTeam: "FC Barcelone",
        awayTeam: "Real Madrid",
        homeScore: 2,
        awayScore: 1,
        status: "IN_PLAY",
        minute: 67,
        utcDate: DateTime.now().toIso8601String(),
      ),
      Match(
        id: 3,
        competition: "Ligue 1 Burkina Faso",
        homeTeam: "Rail Club du Kadiogo",
        awayTeam: "ASFA Yennenga",
        homeScore: 1,
        awayScore: 1,
        status: "FINISHED",
        minute: null,
        utcDate: DateTime.now().toIso8601String(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Aperçu design (temporaire)")),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sampleMatches.length,
        itemBuilder: (context, index) {
          return MatchCard(match: sampleMatches[index], onTap: () {});
        },
      ),
    );
  }
}
