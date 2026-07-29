import "package:flutter/material.dart";

class MatchInfoCard extends StatelessWidget {
  final String? venue;
  final String? referee;

  const MatchInfoCard({super.key, this.venue, this.referee});

  @override
  Widget build(BuildContext context) {
    if (venue == null && referee == null) return const SizedBox.shrink();

    Widget row(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(width: 4),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (venue != null) row(Icons.stadium_outlined, "Stade", venue!),
          if (referee != null) row(Icons.sports_outlined, "Arbitre", referee!),
        ],
      ),
    );
  }
}
