import "package:flutter/material.dart";
import "../models/match_analysis.dart";

class MatchTimelineView extends StatelessWidget {
  final List<MatchEvent> events;
  final String homeTeam;

  const MatchTimelineView({super.key, required this.events, required this.homeTeam});

  IconData _iconFor(MatchEvent e) {
    switch (e.type) {
      case "Goal":
        return Icons.sports_soccer;
      case "Card":
        return e.detail == "Red Card" ? Icons.square : Icons.square_outlined;
      case "subst":
        return Icons.swap_horiz;
      default:
        return Icons.circle;
    }
  }

  Color _colorFor(MatchEvent e) {
    switch (e.type) {
      case "Goal":
        return const Color(0xFF16A34A);
      case "Card":
        return e.detail == "Red Card" ? const Color(0xFFDC2626) : const Color(0xFFEAB308);
      case "subst":
        return Colors.grey[600]!;
      default:
        return Colors.grey;
    }
  }

  String _minuteLabel(MatchEvent e) {
    final base = e.minute ?? 0;
    return e.extraMinute != null ? "$base+${e.extraMinute}'" : "$base'";
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(child: Text("Aucun événement disponible pour ce match."));
    }

    // Ordre chronologique inverse : le plus récent en haut, plus naturel pour un match en cours/terminé.
    final sorted = List<MatchEvent>.from(events)
      ..sort((a, b) => (b.minute ?? 0).compareTo(a.minute ?? 0));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final e = sorted[index];
        final isHome = e.team == homeTeam;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  _minuteLabel(e),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: e.extraMinute != null ? const Color(0xFFDC2626) : Colors.black87,
                  ),
                ),
              ),
              Icon(_iconFor(e), size: 16, color: _colorFor(e)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: isHome ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Text(
                      e.player ?? "",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (e.assist != null)
                      Text(
                        e.type == "subst" ? "Sort : ${e.assist}" : "Passe : ${e.assist}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
