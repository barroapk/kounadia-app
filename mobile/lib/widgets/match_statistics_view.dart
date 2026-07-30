import "package:flutter/material.dart";
import "../models/match_analysis.dart";

class MatchStatisticsView extends StatelessWidget {
  final MatchStatistics statistics;
  final String homeTeam;
  final String awayTeam;

  const MatchStatisticsView({
    super.key,
    required this.statistics,
    required this.homeTeam,
    required this.awayTeam,
  });

  // Ordre d'importance pour l'utilisateur : les stats les plus lues en premier,
  // celles reçues mais moins prioritaires (hors-jeu, fautes) en dernier.
  static const List<String> _priorityOrder = [
    "Ball Possession",
    "expected_goals",
    "Total Shots",
    "Shots on Goal",
    "Shots off Goal",
    "Blocked Shots",
    "Shots insidebox",
    "Shots outsidebox",
    "Corner Kicks",
    "Passes %",
    "Total passes",
    "Passes accurate",
    "Goalkeeper Saves",
    "Yellow Cards",
    "Red Cards",
    "Fouls",
    "Offsides",
    "goals_prevented",
  ];

  List<String> _sortedKeys(Set<String> keys) {
    final sorted = <String>[];
    for (final key in _priorityOrder) {
      if (keys.contains(key)) sorted.add(key);
    }
    for (final key in keys) {
      if (!sorted.contains(key)) sorted.add(key);
    }
    return sorted;
  }

  double? _asPercent(dynamic value) {
    if (value == null) return null;
    final str = value.toString().replaceAll('%', '');
    return double.tryParse(str);
  }

  Widget _row(String label, dynamic homeValue, dynamic awayValue) {
    final homePercent = _asPercent(homeValue);
    final awayPercent = _asPercent(awayValue);
    final showBar = homePercent != null && awayPercent != null && (homePercent + awayPercent) > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  "${homeValue ?? '-'}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  "${awayValue ?? '-'}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          if (showBar) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: (homePercent * 10).round().clamp(1, 1000),
                  child: Container(height: 4, color: const Color(0xFF16A34A)),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: (awayPercent * 10).round().clamp(1, 1000),
                  child: Container(height: 4, color: Colors.grey[300]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = _sortedKeys({...statistics.home.keys, ...statistics.away.keys});

    if (keys.isEmpty) {
      return const Center(child: Text("Statistiques indisponibles pour ce match."));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: keys.map((key) => _row(key, statistics.home[key], statistics.away[key])).toList(),
    );
  }
}
