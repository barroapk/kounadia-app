import "package:shared_preferences/shared_preferences.dart";

class LastCompetitionService {
  static const _key = "last_competition_viewed";

  Future<String?> getLast() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> setLast(String competitionName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, competitionName);
  }
}
