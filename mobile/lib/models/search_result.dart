enum SearchResultType { competition, country, continent, team }

class SearchResult {
  final SearchResultType type;
  final String value;
  final String label;

  SearchResult({required this.type, required this.value, required this.label});
}
