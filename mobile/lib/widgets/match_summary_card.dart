import "package:flutter/material.dart";
import "../models/match_analysis.dart";

class MatchSummaryCard extends StatelessWidget {
  final MatchStatistics? statistics;
  final List<MatchEvent>? events;
  final String homeTeam;
  final String awayTeam;

  const MatchSummaryCard({
    super.key,
    this.statistics,
    this.events,
    required this.homeTeam,
    required this.awayTeam,
  });

  double? _asNumber(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString().replaceAll('%', ''));
  }

  List<String> _buildPoints() {
    final points = <String>[];
    final stats = statistics;

    if (stats != null) {
      final homePos = _asNumber(stats.home['Ball Possession']);
      final awayPos = _asNumber(stats.away['Ball Possession']);
      if (homePos != null && awayPos != null && (homePos - awayPos).abs() >= 15) {
        final leader = homePos > awayPos ? homeTeam : awayTeam;
        points.add("$leader a dominé la possession (${homePos.round()}% contre ${awayPos.round()}%).");
      }

      final homeXg = _asNumber(stats.home['expected_goals']);
      final awayXg = _asNumber(stats.away['expected_goals']);
      if (homeXg != null && awayXg != null && (homeXg - awayXg).abs() >= 0.8) {
        final leader = homeXg > awayXg ? homeTeam : awayTeam;
        points.add(
          "$leader a créé plus d'occasions dangereuses (xG ${homeXg.toStringAsFixed(2)} contre ${awayXg.toStringAsFixed(2)}).",
        );
      }

      final homeShots = _asNumber(stats.home['Total Shots']);
      final awayShots = _asNumber(stats.away['Total Shots']);
      if (homeShots != null && awayShots != null && (homeShots - awayShots).abs() >= 8) {
        final leader = homeShots > awayShots ? homeTeam : awayTeam;
        points.add(
          "$leader a tiré nettement plus souvent (${homeShots.round()} tirs contre ${awayShots.round()}).",
        );
      }
    }

    final evs = events;
    if (evs != null) {
      for (final e in evs) {
        if (e.type == "Card" && e.detail == "Red Card") {
          points.add("${e.team} a terminé en infériorité numérique (carton rouge, ${e.player}, ${e.minute}').");
        }
      }
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    if (points.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Résumé du match", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...points.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text("• $p", style: const TextStyle(fontSize: 13)),
                )),
          ],
        ),
      ),
    );
  }
}
