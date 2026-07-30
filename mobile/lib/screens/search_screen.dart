import "package:flutter/material.dart";
import "../config/competitions_catalog.dart";
import "../models/search_result.dart";

class SearchScreen extends StatefulWidget {
  final List<String> availableTeams;

  const SearchScreen({super.key, this.availableTeams = const []});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = "";

  late final List<String> _continents;
  late final List<String> _countries;

  @override
  void initState() {
    super.initState();
    _continents = COMPETITIONS_CATALOG.map((c) => c.continent).toSet().toList();
    _countries = COMPETITIONS_CATALOG
        .map((c) => c.country)
        .where((c) => c != "International")
        .toSet()
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Retire les accents pour une comparaison insensible ("Égypte" == "egypte").
  String _normalize(String text) {
    const withAccents = 'àáâãäåèéêëìíîïòóôõöùúûüçñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇÑ';
    const withoutAccents = 'aaaaaaeeeeiiiiooooouuuucnAAAAAAEEEEIIIIOOOOOUUUUCN';
    var result = text.toLowerCase();
    for (var i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i].toLowerCase());
    }
    return result;
  }

  bool _matches(String text) => _normalize(text).contains(_normalize(_query));

  @override
  Widget build(BuildContext context) {
    final matchingTeams = _query.isEmpty
        ? <String>[]
        : widget.availableTeams.where(_matches).toList();
    final matchingCompetitions = _query.isEmpty
        ? <CompetitionInfo>[]
        : COMPETITIONS_CATALOG.where((c) => _matches(c.name)).toList();
    final matchingCountries = _query.isEmpty
        ? <String>[]
        : _countries.where(_matches).toList();
    final matchingContinents = _query.isEmpty
        ? <String>[]
        : _continents.where(_matches).toList();

    final hasResults = matchingTeams.isNotEmpty ||
        matchingCompetitions.isNotEmpty ||
        matchingCountries.isNotEmpty ||
        matchingContinents.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Rechercher une équipe, une compétition, un pays...",
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: _query.isEmpty
          ? widget.availableTeams.isEmpty
              ? const Center(child: Text("Commencez à taper pour voir des suggestions"))
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      "Commencez à taper pour voir des suggestions\n(équipes du jour incluses)",
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
          : !hasResults
              ? const Center(child: Text("Aucun résultat"))
              : ListView(
                  children: [
                    // Équipes en premier : recherche la plus fréquente en pratique.
                    if (matchingTeams.isNotEmpty) ...[
                      const _SectionLabel("Équipes (aujourd'hui)"),
                      ...matchingTeams.map(
                        (t) => ListTile(
                          leading: const Icon(Icons.shield_outlined),
                          title: Text(t),
                          onTap: () => Navigator.pop(
                            context,
                            SearchResult(type: SearchResultType.team, value: t, label: t),
                          ),
                        ),
                      ),
                    ],
                    if (matchingCompetitions.isNotEmpty) ...[
                      const _SectionLabel("Compétitions"),
                      ...matchingCompetitions.map(
                        (c) => ListTile(
                          leading: const Icon(Icons.emoji_events_outlined),
                          title: Text(c.name),
                          subtitle: Text("${c.country} · ${c.continent}"),
                          onTap: () => Navigator.pop(
                            context,
                            SearchResult(type: SearchResultType.competition, value: c.name, label: c.name),
                          ),
                        ),
                      ),
                    ],
                    if (matchingCountries.isNotEmpty) ...[
                      const _SectionLabel("Pays"),
                      ...matchingCountries.map(
                        (c) => ListTile(
                          leading: const Icon(Icons.flag_outlined),
                          title: Text(c),
                          onTap: () => Navigator.pop(
                            context,
                            SearchResult(type: SearchResultType.country, value: c, label: c),
                          ),
                        ),
                      ),
                    ],
                    if (matchingContinents.isNotEmpty) ...[
                      const _SectionLabel("Continents"),
                      ...matchingContinents.map(
                        (c) => ListTile(
                          leading: const Icon(Icons.public),
                          title: Text(c),
                          onTap: () => Navigator.pop(
                            context,
                            SearchResult(type: SearchResultType.continent, value: c, label: c),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
