import "dart:convert";
import "package:http/http.dart" as http;
import "../config/api_config.dart";
import "../models/match.dart";

class ApiService {
  Future<List<Match>> getTodayMatches() async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/matches/today");
    final response = await http.get(uri).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception("Erreur serveur (${response.statusCode})");
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Match.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
