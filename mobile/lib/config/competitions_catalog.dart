class CompetitionInfo {
  final String name;
  final String continent;
  final String country;
  final String? code; // Code football-data.org
  final int? leagueId; // ID API-Football

  const CompetitionInfo({
    required this.name,
    required this.continent,
    required this.country,
    this.code,
    this.leagueId,
  });
}

const List<CompetitionInfo> COMPETITIONS_CATALOG = [
  // Europe - football-data.org (avec code, classement disponible)
  CompetitionInfo(name: "Premier League", continent: "Europe", country: "Angleterre", code: "PL"),
  CompetitionInfo(name: "Championship", continent: "Europe", country: "Angleterre", code: "ELC"),
  CompetitionInfo(name: "Primera Division", continent: "Europe", country: "Espagne", code: "PD"),
  CompetitionInfo(name: "Bundesliga", continent: "Europe", country: "Allemagne", code: "BL1"),
  CompetitionInfo(name: "Serie A", continent: "Europe", country: "Italie", code: "SA"),
  CompetitionInfo(name: "Ligue 1", continent: "Europe", country: "France", code: "FL1"),
  CompetitionInfo(name: "Eredivisie", continent: "Europe", country: "Pays-Bas", code: "DED"),
  CompetitionInfo(name: "Primeira Liga", continent: "Europe", country: "Portugal", code: "PPL"),
  CompetitionInfo(name: "UEFA Champions League", continent: "Europe", country: "International", code: "CL"),
  CompetitionInfo(name: "European Championship", continent: "Europe", country: "International", code: "EC"),
  CompetitionInfo(name: "Campeonato Brasileiro Série A", continent: "Amériques", country: "Brésil", code: "BSA"),
  CompetitionInfo(name: "FIFA World Cup", continent: "Monde", country: "International", code: "WC"),

  // Europe - API-Football (pas de code football-data.org, classement non disponible pour l'instant)
  CompetitionInfo(name: "Europa League", leagueId: 3, continent: "Europe", country: "International"),
  CompetitionInfo(name: "Conference League", leagueId: 848, continent: "Europe", country: "International"),
  CompetitionInfo(name: "FA Cup", leagueId: 45, continent: "Europe", country: "Angleterre"),
  CompetitionInfo(name: "Copa del Rey", leagueId: 143, continent: "Europe", country: "Espagne"),
  CompetitionInfo(name: "Coppa Italia", leagueId: 137, continent: "Europe", country: "Italie"),
  CompetitionInfo(name: "DFB Pokal", leagueId: 81, continent: "Europe", country: "Allemagne"),
  CompetitionInfo(name: "Coupe de France", leagueId: 66, continent: "Europe", country: "France"),
  CompetitionInfo(name: "Jupiler Pro League", leagueId: 144, continent: "Europe", country: "Belgique"),
  CompetitionInfo(name: "Supercoupe d'Espagne", leagueId: 558, continent: "Europe", country: "Espagne"),
  CompetitionInfo(name: "UEFA Super Cup", leagueId: 531, continent: "Europe", country: "International"),
  CompetitionInfo(name: "2. Bundesliga", leagueId: 79, continent: "Europe", country: "Allemagne"),
  CompetitionInfo(name: "Serie B (Italie)", leagueId: 136, continent: "Europe", country: "Italie"),
  CompetitionInfo(name: "Segunda División (Espagne)", leagueId: 141, continent: "Europe", country: "Espagne"),
  CompetitionInfo(name: "Süper Lig (Turquie)", leagueId: 203, continent: "Europe", country: "Turquie"),

  // Afrique
  CompetitionInfo(name: "CAF Champions League", leagueId: 12, continent: "Afrique", country: "International"),
  CompetitionInfo(name: "CAF Confederation Cup", leagueId: 20, continent: "Afrique", country: "International"),
  CompetitionInfo(name: "CAN", leagueId: 6, continent: "Afrique", country: "International"),
  CompetitionInfo(name: "Ligue 1 Burkina Faso", leagueId: 423, continent: "Afrique", country: "Burkina Faso"),
  CompetitionInfo(name: "Ligue 1 Côte d'Ivoire", leagueId: 386, continent: "Afrique", country: "Côte d'Ivoire"),
  CompetitionInfo(name: "Ligue 1 Sénégal", leagueId: 403, continent: "Afrique", country: "Sénégal"),
  CompetitionInfo(name: "Première Division Mali", leagueId: 598, continent: "Afrique", country: "Mali"),
  CompetitionInfo(name: "Ghana Premier League", leagueId: 570, continent: "Afrique", country: "Ghana"),
  CompetitionInfo(name: "NPFL Nigeria", leagueId: 399, continent: "Afrique", country: "Nigeria"),
  CompetitionInfo(name: "Botola Pro", leagueId: 200, continent: "Afrique", country: "Maroc"),
  CompetitionInfo(name: "Ligue 1 Algérie", leagueId: 186, continent: "Afrique", country: "Algérie"),
  CompetitionInfo(name: "Ligue 1 Tunisie", leagueId: 202, continent: "Afrique", country: "Tunisie"),
  CompetitionInfo(name: "Egyptian Premier League", leagueId: 233, continent: "Afrique", country: "Égypte"),
  CompetitionInfo(name: "Premier Soccer League (Afrique du Sud)", leagueId: 288, continent: "Afrique", country: "Afrique du Sud"),

  // Amériques
  CompetitionInfo(name: "Copa do Brasil", leagueId: 73, continent: "Amériques", country: "Brésil"),
  CompetitionInfo(name: "Liga Profesional Argentina", leagueId: 128, continent: "Amériques", country: "Argentine"),
  CompetitionInfo(name: "CONMEBOL Libertadores", leagueId: 13, continent: "Amériques", country: "International"),
  CompetitionInfo(name: "CONMEBOL Sudamericana", leagueId: 11, continent: "Amériques", country: "International"),
  CompetitionInfo(name: "Liga MX", leagueId: 262, continent: "Amériques", country: "Mexique"),
  CompetitionInfo(name: "MLS", leagueId: 253, continent: "Amériques", country: "États-Unis"),
  CompetitionInfo(name: "Copa America", leagueId: 9, continent: "Amériques", country: "International"),

  // Asie / Moyen-Orient
  CompetitionInfo(name: "Saudi Pro League", leagueId: 307, continent: "Asie", country: "Arabie Saoudite"),
  CompetitionInfo(name: "J1 League", leagueId: 98, continent: "Asie", country: "Japon"),
  CompetitionInfo(name: "AFC Champions League Elite", leagueId: 17, continent: "Asie", country: "International"),
  CompetitionInfo(name: "King's Cup (Arabie Saoudite)", leagueId: 504, continent: "Asie", country: "Arabie Saoudite"),

  // Monde
  CompetitionInfo(name: "FIFA Club World Cup", leagueId: 15, continent: "Monde", country: "International"),
];

// Rang d'affichage : plus petit = affiché en premier (D1 avant D2 avant coupes).
const Map<String, int> COMPETITION_DISPLAY_RANK = {
  "Premier League": 1,
  "Primera Division": 1,
  "Bundesliga": 1,
  "Serie A": 1,
  "Ligue 1": 1,
  "Eredivisie": 1,
  "Primeira Liga": 1,
  "Campeonato Brasileiro Série A": 1,
  "Jupiler Pro League": 1,
  "Süper Lig (Turquie)": 1,
  "Saudi Pro League": 1,
  "J1 League": 1,
  "Liga MX": 1,
  "MLS": 1,
  "Liga Profesional Argentina": 1,
  "Ligue 1 Burkina Faso": 1,
  "Ligue 1 Côte d'Ivoire": 1,
  "Ligue 1 Sénégal": 1,
  "Première Division Mali": 1,
  "Ghana Premier League": 1,
  "NPFL Nigeria": 1,
  "Botola Pro": 1,
  "Ligue 1 Algérie": 1,
  "Ligue 1 Tunisie": 1,
  "Egyptian Premier League": 1,
  "Premier Soccer League (Afrique du Sud)": 1,
  "Championship": 2,
  "2. Bundesliga": 2,
  "Serie B (Italie)": 2,
  "Segunda División (Espagne)": 2,
  "FA Cup": 3,
  "Copa del Rey": 3,
  "Coppa Italia": 3,
  "DFB Pokal": 3,
  "Coupe de France": 3,
  "Supercoupe d'Espagne": 3,
  "UEFA Champions League": 4,
  "Europa League": 4,
  "Conference League": 4,
  "UEFA Super Cup": 4,
  "CAF Champions League": 4,
  "CAF Confederation Cup": 4,
  "CONMEBOL Libertadores": 4,
  "CONMEBOL Sudamericana": 4,
  "AFC Champions League Elite": 4,
  "FIFA Club World Cup": 4,
  "Copa do Brasil": 4,
  "FIFA World Cup": 5,
  "European Championship": 5,
  "CAN": 5,
  "Copa America": 5,
};

int competitionRank(String name) => COMPETITION_DISPLAY_RANK[name] ?? 50;
