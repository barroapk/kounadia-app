class CompetitionInfo {
  final String name;
  final String continent;
  final String country;

  const CompetitionInfo({
    required this.name,
    required this.continent,
    required this.country,
  });
}

// Ces noms doivent correspondre EXACTEMENT à ce que renvoie le backend
// (champ "competition" de chaque match), sinon le filtre ne fonctionnera pas.
const List<CompetitionInfo> COMPETITIONS_CATALOG = [
  // Europe - football-data.org
  CompetitionInfo(name: "Premier League", continent: "Europe", country: "Angleterre"),
  CompetitionInfo(name: "Championship", continent: "Europe", country: "Angleterre"),
  CompetitionInfo(name: "Primera Division", continent: "Europe", country: "Espagne"),
  CompetitionInfo(name: "Bundesliga", continent: "Europe", country: "Allemagne"),
  CompetitionInfo(name: "Serie A", continent: "Europe", country: "Italie"),
  CompetitionInfo(name: "Ligue 1", continent: "Europe", country: "France"),
  CompetitionInfo(name: "Eredivisie", continent: "Europe", country: "Pays-Bas"),
  CompetitionInfo(name: "Primeira Liga", continent: "Europe", country: "Portugal"),
  CompetitionInfo(name: "UEFA Champions League", continent: "Europe", country: "International"),
  CompetitionInfo(name: "European Championship", continent: "Europe", country: "International"),
  CompetitionInfo(name: "Campeonato Brasileiro Série A", continent: "Amériques", country: "Brésil"),
  CompetitionInfo(name: "FIFA World Cup", continent: "Monde", country: "International"),

  // Europe - API-Football
  CompetitionInfo(name: "Europa League", continent: "Europe", country: "International"),
  CompetitionInfo(name: "Conference League", continent: "Europe", country: "International"),
  CompetitionInfo(name: "FA Cup", continent: "Europe", country: "Angleterre"),
  CompetitionInfo(name: "Copa del Rey", continent: "Europe", country: "Espagne"),
  CompetitionInfo(name: "Coppa Italia", continent: "Europe", country: "Italie"),
  CompetitionInfo(name: "DFB Pokal", continent: "Europe", country: "Allemagne"),
  CompetitionInfo(name: "Coupe de France", continent: "Europe", country: "France"),
  CompetitionInfo(name: "Jupiler Pro League", continent: "Europe", country: "Belgique"),
  CompetitionInfo(name: "Supercoupe d'Espagne", continent: "Europe", country: "Espagne"),
  CompetitionInfo(name: "UEFA Super Cup", continent: "Europe", country: "International"),
  CompetitionInfo(name: "2. Bundesliga", continent: "Europe", country: "Allemagne"),
  CompetitionInfo(name: "Serie B (Italie)", continent: "Europe", country: "Italie"),
  CompetitionInfo(name: "Segunda División (Espagne)", continent: "Europe", country: "Espagne"),
  CompetitionInfo(name: "Süper Lig (Turquie)", continent: "Europe", country: "Turquie"),

  // Afrique
  CompetitionInfo(name: "CAF Champions League", continent: "Afrique", country: "International"),
  CompetitionInfo(name: "CAF Confederation Cup", continent: "Afrique", country: "International"),
  CompetitionInfo(name: "CAN", continent: "Afrique", country: "International"),
  CompetitionInfo(name: "Ligue 1 Burkina Faso", continent: "Afrique", country: "Burkina Faso"),
  CompetitionInfo(name: "Ligue 1 Côte d'Ivoire", continent: "Afrique", country: "Côte d'Ivoire"),
  CompetitionInfo(name: "Ligue 1 Sénégal", continent: "Afrique", country: "Sénégal"),
  CompetitionInfo(name: "Première Division Mali", continent: "Afrique", country: "Mali"),
  CompetitionInfo(name: "Ghana Premier League", continent: "Afrique", country: "Ghana"),
  CompetitionInfo(name: "NPFL Nigeria", continent: "Afrique", country: "Nigeria"),
  CompetitionInfo(name: "Botola Pro", continent: "Afrique", country: "Maroc"),
  CompetitionInfo(name: "Ligue 1 Algérie", continent: "Afrique", country: "Algérie"),
  CompetitionInfo(name: "Ligue 1 Tunisie", continent: "Afrique", country: "Tunisie"),
  CompetitionInfo(name: "Egyptian Premier League", continent: "Afrique", country: "Égypte"),
  CompetitionInfo(name: "Premier Soccer League (Afrique du Sud)", continent: "Afrique", country: "Afrique du Sud"),

  // Amériques
  CompetitionInfo(name: "Copa do Brasil", continent: "Amériques", country: "Brésil"),
  CompetitionInfo(name: "Liga Profesional Argentina", continent: "Amériques", country: "Argentine"),
  CompetitionInfo(name: "CONMEBOL Libertadores", continent: "Amériques", country: "International"),
  CompetitionInfo(name: "CONMEBOL Sudamericana", continent: "Amériques", country: "International"),
  CompetitionInfo(name: "Liga MX", continent: "Amériques", country: "Mexique"),
  CompetitionInfo(name: "MLS", continent: "Amériques", country: "États-Unis"),
  CompetitionInfo(name: "Copa America", continent: "Amériques", country: "International"),

  // Asie / Moyen-Orient
  CompetitionInfo(name: "Saudi Pro League", continent: "Asie", country: "Arabie Saoudite"),
  CompetitionInfo(name: "J1 League", continent: "Asie", country: "Japon"),
  CompetitionInfo(name: "AFC Champions League Elite", continent: "Asie", country: "International"),
  CompetitionInfo(name: "King's Cup (Arabie Saoudite)", continent: "Asie", country: "Arabie Saoudite"),

  // Monde
  CompetitionInfo(name: "FIFA Club World Cup", continent: "Monde", country: "International"),
];
