import "package:shared_preferences/shared_preferences.dart";

class SeasonPreferenceService {
  Future<String?> getLastSeason(String competitionCode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("last_season_$competitionCode");
  }

  Future<void> setLastSeason(String competitionCode, String season) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("last_season_$competitionCode", season);
  }
}
