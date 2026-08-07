/// Construit le suffixe a afficher a cote du score pour un match termine
/// apres prolongation (AET) ou aux tirs au but (PEN), avec le score de la
/// seance quand disponible. Retourne une chaine vide si le match s'est
/// decide en 90 minutes normales.
String wonAfterLabel({
  required String? wonAfter,
  int? penaltyHomeScore,
  int? penaltyAwayScore,
}) {
  if (wonAfter == 'AET') return " (PROL.)";
  if (wonAfter == 'PEN') {
    if (penaltyHomeScore != null && penaltyAwayScore != null) {
      return " (TAB $penaltyHomeScore-$penaltyAwayScore)";
    }
    return " (TAB)";
  }
  return "";
}
