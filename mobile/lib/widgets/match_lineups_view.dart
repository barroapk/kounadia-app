import "package:flutter/material.dart";
import "../models/match_analysis.dart";

class MatchLineupsView extends StatelessWidget {
  final List<LineupEntry> lineups;

  const MatchLineupsView({super.key, required this.lineups});

  Widget _teamCard(LineupEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.team ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            if (entry.formation != null)
              Text("Formation : ${entry.formation}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            if (entry.coach != null)
              Text("Entraîneur : ${entry.coach}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text("Titulaires (${entry.startXI.length})", style: const TextStyle(fontSize: 13)),
              children: entry.startXI
                  .map((p) => ListTile(
                        dense: true,
                        leading: Text("${p.number ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        title: Text(p.name ?? "", style: const TextStyle(fontSize: 13)),
                        trailing: Text(p.position ?? "", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ))
                  .toList(),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text("Remplaçants (${entry.substitutes.length})", style: const TextStyle(fontSize: 13)),
              children: entry.substitutes
                  .map((p) => ListTile(
                        dense: true,
                        leading: Text("${p.number ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        title: Text(p.name ?? "", style: const TextStyle(fontSize: 13)),
                        trailing: Text(p.position ?? "", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (lineups.isEmpty) {
      return const Center(child: Text("Compositions pas encore publiées."));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: lineups.map(_teamCard).toList(),
    );
  }
}
