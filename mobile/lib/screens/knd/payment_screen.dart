import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "../../services/knd/knd_api_service.dart";
import "../../services/knd/deposit_history_service.dart";

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> deposit;

  const PaymentScreen({
    super.key,
    required this.deposit,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _primary = Color(0xFF1A56DB);
  static const _success = Color(0xFF159947);
  static const _orange = Color(0xFFE87900);
  static const _background = Color(0xFFF5F7FA);

  final _api = KndApiService();
  final _historyService = DepositHistoryService();

  late Map<String, dynamic> _deposit;

  Timer? _pollTimer;
  Timer? _countdownTimer;

  Duration _remaining = Duration.zero;

  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _deposit = Map<String, dynamic>.from(widget.deposit);
    _historyService.saveEntry(_deposit);
    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _status =>
      _deposit["status"]?.toString() ?? "PAYMENT_PENDING";

  bool get _isWaiting =>
      _status == "PAYMENT_PENDING" || _status == "PAYMENT_LATE";

  bool get _canCancel =>
      _status == "PAYMENT_PENDING" ||
      _status == "PAYMENT_LATE" ||
      _status == "PAYMENT_EXPIRED";

  int get _amount {
    final value = _deposit["amount"];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  int get _totalCredit {
    final value = _deposit["totalCredit"];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? "") ?? _amount;
  }

  String get _playerName =>
      _deposit["playerName"]?.toString() ?? "Compte 1xBet";

  String get _playerId =>
      _deposit["playerId1xbet"]?.toString() ??
      _deposit["playerId"]?.toString() ??
      "";

  String get _reference =>
      _deposit["reference"]?.toString() ?? "—";

  String get _ussdCode =>
      _deposit["ussdCode"]?.toString() ?? "—";

  String get _merchantName =>
      _deposit["merchantName"]?.toString() ?? "—";

  String get _supportWhatsapp =>
      _deposit["supportWhatsapp"]?.toString() ?? "";

  void _startCountdown() {
    _updateCountdown();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  void _updateCountdown() {
    final raw = _deposit["expiresAt"]?.toString();

    if (raw == null) {
      if (mounted) {
        setState(() => _remaining = Duration.zero);
      }
      return;
    }

    final expiresAt = DateTime.tryParse(raw)?.toLocal();

    if (expiresAt == null) {
      if (mounted) {
        setState(() => _remaining = Duration.zero);
      }
      return;
    }

    final remaining = expiresAt.difference(DateTime.now());

    if (!mounted) return;

    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshDeposit(),
    );

    _refreshDeposit();
  }

  Future<void> _refreshDeposit() async {
    if (!_isWaiting) {
      _pollTimer?.cancel();
      return;
    }

    try {
      final id = _deposit["id"]?.toString();

      if (id == null || id.isEmpty) return;

      final updated = await _api.getDeposit(id);

      if (!mounted) return;

      setState(() {
        _deposit = Map<String, dynamic>.from(updated);
        _error = null;
      });

      _historyService.saveEntry(_deposit);

      if (!_isWaiting) {
        _pollTimer?.cancel();
      }
    } catch (_) {
      // Une erreur ponctuelle de polling ne doit pas perturber
      // l'utilisateur. Le prochain cycle réessaiera.
    }
  }

  Future<void> _copyUssd() async {
    await Clipboard.setData(ClipboardData(text: _ussdCode));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Code copié dans le presse-papiers."),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openUssd() async {
    final code = _ussdCode.trim();

    if (code.isEmpty || code == "—") return;

    final uri = Uri(
      scheme: "tel",
      path: code,
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'ouvrir l'application Téléphone."),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir l'application Téléphone."),
        ),
      );
    }
  }

  Future<void> _openWhatsapp() async {
    if (_supportWhatsapp.isEmpty) return;

    final phone = _supportWhatsapp.replaceAll(RegExp(r"[^0-9+]"), "");

    final uri = Uri(
      scheme: "https",
      host: "wa.me",
      path: "/$phone",
    );

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir WhatsApp."),
        ),
      );
    }
  }

  Future<void> _cancelDeposit() async {
    if (_cancelling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Annuler le dépôt ?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Si tu as déjà effectué le paiement Orange Money, "
            "n'annule pas cette opération.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Continuer"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Annuler le dépôt",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final id = _deposit["id"]?.toString();

    if (id == null || id.isEmpty) return;

    setState(() {
      _cancelling = true;
      _error = null;
    });

    try {
      final updated = await _api.cancelDeposit(id);

      if (!mounted) return;

      setState(() {
        _deposit = Map<String, dynamic>.from(updated);
        _cancelling = false;
      });

      _historyService.saveEntry(_deposit);
      _pollTimer?.cancel();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cancelling = false;
        _error = e.toString();
      });
    }
  }

  String _formatAmount(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      final remainingAfterThis = text.length - i - 1;

      buffer.write(text[i]);

      // Espace tous les 3 chiffres restants, jamais apres le dernier
      // caractere : "5000" -> "5 000", "1234567" -> "1 234 567".
      if (remainingAfterThis > 0 && remainingAfterThis % 3 == 0) {
        buffer.write(" ");
      }
    }

    return buffer.toString();
  }

  String _formatCountdown() {
    final totalSeconds = _remaining.inSeconds;

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return "$minutes:${seconds.toString().padLeft(2, "0")}";
  }

  Widget _statusIcon() {
    if (_status == "SUCCESS") {
      return Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFFE8F7EE),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle,
          color: _success,
          size: 38,
        ),
      );
    }

    if (_status == "PAYMENT_CONFIRMED" ||
        _status == "PROCESSING") {
      return Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFFE8F0FF),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.sync,
          color: _primary,
          size: 34,
        ),
      );
    }

    if (_status == "PAYMENT_EXPIRED" ||
        _status == "CANCELLED") {
      return Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFFFFEEEE),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.info_outline,
          color: Colors.red,
          size: 34,
        ),
      );
    }

    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F0FF),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.account_balance_wallet_outlined,
        color: _primary,
        size: 34,
      ),
    );
  }

  String get _statusTitle {
    switch (_status) {
      case "PAYMENT_CONFIRMED":
        return "Paiement reçu";
      case "PROCESSING":
        return "Dépôt en traitement";
      case "SUCCESS":
        return "Dépôt confirmé";
      case "PAYMENT_EXPIRED":
        return "Délai dépassé";
      case "CANCELLED":
        return "Dépôt annulé";
      case "PAYMENT_LATE":
        return "Paiement non encore détecté";
      default:
        return "Ton paiement est prêt";
    }
  }

  String get _statusSubtitle {
    switch (_status) {
      case "PAYMENT_CONFIRMED":
        return "Ton paiement Orange Money a bien été reçu.";
      case "PROCESSING":
        return "Ton paiement est confirmé. Ton dépôt est en cours de traitement.";
      case "SUCCESS":
        return "Ton dépôt a été traité avec succès.";
      case "PAYMENT_EXPIRED":
        return "Le délai de paiement est terminé.";
      case "CANCELLED":
        return "Cette opération a été annulée.";
      case "PAYMENT_LATE":
        return "Nous continuons à vérifier ton paiement.";
      default:
        return "Effectue ton paiement Orange Money. KOUNADIA vérifiera automatiquement.";
    }
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Joueur",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _playerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          if (_playerId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  "ID joueur",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  _playerId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              const Text(
                "Dépôt",
                style: TextStyle(color: Colors.grey),
              ),
              const Spacer(),
              Text(
                "${_formatAmount(_amount)} FCFA",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          if (_totalCredit != _amount) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  "Crédit prévu",
                  style: TextStyle(color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  "${_formatAmount(_totalCredit)} FCFA",
                  style: const TextStyle(
                    color: _success,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Référence",
                style: TextStyle(color: Colors.grey),
              ),
              const Spacer(),
              Text(
                _reference,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _orange,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "1. Effectue ton paiement",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8A4300),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Appuie sur le code ou copie-le pour lancer ton paiement Orange Money.",
            style: TextStyle(
              color: Color(0xFF8A5A35),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),

          InkWell(
            onTap: _openUssd,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD9A8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    _ussdCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB74B00),
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Appuie ici pour lancer le paiement",
                    style: TextStyle(
                      color: Color(0xFF8A5A35),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.store_outlined,
                  color: _orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Marchand",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _merchantName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "Vérifie ce nom avant de valider le paiement.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A5A35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copyUssd,
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text("Copier le code"),
              style: OutlinedButton.styleFrom(
                foregroundColor: _orange,
                side: const BorderSide(color: _orange),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard() {
    final confirmed = _status == "PAYMENT_CONFIRMED" ||
        _status == "PROCESSING" ||
        _status == "SUCCESS";

    final finished = _status == "SUCCESS";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Suivi du dépôt",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),

          _step(
            number: "1",
            title: "Paiement Orange Money",
            subtitle: confirmed
                ? "Paiement reçu"
                : "En attente de ton paiement",
            active: !confirmed,
            done: confirmed,
          ),

          _verticalLine(),

          _step(
            number: "2",
            title: "Vérification KOUNADIA",
            subtitle: confirmed
                ? "Paiement confirmé"
                : "Détection automatique",
            active: confirmed && !finished,
            done: confirmed,
          ),

          _verticalLine(),

          _step(
            number: "3",
            title: "Crédit du compte 1xBet",
            subtitle: finished
                ? "Dépôt terminé"
                : "Traitement par notre équipe",
            active: finished,
            done: finished,
          ),
        ],
      ),
    );
  }

  Widget _step({
    required String number,
    required String title,
    required String subtitle,
    required bool active,
    required bool done,
  }) {
    final color = done
        ? _success
        : active
            ? _primary
            : Colors.grey;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: done
                ? const Color(0xFFE8F7EE)
                : active
                    ? _primary
                    : const Color(0xFFE8E8E8),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(
                  Icons.check,
                  color: _success,
                  size: 20,
                )
              : Text(
                  number,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _verticalLine() {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      width: 2,
      height: 22,
      color: Colors.grey[200],
    );
  }

  Widget _waitingCard() {
    if (!_isWaiting) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _remaining.inSeconds > 0
                      ? (_remaining.inSeconds / 180).clamp(0.0, 1.0)
                      : null,
                  strokeWidth: 6,
                  backgroundColor: Colors.blueGrey.withValues(alpha: 0.12),
                  color: _primary,
                ),
                Text(
                  _remaining.inSeconds > 0
                      ? _formatCountdown()
                      : "…",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _remaining.inSeconds > 0
                ? "En attente de ton paiement Orange Money…"
                : "Vérification par le serveur…",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF315A9E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Si tu as déjà payé, ne repaie pas. "
            "KOUNADIA vérifie automatiquement ton paiement.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _successCard() {
    if (_status != "SUCCESS") return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: _success,
            size: 58,
          ),
          const SizedBox(height: 12),
          const Text(
            "Dépôt confirmé !",
            style: TextStyle(
              color: _success,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${_formatAmount(_totalCredit)} FCFA",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Le dépôt a été traité avec succès.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          "Paiement",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _statusIcon(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _statusSubtitle,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _summaryCard(),

              const SizedBox(height: 16),

              if (_isWaiting) ...[
                _paymentCard(),
                const SizedBox(height: 16),
                _waitingCard(),
                const SizedBox(height: 16),
              ],

              _progressCard(),

              const SizedBox(height: 16),

              _successCard(),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              ],

              if (_isWaiting && _supportWhatsapp.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openWhatsapp,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text("Besoin d'aide ? WhatsApp"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              if (_canCancel && _status != "PAYMENT_EXPIRED") ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _cancelling ? null : _cancelDeposit,
                  child: _cancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Annuler ce dépôt",
                          style: TextStyle(color: Colors.red),
                        ),
                ),
              ],

              const SizedBox(height: 8),

              if (!_isWaiting)
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _status == "SUCCESS"
                          ? "Retour à KOUNADIA"
                          : "Retour à KOUNADIA",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
}
