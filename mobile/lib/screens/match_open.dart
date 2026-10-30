import 'package:flutter/material.dart';
import '../models/live_match.dart';
import '../services/scores_service.dart';
import '../widgets/premium_gate.dart';
import 'pt_match_screen.dart';

/// Ouvre l'analyse d'un match (même accès Premium que depuis l'onglet Matchs).
Future<void> openMatch(BuildContext context, LiveMatch m) async {
  // Match venu de footlive (numéro négatif) : pas de fiche d'analyse.
  if (m.id < 0) return;
  await _openMatch(context, m);
}

Future<void> _openMatch(BuildContext context, LiveMatch m) => Navigator.push(
    context,
    MaterialPageRoute(
        builder: (_) => PremiumGate(
            standalone: true,
            title: "Analyse du match",
            pitch: "Statistiques, forme, confrontations et marchés détaillés pour chaque match.",
            perks: [
              "Probabilités et cotes : 1X2, buts, les deux marquent",
              "Forme récente et classement",
              "Confrontations directes",
              "Analyse KOUNADIA du match"
            ],
            icon: Icons.query_stats_rounded,
            child: PtMatchScreen(match: m))));

/// Retrouve un match par son numéro (notification touchée) puis l'ouvre.
Future<void> openMatchId(BuildContext context, int id) async {
  try {
    final (days, _) = await ScoresService.load();
    for (final l in days.values) {
      for (final m in l) {
        if (m.id == id) {
          if (context.mounted) await openMatch(context, m);
          return;
        }
      }
    }
  } catch (_) {}
}
