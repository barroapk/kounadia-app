import "dart:convert";
import "dart:io";
import "dart:math";
import "package:http/http.dart" as http;
import "../config/api_config.dart";
import "../models/match.dart";
import "../models/match_analysis.dart";
import "../models/eligible_match.dart";
import "../models/standings.dart";
import "../models/calendar.dart";
import "../models/brvm.dart";

class ApiService {
  static const _serverErrorCodes = {502, 503, 504};
  final Random _random = Random();

  /// Centralise tous les appels réseau : timeout + jusqu'à 3 tentatives avec
  /// backoff exponentiel avant d'abandonner, pour absorber les échecs
  /// DNS/réseau passagers et le réveil du serveur Render.
  Future<http.Response> _getWithRetry(String path, {int maxAttempts = 3}) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}$path");
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 90));

        if (_serverErrorCodes.contains(response.statusCode)) {
          throw HttpException("Serveur temporairement indisponible (${response.statusCode})");
        }

        return response;
      } catch (e) {
        lastError = e;
      }

      if (attempt < maxAttempts) {
        // Backoff exponentiel (2s, 4s, 8s...) + petite variation aléatoire,
        // pour éviter que plusieurs appareils retentent exactement au même moment.
        final baseDelay = pow(2, attempt).toInt();
        final jitterMs = _random.nextInt(500);
        await Future.delayed(Duration(seconds: baseDelay, milliseconds: jitterMs));
      }
    }

    throw Exception("Connexion au serveur impossible après $maxAttempts tentatives : $lastError");
  }

  Future<List<Match>> _fetchMatches(String path) async {
    final response = await _getWithRetry(path);

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

  Future<MatchAnalysis> getMatchAnalysis(int matchId, {String provider = 'football-data'}) async {
    final providerParam = provider == 'api-football' ? '?provider=api-football' : '';
    final response = await _getWithRetry("/analyzer/$matchId$providerParam");

    if (response.statusCode != 200) {
      throw Exception("Erreur serveur (${response.statusCode})");
    }

    return MatchAnalysis.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<EligibleMatch>> getTodaysPredictions() async {
    final response = await _getWithRetry("/predictions/today");

    if (response.statusCode != 200) {
      throw Exception("Erreur serveur (${response.statusCode})");
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => EligibleMatch.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StandingsResponse?> getStandings(String competitionCode, {String? season}) async {
    final seasonParam = season != null ? "?season=$season" : "";
    final response = await _getWithRetry("/standings/$competitionCode$seasonParam");

    if (response.statusCode != 200) {
      return null;
    }

    return StandingsResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CalendarResponse?> getCalendar(String competitionCode, {String? season}) async {
    final seasonParam = season != null ? "?season=$season" : "";
    final response = await _getWithRetry("/calendar/$competitionCode$seasonParam");

    if (response.statusCode != 200) {
      return null;
    }

    return CalendarResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<BrvmCatalog> getBrvmCatalog() async {
    final response = await _getWithRetry("/stocks/brvm");

    if (response.statusCode != 200) {
      throw Exception("Erreur serveur (${response.statusCode})");
    }

    return BrvmCatalog.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<BrvmQuote?> getBrvmQuote(String ticker) async {
    final symbol = ticker.trim().toUpperCase();
    final response = await _getWithRetry("/stocks/brvm/$symbol");

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception("Erreur serveur (${response.statusCode})");
    }

    return BrvmQuote.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<BrvmCandle>?> getBrvmHistory(String ticker) async {
    final symbol = ticker.trim().toUpperCase();
    final response = await _getWithRetry("/stocks/brvm/$symbol/history");

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception("Erreur serveur (${response.statusCode})");
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candles = data['candles'] as List<dynamic>? ?? [];
    return candles.map((e) => BrvmCandle.fromJson(e as Map<String, dynamic>)).toList();
  }
}
