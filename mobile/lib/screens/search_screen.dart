import "package:flutter/material.dart";
import "../config/competitions_catalog.dart";
import "../models/search_result.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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

  bool _matches(String text) => text.toLowerCase().contains(_query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final matchingContinents = _query.isEmpty
        ? <String>[]
        : _continents.where(_matches).toList();
    final matchingCountries = _query.isEmpty
        ? <String>[]
        : _countries.where(_matches).toList();
    final matchingCompetitions = _query.isEmpty
        ? <CompetitionInfo>[]
        : COMPETITIONS_CATALOG.where((c) => _matches(c.name)).toList();

    final hasResults = matchingContinents.isNotEmpty ||
        matchingCountries.isNotEmpty ||
        matchingCompetitions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Rechercher un continent, un pays, une compétition...",
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: _query.isEmpty
          ? const Center(child: Text("Commencez à taper pour voir des suggestions"))
          : !hasResults
              ? const Center(child: Text("Aucun résultat"))
              : ListView(
                  children: [
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
