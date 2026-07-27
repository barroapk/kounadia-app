import "package:flutter/material.dart";
import "../config/competitions_catalog.dart";
import "../services/competition_preferences.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Map<String, Map<String, List<CompetitionInfo>>> grouped = {};
    for (final comp in COMPETITIONS_CATALOG) {
      grouped.putIfAbsent(comp.continent, () => {});
      grouped[comp.continent]!.putIfAbsent(comp.country, () => []);
      grouped[comp.continent]![comp.country]!.add(comp);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Compétitions affichées")),
      body: ListView(
        children: grouped.entries.map((continentEntry) {
          return ExpansionTile(
            title: Text(
              continentEntry.key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: continentEntry.value.entries.map((countryEntry) {
              final showCountryHeader = countryEntry.key != "International" &&
                  countryEntry.value.length > 1 == false &&
                  countryEntry.key.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (countryEntry.key != "International")
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
                      child: Text(
                        countryEntry.key,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ...countryEntry.value.map((comp) {
                    final isEnabled = !_disabled.contains(comp.name);
                    return SwitchListTile(
                      contentPadding: const EdgeInsets.only(left: 32, right: 16),
                      dense: true,
                      title: Text(comp.name),
                      value: isEnabled,
                      activeColor: const Color(0xFF16A34A),
                      onChanged: (value) => _toggle(comp.name, value),
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
