import "package:flutter/material.dart";
import "../config/competitions_catalog.dart";
import "../config/country_flags.dart";
import "../services/last_competition_service.dart";
import "../widgets/country_card.dart";
import "competition_detail_screen.dart";

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen> {
  final LastCompetitionService _lastCompetitionService = LastCompetitionService();
  String? _lastCompetition;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final last = await _lastCompetitionService.getLast();
    if (mounted) setState(() => _lastCompetition = last);
  }

  void _openCompetition(CompetitionInfo comp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompetitionDetailScreen(name: comp.name, code: comp.code),
      ),
    ).then((_) => _loadLast());
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, List<CompetitionInfo>>> tree = {};
    for (final comp in COMPETITIONS_CATALOG) {
      tree.putIfAbsent(comp.continent, () => {});
      tree[comp.continent]!.putIfAbsent(comp.country, () => []).add(comp);
    }
    final continents = tree.keys.toList();

    CompetitionInfo? lastCompetitionInfo;
    if (_lastCompetition != null) {
      try {
        lastCompetitionInfo = COMPETITIONS_CATALOG.firstWhere((c) => c.name == _lastCompetition);
      } catch (_) {
        lastCompetitionInfo = null;
      }
    }

    return Container(
      color: const Color(0xFFF2F2F2),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (lastCompetitionInfo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: InkWell(
                onTap: () => _openCompetition(lastCompetitionInfo!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Dernière consultation : ${lastCompetitionInfo.name}",
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ...continents.map((continent) {
            final countries = tree[continent]!;
            final international = countries["International"];
            final realCountries = Map<String, List<CompetitionInfo>>.from(countries)
              ..remove("International");

            List<Widget> competitionTiles(List<CompetitionInfo> comps) {
              final sorted = List<CompetitionInfo>.from(comps)
                ..sort((a, b) => competitionRank(a.name).compareTo(competitionRank(b.name)));
              return sorted
                  .map((c) => ListTile(
                        dense: true,
                        title: Text(c.name, style: const TextStyle(fontSize: 13)),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _openCompetition(c),
                      ))
                  .toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(continent, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (international != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(children: competitionTiles(international)),
                  ),
                ...realCountries.entries.map((entry) {
                  final country = entry.key;
                  final comps = entry.value;
                  final flagUrl = flagUrlFor(country);
                  return CountryCard(
                    title: country,
                    flagUrl: flagUrl,
                    matchCount: 0,
                    competitionCount: comps.length,
                    children: competitionTiles(comps),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }
}
