import "package:flutter/material.dart";
import "../models/match_analysis.dart";

Widget buildFormBar(String label, TeamForm form) {
  final total = form.matchesAnalyzed;
  if (total == 0) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text("$label : pas assez de données.", style: const TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              if (form.wins > 0) Expanded(flex: form.wins, child: Container(height: 10, color: const Color(0xFF16A34A))),
              if (form.draws > 0) Expanded(flex: form.draws, child: Container(height: 10, color: Colors.grey[400])),
              if (form.losses > 0) Expanded(flex: form.losses, child: Container(height: 10, color: const Color(0xFFDC2626))),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text("${form.wins}V ${form.draws}N ${form.losses}D sur $total match(s)",
            style: TextStyle(color: Colors.grey[600], fontSize: 11)),
      ],
    ),
  );
}

Widget buildHeadToHeadBar(HeadToHead h2h) {
  if (!h2h.available || (h2h.totalMatches ?? 0) == 0) {
    return const Text("Aucun historique de confrontation disponible.", style: TextStyle(fontSize: 12, color: Colors.grey));
  }

  final winsA = h2h.teamAWins ?? 0;
  final draws = h2h.draws ?? 0;
  final winsB = h2h.teamBWins ?? 0;
  final teamAName = h2h.teamA ?? "Équipe A";
  final teamBName = h2h.teamB ?? "Équipe B";

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$winsA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF16A34A))),
          Text("$draws nuls", style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
          Text("$winsB", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            if (winsA > 0) Expanded(flex: winsA, child: Container(height: 10, color: const Color(0xFF16A34A))),
            if (draws > 0) Expanded(flex: draws, child: Container(height: 10, color: Colors.grey[400])),
            if (winsB > 0) Expanded(flex: winsB, child: Container(height: 10, color: Colors.grey[700])),
          ],
        ),
      ),
      const SizedBox(height: 4),
      Text(
        "$teamAName : $winsA victoire(s) · $teamBName : $winsB victoire(s) · $draws nul(s) · ${h2h.totalMatches} confrontation(s) au total",
        style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
      ),
    ],
  );
}
