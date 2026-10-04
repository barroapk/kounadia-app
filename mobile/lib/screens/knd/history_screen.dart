import "package:flutter/material.dart";
import "../../services/knd/deposit_history_service.dart";
import "../../services/knd/knd_api_service.dart";

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _historyService = DepositHistoryService();
  final _kndApi = KndApiService();
  bool _cancelling = false;

  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  bool _showSensitive = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final entries = await _historyService.getHistory();

    if (!mounted) return;

    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  String _formatDate(dynamic value) {
    if (value == null) return "-";

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final local = date.toLocal();

    String two(int n) => n.toString().padLeft(2, "0");

    return "${two(local.day)}/${two(local.month)} "
        "${local.year} ${two(local.hour)}:${two(local.minute)}";
  }

  String _formatShortDate(dynamic value) {
    if (value == null) return "-";

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final local = date.toLocal();

    String two(int n) => n.toString().padLeft(2, "0");

    return "${two(local.day)}/${two(local.month)} "
        "${two(local.hour)}:${two(local.minute)}";
  }

  String _fcfa(dynamic value) {
    if (value == null) return "0";

    final number = int.tryParse(value.toString()) ?? 0;

    return number.toString().replaceAllMapped(
      RegExp(r"\B(?=(\d{3})+(?!\d))"),
      (match) => " ",
    );
  }

  String _statusLabel(dynamic value) {
    switch (value?.toString()) {
      case "PAYMENT_PENDING":
        return "En attente";
      case "PAYMENT_REVIEW":
        return "En vérification";
      case "PAYMENT_LATE":
        return "En retard";
      case "CONFIRMED":
        return "Confirmé";
      case "SUCCESS":
        return "Réussi";
      case "CANCELLED":
        return "Annulé";
      case "REJECTED":
        return "Refusé";
      default:
        return value?.toString() ?? "Inconnu";
    }
  }

  Color _statusColor(dynamic value) {
    switch (value?.toString()) {
      case "CONFIRMED":
      case "SUCCESS":
        return Colors.green;
      case "CANCELLED":
      case "REJECTED":
        return Colors.brown;
      case "PAYMENT_REVIEW":
      case "PAYMENT_LATE":
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _mask(String value) {
    if (_showSensitive) return value;

    if (value.length <= 4) {
      return "••••";
    }

    return "${value.substring(0, 2)}••••${value.substring(value.length - 2)}";
  }

  bool _isCancelled(Map<String, dynamic> entry) {
    final status = entry["status"]?.toString();

    return status == "CANCELLED" || status == "REJECTED";
  }

  Future<void> _cancelDeposit(Map<String, dynamic> entry, void Function(void Function()) sheetSetState) async {
    final id = entry["id"]?.toString();
    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Annuler le dépôt ?"),
        content: const Text(
          "Si tu as déjà effectué le paiement Orange Money, n'annule pas cette opération.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Retour"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Annuler le dépôt", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    sheetSetState(() => _cancelling = true);

    try {
      final updated = await _kndApi.cancelDeposit(id);
      await _historyService.saveEntry({...entry, ...updated});

      if (!mounted) return;
      Navigator.pop(context);
      _loadHistory();
    } catch (_) {
      sheetSetState(() => _cancelling = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'annuler ce dépôt. Réessaie.")),
      );
    }
  }

  void _openDetail(Map<String, dynamic> entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, sheetSetState) => _buildDetailSheet(entry, sheetSetState),
      ),
    );
  }

  Widget _buildDetailSheet(Map<String, dynamic> entry, void Function(void Function()) sheetSetState) {
    final amount = _fcfa(entry["amount"]);
    final bonus = _fcfa(entry["bonusAmount"]);
    final total = _fcfa(entry["totalCredit"]);

    final playerId = entry["playerId"]?.toString() ?? "-";
    final playerName = entry["playerName"]?.toString();
    final phone = entry["paymentPhone"]?.toString() ?? "-";
    final reference = entry["reference"]?.toString() ?? "-";

    final status = entry["status"];
    final statusColor = _statusColor(status);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 45),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      "Dépôt 1xBet",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  "+$amount F",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              _detailRow(
                Icons.person_outline,
                "Compte 1xBet",
                _mask(playerId),
              ),

              if (playerName != null && playerName.isNotEmpty)
                _detailRow(
                  Icons.badge_outlined,
                  "Nom",
                  playerName,
                ),

              _detailRow(
                Icons.phone_android_outlined,
                "Orange Money",
                _mask(phone),
              ),

              _detailRow(
                Icons.access_time,
                "Date et heure",
                _formatDate(entry["createdAt"]),
              ),

              _detailRow(
                Icons.confirmation_number_outlined,
                "Référence",
                reference,
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              _amountRow(
                "Montant du dépôt",
                "$amount FCFA",
              ),

              _amountRow(
                "Bonus",
                "+$bonus FCFA",
                valueColor: Colors.green,
              ),

              _amountRow(
                "Crédit total",
                "$total FCFA",
                bold: true,
              ),

              if (_isCancelled(entry)) ...[
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.card_giftcard_outlined,
                        color: Colors.orange[800],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Bonus manqué : $bonus FCFA",
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 25),

              if (entry["status"]?.toString() == "PAYMENT_PENDING") ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _cancelling ? null : () => _cancelDeposit(entry, sheetSetState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red[800],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _cancelling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            "Annuler ce dépôt",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Fermer",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyItem(Map<String, dynamic> entry) {
    final amount = _fcfa(entry["amount"]);
    final playerId = entry["playerId"]?.toString() ?? "-";
    final phone = entry["paymentPhone"]?.toString() ?? "-";
    final status = entry["status"];

    final statusColor = _statusColor(status);
    final cancelled = _isCancelled(entry);

    final bonus = _fcfa(entry["bonusAmount"]);

    return InkWell(
      onTap: () => _openDetail(entry),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 17, 16, 17),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.arrow_downward_rounded,
                color: Colors.green,
                size: 32,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          "Dépôt 1xBet",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        "+$amount F",
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          "ID ${_mask(playerId)} · "
                          "${phone.isNotEmpty ? "Orange Money" : "-"}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatShortDate(entry["createdAt"]),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      if (cancelled && bonus != "0") ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.card_giftcard_outlined,
                                  size: 17,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    "$bonus F de bonus manqués",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          "Historique",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _showSensitive
                ? "Masquer les données"
                : "Afficher les données",
            icon: Icon(
              _showSensitive
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () {
              setState(() {
                _showSensitive = !_showSensitive;
              });
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: _entries.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 130),
                        Icon(
                          Icons.history,
                          size: 58,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            "Aucun dépôt enregistré",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: 6),
                        Center(
                          child: Text(
                            "Tes prochains dépôts apparaîtront ici.",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _entries.length,
                      itemBuilder: (_, index) =>
                          _historyItem(_entries[index]),
                    ),
            ),
    );
  }
}
