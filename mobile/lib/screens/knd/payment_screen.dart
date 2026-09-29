import "dart:async";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../../services/knd/knd_api_service.dart";

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> deposit;

  const PaymentScreen({super.key, required this.deposit});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _kndApi = KndApiService();
  late Map<String, dynamic> _deposit;
  Timer? _countdownTimer;
  Timer? _statusTimer;
  Duration _remaining = Duration.zero;
  bool _cancelling = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _deposit = widget.deposit;
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  DateTime? get _expiresAt {
    final raw = _deposit["expiresAt"]?.toString();
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String get _status => _deposit["status"]?.toString() ?? "PAYMENT_PENDING";

  void _updateCountdown() {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return;

    final remaining = expiresAt.difference(DateTime.now());
    if (!mounted) return;

    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  Future<void> _pollStatus() async {
    // Une fois l'operation terminee (paye, expire ou annule cote serveur),
    // plus besoin d'interroger le serveur.
    if (!["PAYMENT_PENDING", "PAYMENT_LATE"].contains(_status)) {
      _statusTimer?.cancel();
      return;
    }

    try {
      final depositId = _deposit["id"]?.toString();
      if (depositId == null) return;
      final updated = await _kndApi.getDeposit(depositId);
      if (!mounted) return;
      setState(() => _deposit = updated);
    } catch (e) {
      // Echec de sondage silencieux : on reessaiera dans 5s, pas la peine
      // d'interrompre l'ecran pour un aleas reseau passager.
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Annuler ce dépôt ?"),
        content: const Text("Si vous avez déjà payé, ne l'annulez pas : attendez la confirmation."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Retour")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Annuler le dépôt")),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _cancelling = true;
      _actionError = null;
    });

    try {
      final depositId = _deposit["id"]?.toString();
      if (depositId == null) return;
      final updated = await _kndApi.cancelDeposit(depositId);
      if (!mounted) return;
      setState(() {
        _deposit = updated;
        _cancelling = false;
      });
    } catch (e) {
      setState(() {
        _cancelling = false;
        _actionError = e.toString();
      });
    }
  }

  Future<void> _openWhatsapp() async {
    final phone = _deposit["supportWhatsapp"]?.toString() ?? "";
    final reference = _deposit["reference"]?.toString() ?? "";
    final amount = _deposit["totalCredit"]?.toString() ?? "";
    final message = Uri.encodeComponent(
      "Bonjour, j'ai un problème avec mon dépôt $reference ($amount FCFA).",
    );
    final uri = Uri.parse("https://wa.me/$phone?text=$message");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  Widget _buildStatusBanner() {
    switch (_status) {
      case "PAYMENT_CONFIRMED":
      case "PROCESSING":
        return _banner(Colors.blue, Icons.check_circle, "Paiement reçu, traitement en cours…");
      case "SUCCESS":
        return _banner(Colors.green, Icons.check_circle, "Dépôt crédité avec succès !");
      case "PAYMENT_LATE":
        return _banner(
          Colors.orange,
          Icons.warning_amber,
          "Paiement non encore détecté. Si vous avez déjà payé, ne repayez pas.",
        );
      case "PAYMENT_EXPIRED":
        return _banner(Colors.grey, Icons.timer_off, "Ce dépôt a expiré sans paiement détecté.");
      case "CANCELLED":
        return _banner(Colors.grey, Icons.cancel, "Ce dépôt a été annulé.");
      default:
        return _banner(Colors.orange, Icons.hourglass_top, "En attente de votre paiement Orange Money…");
    }
  }

  Widget _banner(Color color, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = ["PAYMENT_PENDING", "PAYMENT_LATE"].contains(_status);
    final isExpired = _remaining == Duration.zero && isActive;

    return Scaffold(
        appBar: AppBar(title: const Text("Paiement")),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusBanner(),
              const SizedBox(height: 24),

              Text(
                "${_deposit["totalCredit"] ?? "?"} FCFA",
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                "à créditer",
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _deposit["playerName"]?.toString() ?? "",
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                "Réf : ${_deposit["reference"] ?? ""}",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),

              if (isActive) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text("Composez ce code sur Orange Money", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _deposit["ussdCode"]?.toString() ?? "",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: "monospace"),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Marchand : ${_deposit["merchantName"] ?? ""}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),
                Text(
                  isExpired ? "Vérification par le serveur…" : _formatDuration(_remaining),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isExpired ? Colors.grey : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),
                if (_actionError != null) ...[
                  Text(_actionError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: _cancelling ? null : _cancel,
                  child: _cancelling
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Annuler ce dépôt"),
                ),
              ],

              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _openWhatsapp,
                icon: const Icon(Icons.help_outline),
                label: const Text("Besoin d'aide ? WhatsApp"),
              ),

              if (_status == "SUCCESS") ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text("Retour à l'accueil"),
                ),
              ],
            ],
          ),
        ),
      );
  }
}
