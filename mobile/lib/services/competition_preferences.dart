import "package:shared_preferences/shared_preferences.dart";

class CompetitionPreferences {
  static const _key = "disabled_competitions";

  Future<Set<String>> getDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).toSet();
  }

  Future<void> setEnabled(String competitionName, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final disabled = (prefs.getStringList(_key) ?? []).toSet();

    if (enabled) {
      disabled.remove(competitionName);
    } else {
      disabled.add(competitionName);
    }

    await prefs.setStringList(_key, disabled.toList());
  }
}
