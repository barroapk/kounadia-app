// Codes ISO utilisés pour récupérer les drapeaux via flagcdn.com (gratuit, sans clé).
const Map<String, String> COUNTRY_FLAG_CODES = {
  "Angleterre": "gb",
  "Espagne": "es",
  "Allemagne": "de",
  "Italie": "it",
  "France": "fr",
  "Pays-Bas": "nl",
  "Portugal": "pt",
  "Brésil": "br",
  "Belgique": "be",
  "Turquie": "tr",
  "Burkina Faso": "bf",
  "Côte d'Ivoire": "ci",
  "Sénégal": "sn",
  "Mali": "ml",
  "Ghana": "gh",
  "Nigeria": "ng",
  "Maroc": "ma",
  "Algérie": "dz",
  "Tunisie": "tn",
  "Égypte": "eg",
  "Afrique du Sud": "za",
  "Argentine": "ar",
  "Mexique": "mx",
  "États-Unis": "us",
  "Arabie Saoudite": "sa",
  "Japon": "jp",
};

String? flagUrlFor(String country) {
  final code = COUNTRY_FLAG_CODES[country];
  if (code == null) return null;
  return "https://flagcdn.com/w40/$code.png";
}
