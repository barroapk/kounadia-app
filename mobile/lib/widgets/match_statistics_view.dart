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

  // Ces 4 indicateurs sont mis en avant dans des cartes dédiées.
  static const List<String> _keyStats = [
    "Ball Possession",
    "expected_goals",
    "Total Shots",
    "Shots on Goal",
  ];

  static const Map<String, String> _keyLabels = {
    "Ball Possession": "Possession",
    "expected_goals": "xG (buts attendus)",
    "Total Shots": "Tirs",
    "Shots on Goal": "Tirs cadrés",
  };

  static const List<String> _secondaryOrder = [
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

  double? _asNumber(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString().replaceAll('%', ''));
  }

  Widget _keyStatCard(String label, dynamic homeValue, dynamic awayValue) {
    final homeNum = _asNumber(homeValue) ?? 0;
    final awayNum = _asNumber(awayValue) ?? 0;
    final total = homeNum + awayNum;
    final homeRatio = total > 0 ? homeNum / total : 0.5;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${homeValue ?? '-'}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF16A34A)),
              ),
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
              Text(
                "${awayValue ?? '-'}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: (homeRatio * 100).round().clamp(1, 99),
                  child: Container(height: 8, color: const Color(0xFF16A34A)),
                ),
                Expanded(
                  flex: (100 - (homeRatio * 100).round()).clamp(1, 99),
                  child: Container(height: 8, color: Colors.grey[300]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _secondaryRow(String label, dynamic homeValue, dynamic awayValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text("${homeValue ?? '-'}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(
            child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ),
          SizedBox(
            width: 40,
            child: Text("${awayValue ?? '-'}", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allKeys = <String>{...statistics.home.keys, ...statistics.away.keys};
    if (allKeys.isEmpty) {
      return const Center(child: Text("Statistiques indisponibles pour ce match."));
    }

    final availableKeyStats = _keyStats.where((k) => allKeys.contains(k)).toList();
    final secondaryKeys = <String>[];
    for (final key in _secondaryOrder) {
      if (allKeys.contains(key)) secondaryKeys.add(key);
    }
    for (final key in allKeys) {
      if (!_keyStats.contains(key) && !secondaryKeys.contains(key)) secondaryKeys.add(key);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...availableKeyStats.map(
          (key) => _keyStatCard(_keyLabels[key] ?? key, statistics.home[key], statistics.away[key]),
        ),
        if (secondaryKeys.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "AUTRES STATISTIQUES",
              style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: secondaryKeys
                  .map((key) => _secondaryRow(key, statistics.home[key], statistics.away[key]))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}
