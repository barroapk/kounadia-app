import "package:flutter/material.dart";
import "../models/match_analysis.dart";

class MatchSummaryCard extends StatefulWidget {
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

  @override
  State<MatchSummaryCard> createState() => _MatchSummaryCardState();
}

class _MatchSummaryCardState extends State<MatchSummaryCard> {
  bool _expanded = false;

  double? _asNumber(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString().replaceAll('%', ''));
  }

  List<String> _buildPoints() {
    final points = <String>[];
    final stats = widget.statistics;

    if (stats != null) {
      final homePos = _asNumber(stats.home['Ball Possession']);
      final awayPos = _asNumber(stats.away['Ball Possession']);
      if (homePos != null && awayPos != null && (homePos - awayPos).abs() >= 15) {
        final leader = homePos > awayPos ? widget.homeTeam : widget.awayTeam;
        points.add("$leader a dominé la possession (${homePos.round()}% contre ${awayPos.round()}%).");
      }

      final homeXg = _asNumber(stats.home['expected_goals']);
      final awayXg = _asNumber(stats.away['expected_goals']);
      if (homeXg != null && awayXg != null && (homeXg - awayXg).abs() >= 0.8) {
        final leader = homeXg > awayXg ? widget.homeTeam : widget.awayTeam;
        points.add(
          "$leader a créé plus d'occasions dangereuses (xG ${homeXg.toStringAsFixed(2)} contre ${awayXg.toStringAsFixed(2)}).",
        );
      }

      final homeShots = _asNumber(stats.home['Total Shots']);
      final awayShots = _asNumber(stats.away['Total Shots']);
      if (homeShots != null && awayShots != null && (homeShots - awayShots).abs() >= 8) {
        final leader = homeShots > awayShots ? widget.homeTeam : widget.awayTeam;
        points.add(
          "$leader a tiré nettement plus souvent (${homeShots.round()} tirs contre ${awayShots.round()}).",
        );
      }
    }

    final evs = widget.events;
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

    final visiblePoints = _expanded ? points : points.take(1).toList();
    final hiddenCount = points.length - visiblePoints.length;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                const Text("Résumé du match", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            ...visiblePoints.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text("• $p", style: const TextStyle(fontSize: 12.5)),
                )),
            if (_expanded)
              InkWell(
                onTap: () => setState(() => _expanded = false),
                child: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    "Voir moins",
                    style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else if (hiddenCount > 0)
              InkWell(
                onTap: () => setState(() => _expanded = true),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Voir $hiddenCount de plus",
                    style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
