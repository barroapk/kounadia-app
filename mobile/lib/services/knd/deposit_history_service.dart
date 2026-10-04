import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";

/// Historique local des depots, propre a ce telephone (pas de compte
/// KOUNADIA). Chaque entree est enregistree depuis PaymentScreen au fil
/// des operations. Donnees affichables/masquables : montant, bonus,
/// compte 1xBet, telephone, statut, date/heure.
class DepositHistoryService {
  static const _key = "knd_deposit_history";
  static const _maxEntries = 200;

  Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Enregistre ou met a jour une entree (par reference). Un meme depot
  /// peut etre sauvegarde plusieurs fois (PAYMENT_PENDING -> SUCCESS) :
  /// seule la derniere version est conservee.
  Future<void> saveEntry(Map<String, dynamic> deposit) async {
    final reference = deposit["reference"]?.toString();
    if (reference == null || reference.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final entries = await getHistory();

    entries.removeWhere((e) => e["reference"] == reference);

    entries.insert(0, {
      "reference": reference,
      "playerId": deposit["playerId"],
      "playerName": deposit["playerName"],
      "amount": deposit["amount"],
      "bonusAmount": deposit["bonusAmount"],
      "totalCredit": deposit["totalCredit"],
      "paymentPhone": deposit["paymentPhone"],
      "status": deposit["status"],
      "createdAt": deposit["createdAt"],
    });

    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }

    await prefs.setString(_key, jsonEncode(entries));
  }
}
