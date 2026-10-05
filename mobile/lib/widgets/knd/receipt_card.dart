import "package:flutter/material.dart";

/// Carte visuelle du reçu KOUNADIA, destinee a etre capturee en image
/// et partagee. Format compact, inspire des recus de transaction mobile.
class ReceiptCard extends StatelessWidget {
  final String statusLabel;
  final Color statusColor;
  final String amount;
  final String bonusAmount;
  final String totalCredit;
  final String playerId;
  final String? playerName;
  final String phone;
  final String reference;
  final String date;

  const ReceiptCard({
    super.key,
    required this.statusLabel,
    required this.statusColor,
    required this.amount,
    required this.bonusAmount,
    required this.totalCredit,
    required this.playerId,
    this.playerName,
    required this.phone,
    required this.reference,
    required this.date,
  });

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1A56DB);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 320,
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tete colore
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [primary, Color(0xFF123F9E)]),
              ),
              child: Row(
                children: [
                  const Text(
                    "KOUNADIA",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "REÇU",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      "DÉPÔT · 1XBET",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: "+",
                            style: TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: amount,
                            style: const TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(
                            text: " FCFA",
                            style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _row("Compte joueur", playerId),
                  if (playerName != null && playerName!.isNotEmpty) _row("Nom", playerName!),
                  _row("Moyen de paiement", "Orange Money ($phone)"),
                  _row("Bonus", "+$bonusAmount FCFA"),
                  _row("Crédit total", "$totalCredit FCFA"),
                  _row("Référence", reference),
                  _row("Date", date),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      "Dépose et retire sur 1xBet avec KOUNADIA",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
