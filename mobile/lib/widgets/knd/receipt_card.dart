import "package:flutter/material.dart";

/// Carte visuelle du reçu KOUNADIA, destinee a etre capturee en image
/// et partagee. Design simple, lisible une fois converti en PNG.
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

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              "KOUNADIA",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              "Reçu de dépôt 1xBet",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(),
          _row("Compte 1xBet", playerId),
          if (playerName != null && playerName!.isNotEmpty) _row("Nom", playerName!),
          _row("Orange Money", phone),
          _row("Date et heure", date),
          _row("Référence", reference),
          const Divider(),
          _row("Montant du dépôt", "$amount FCFA"),
          _row("Bonus KOUNADIA", "+$bonusAmount FCFA"),
          const SizedBox(height: 4),
          _row("Crédit total", "$totalCredit FCFA", bold: true),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              "Merci d'utiliser KOUNADIA",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
