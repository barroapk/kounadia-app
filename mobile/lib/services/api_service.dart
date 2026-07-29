import "dart:convert";
import "package:http/http.dart" as http;
import "../config/api_config.dart";
import "../models/match.dart";
import "../models/match_analysis.dart";
import "../models/eligible_match.dart";
import "../models/standings.dart";
import "../models/calendar.dart";

class ApiService {
  Future<List<Match>> _fetchMatches(String path) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}$path");
    final response = await http.get(uri).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception("Erreur serveur (${response.statusCode})");
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Match.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Match>> getTodayMatches() => _fetchMatches("/matches/today");
  Future<List<Match>> getLiveMatches() => _fetchMatches("/matches/live");

  Future<List<Match>> getMatchesByDate(String date) =>
      _fetchMatches("/matches/by-date?date=$date");

  Future<MatchAnalysis> getMatchAnalysis(int matchId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/analyzer/$matchId");
    final response = await http.get(uri).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception("Erreur serveur (${response.statusCode})");
    }

    return MatchAnalysis.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<EligibleMatch>> getTodaysPredictions() async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/predictions/today");
    final response = await http.get(uri).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception("Erreur serveur (${response.statusCode})");
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => EligibleMatch.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StandingsResponse?> getStandings(String competitionCode) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/standings/$competitionCode");
    final response = await http.get(uri).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      return null;
    }

    return StandingsResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CalendarResponse?> getCalendar(String competitionCode) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/calendar/$competitionCode");
    final response = await http.get(uri).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      return null;
    }

    return CalendarResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
