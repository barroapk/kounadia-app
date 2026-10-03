import "dart:convert";
import "dart:io";
import "dart:math";
import "package:http/http.dart" as http;
import "../../config/knd_api_config.dart";

/// Exception porteuse du message d'erreur renvoye par KND API (ex: "Ce numero
/// Orange Money a deja une operation en cours"), pour l'afficher tel quel au
/// client plutot qu'un message reseau generique.
class KndApiException implements Exception {
  final int statusCode;
  final String message;
  KndApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Appels reseau vers KND API. Meme principe de retry que ApiService
/// (_getWithRetry) : jusqu'a 3 tentatives avec backoff, pour absorber le
/// reveil du serveur Render (jusqu'a 60s). Systeme independant de
/// l'ApiService existant, qui ne gere que le backend KOUNADIA (scores).
class KndApiService {
  static const _serverErrorCodes = {502, 503, 504};
  final Random _random = Random();

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    if (_serverErrorCodes.contains(response.statusCode)) {
      throw HttpException("Serveur temporairement indisponible (${response.statusCode})");
    }

    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded["message"] != null
          ? decoded["message"].toString()
          : "Erreur ${response.statusCode}";
      throw KndApiException(response.statusCode, message);
    }

    return decoded as Map<String, dynamic>;
  }

  /// Reservee aux lectures (GET) : sans effet de bord, donc rejouable sans
  /// risque en cas d'echec reseau/reveil Render.
  Future<Map<String, dynamic>> _getWithRetry(String path, {int maxAttempts = 3}) async {
    final uri = Uri.parse("${KndApiConfig.baseUrl}$path");

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 90));
        return _decodeOrThrow(response);
      } on KndApiException {
        rethrow;
      } catch (e) {
        if (attempt >= maxAttempts) {
          throw KndApiException(0, "Serveur injoignable. Vérifiez votre connexion et réessayez.");
        }
      }

      final baseDelay = pow(2, attempt).toInt();
      final jitterMs = _random.nextInt(500);
      await Future.delayed(Duration(seconds: baseDelay, milliseconds: jitterMs));
    }

    throw KndApiException(0, "Serveur injoignable. Vérifiez votre connexion et réessayez.");
  }

  /// Un seul essai, jamais rejoue automatiquement : /deposits n'a pas de cle
  /// d'idempotence cote serveur (contrairement au webhook SMS), donc un
  /// retry automatique apres timeout pourrait creer un doublon si le serveur
  /// avait deja traite la premiere requete. Le delai est volontairement
  /// long pour couvrir le reveil de Render (jusqu'a ~60s) en un seul essai.
  Future<Map<String, dynamic>> _postOnce(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse("${KndApiConfig.baseUrl}$path");
    try {
      final response = await http
          .post(uri, headers: {"Content-Type": "application/json"}, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 90));
      return _decodeOrThrow(response);
    } on KndApiException {
      rethrow;
    } catch (e) {
      throw KndApiException(
        0,
        "Impossible de confirmer si l'opération a réussi. Vérifiez votre connexion avant de réessayer.",
      );
    }
  }

  Future<Map<String, dynamic>> verifyPlayer(String playerId) {
    return _getWithRetry("/player-verification/verify?playerId=$playerId");
  }

  Future<Map<String, dynamic>> bonusInfo({
    required String playerId,
    required int amount,
  }) {
    final query = Uri(
      queryParameters: {
        "playerId": playerId,
        "amount": amount.toString(),
      },
    ).query;

    return _getWithRetry("/deposits/bonus-info?$query");
  }

  Future<Map<String, dynamic>> previewDeposit({
    required String playerId,
    required int amount,
  }) {
    return _postOnce(
      "/deposits/preview",
      body: {
        "playerId": playerId,
        "amount": amount,
      },
    );
  }

  Future<Map<String, dynamic>> createDeposit({
    required String playerId,
    required int amount,
    required String paymentPhone,
  }) {
    return _postOnce(
      "/deposits",
      body: {"playerId": playerId, "amount": amount, "paymentPhone": paymentPhone},
    );
  }

  Future<Map<String, dynamic>> getDeposit(String depositId) {
    return _getWithRetry("/deposits/$depositId");
  }

  Future<Map<String, dynamic>> cancelDeposit(String depositId) {
    return _postOnce("/deposits/$depositId/cancel");
  }
}
