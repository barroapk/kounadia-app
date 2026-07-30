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
        return Icons.square_rounded;
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
        return Colors.grey[500]!;
      default:
        return Colors.grey;
    }
  }

  String _minuteLabel(MatchEvent e) {
    final base = e.minute ?? 0;
    return e.extraMinute != null ? "$base+${e.extraMinute}'" : "$base'";
  }

  Widget _eventDetails(MatchEvent e, {required bool alignRight}) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          e.player ?? "",
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
        if (e.assist != null)
          Text(
            e.type == "subst" ? "Sort : ${e.assist}" : "Passe : ${e.assist}",
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        if (e.team != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              e.team!,
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(child: Text("Aucun événement disponible pour ce match."));
    }

    final sorted = List<MatchEvent>.from(events)
      ..sort((a, b) {
        final ta = (a.minute ?? 0) * 100 + (a.extraMinute ?? 0);
        final tb = (b.minute ?? 0) * 100 + (b.extraMinute ?? 0);
        return tb.compareTo(ta);
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final e = sorted[index];
        final isHome = e.team == homeTeam;
        final isFirst = index == 0;
        final isLast = index == sorted.length - 1;

        return SizedBox(
          height: 58,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: isHome ? _eventDetails(e, alignRight: true) : const SizedBox.shrink(),
                  ),
                ),
              ),
              SizedBox(
                width: 46,
                child: Column(
                  children: [
                    Expanded(
                      child: isFirst
                          ? const SizedBox()
                          : Container(width: 2, color: Colors.grey[300]),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _minuteLabel(e),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: e.extraMinute != null ? const Color(0xFFDC2626) : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: _colorFor(e), width: 2),
                          ),
                          child: Icon(_iconFor(e), size: 13, color: _colorFor(e)),
                        ),
                      ],
                    ),
                    Expanded(
                      child: isLast
                          ? const SizedBox()
                          : Container(width: 2, color: Colors.grey[300]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: !isHome ? _eventDetails(e, alignRight: false) : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
