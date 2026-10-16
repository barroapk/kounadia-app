import "package:flutter/material.dart";
import "../config/competitions_catalog.dart";
import "../services/competition_preferences.dart";

class CompetitionsSettingsScreen extends StatefulWidget {
  CompetitionsSettingsScreen({super.key});

  @override
  State<CompetitionsSettingsScreen> createState() => _CompetitionsSettingsScreenState();
}

class _CompetitionsSettingsScreenState extends State<CompetitionsSettingsScreen> {
  final _prefs = CompetitionPreferences();
  Set<String> _disabled = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final disabled = await _prefs.getDisabled();
    setState(() {
      _disabled = disabled;
      _loading = false;
    });
  }

  Future<void> _toggle(String name, bool enabled) async {
    await _prefs.setEnabled(name, enabled);
    setState(() {
      if (enabled) {
        _disabled.remove(name);
      } else {
        _disabled.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Map<String, Map<String, List<CompetitionInfo>>> grouped = {};
    for (final comp in VISIBLE_COMPETITIONS_CATALOG) {
      grouped.putIfAbsent(comp.continent, () => {});
      grouped[comp.continent]!.putIfAbsent(comp.country, () => []);
      grouped[comp.continent]![comp.country]!.add(comp);
    }

    return Scaffold(
      appBar: AppBar(title: Text("Compétitions affichées")),
      body: ListView(
        children: grouped.entries.map((continentEntry) {
          return ExpansionTile(
            title: Text(
              continentEntry.key,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            childrenPadding: EdgeInsets.zero,
            children: continentEntry.value.entries.map((countryEntry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (countryEntry.key != "International")
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 6, 16, 2),
                      child: Text(
                        countryEntry.key,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ...countryEntry.value.map((comp) {
                    final isEnabled = !_disabled.contains(comp.name);
                    return InkWell(
                      onTap: () => _toggle(comp.name, !isEnabled),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                comp.name,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: isEnabled,
                                activeColor: Color(0xFF16A34A),
                                onChanged: (value) => _toggle(comp.name, value),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
