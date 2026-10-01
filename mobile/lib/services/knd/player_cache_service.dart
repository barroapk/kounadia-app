import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";

class PlayerCacheService {
  static const _key = "knd_recent_1xbet_players";
  static const _maxPlayers = 5;

  Future<List<Map<String, String>>> getPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => {
              "id": item["id"]?.toString() ?? "",
              "name": item["name"]?.toString() ?? "",
              "lastVerifiedAt":
                  item["lastVerifiedAt"]?.toString() ?? "",
            },
          )
          .where((item) => item["id"]!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlayer(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final players = await getPlayers();

    players.removeWhere((player) => player["id"] == id);

    players.insert(0, {
      "id": id,
      "name": name,
      "lastVerifiedAt": DateTime.now().toUtc().toIso8601String(),
    });

    if (players.length > _maxPlayers) {
      players.removeRange(_maxPlayers, players.length);
    }

    await prefs.setString(_key, jsonEncode(players));
  }

  Future<void> removePlayer(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final players = await getPlayers();

    players.removeWhere((player) => player["id"] == id);

    await prefs.setString(_key, jsonEncode(players));
  }
}
