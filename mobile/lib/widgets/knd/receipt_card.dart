import "package:flutter/material.dart";

/// Carte visuelle du reçu KOUNADIA, destinee a etre capturee en image
/// et partagee. Format compact pour tenir sur un ecran sans surcharge.
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 14 : 11,
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
      width: 300,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              "KOUNADIA",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 2),
          const Center(
            child: Text(
              "Reçu de dépôt 1xBet",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(height: 10),
          const Divider(height: 16),
          _row("Compte 1xBet", playerId),
          if (playerName != null && playerName!.isNotEmpty) _row("Nom", playerName!),
          _row("Orange Money", phone),
          _row("Date et heure", date),
          _row("Référence", reference),
          const Divider(height: 16),
          _row("Montant du dépôt", "$amount FCFA"),
          _row("Bonus KOUNADIA", "+$bonusAmount FCFA"),
          const SizedBox(height: 2),
          _row("Crédit total", "$totalCredit FCFA", bold: true),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              "Merci d'utiliser KOUNADIA",
              style: TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
