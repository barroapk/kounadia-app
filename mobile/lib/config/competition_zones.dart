import "package:flutter/material.dart";

class CompetitionZoneRules {
  final int championsLeagueSpots;
  final int europaLeagueSpots; // places supplémentaires après la Champions League
  final int relegationSpots;

  const CompetitionZoneRules({
    this.championsLeagueSpots = 0,
    this.europaLeagueSpots = 0,
    this.relegationSpots = 0,
  });
}

// Règles approximatives des 5 grands championnats, à ajuster manuellement
// si les formats changent d'une saison à l'autre (barrages, coupes qualificatives...).
const Map<String, CompetitionZoneRules> COMPETITION_ZONES = {
  'PL': CompetitionZoneRules(championsLeagueSpots: 4, europaLeagueSpots: 2, relegationSpots: 3),
  'PD': CompetitionZoneRules(championsLeagueSpots: 4, europaLeagueSpots: 2, relegationSpots: 3),
  'SA': CompetitionZoneRules(championsLeagueSpots: 4, europaLeagueSpots: 2, relegationSpots: 3),
  'BL1': CompetitionZoneRules(championsLeagueSpots: 4, europaLeagueSpots: 2, relegationSpots: 2),
  'FL1': CompetitionZoneRules(championsLeagueSpots: 3, europaLeagueSpots: 2, relegationSpots: 2),
};

Color? zoneColorFor(String competitionCode, int position, int totalTeams) {
  final rules = COMPETITION_ZONES[competitionCode];
  if (rules == null) return null;

  if (position <= rules.championsLeagueSpots) return const Color(0xFF2563EB); // bleu
  if (position <= rules.championsLeagueSpots + rules.europaLeagueSpots) {
    return const Color(0xFFF97316); // orange
  }
  if (position > totalTeams - rules.relegationSpots) return const Color(0xFFDC2626); // rouge
  return null;
}
