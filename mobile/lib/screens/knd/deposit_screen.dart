import "package:flutter/material.dart";
import "../../services/knd/knd_api_service.dart";
import "payment_screen.dart";

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _kndApi = KndApiService();
  final _amountController = TextEditingController();
  final _playerIdController = TextEditingController();
  final _phoneController = TextEditingController();

  // Indicatif uniquement (UX) : le serveur reste la seule autorite sur le
  // bonus reel applique au depot. Ne jamais utiliser cette valeur pour
  // afficher un credit final "garanti".
  static const _indicativeBonusPercent = 0;

  String? _verifiedPlayerName;
  bool _verifying = false;
  String? _verifyError;

  bool _creating = false;
  String? _createError;

  @override
  void dispose() {
    _amountController.dispose();
    _playerIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_amountController.text.trim());

  int get _indicativeBonus {
    final amount = _amount;
    if (amount == null) return 0;
    return (amount * _indicativeBonusPercent / 100).floor();
  }

  Future<void> _verifyPlayer() async {
    final playerId = _playerIdController.text.trim();
    if (playerId.isEmpty) return;

    setState(() {
      _verifying = true;
      _verifyError = null;
      _verifiedPlayerName = null;
    });

    try {
      final result = await _kndApi.verifyPlayer(playerId);
      final valid = result["valid"] == true;
      final name = result["playerName"]?.toString();

      setState(() {
        _verifying = false;
        if (valid && name != null) {
          _verifiedPlayerName = name;
        } else {
          _verifyError = "Compte 1xBet introuvable. Vérifiez l'ID.";
        }
      });
    } catch (e) {
      setState(() {
        _verifying = false;
        _verifyError = e.toString();
      });
    }
  }

  void _onPlayerIdChanged(String _) {
    // Toute modification de l'ID invalide une verification precedente :
    // on ne doit jamais laisser un ancien nom verifie associe a un ID modifie.
    if (_verifiedPlayerName != null || _verifyError != null) {
      setState(() {
        _verifiedPlayerName = null;
        _verifyError = null;
      });
    }
  }

  bool get _canContinue {
    final amount = _amount;
    final phone = _phoneController.text.trim();
    return amount != null &&
        amount >= 100 &&
        _verifiedPlayerName != null &&
        phone.length >= 8 &&
        !_creating;
  }

  Future<void> _createDeposit() async {
    final amount = _amount;
    final playerId = _playerIdController.text.trim();
    final phone = _phoneController.text.trim();
    if (amount == null) return;

    setState(() {
      _creating = true;
      _createError = null;
    });

    try {
      final deposit = await _kndApi.createDeposit(
        playerId: playerId,
        amount: amount,
        paymentPhone: phone,
      );

      if (!mounted) return;
      setState(() => _creating = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PaymentScreen(deposit: deposit)),
      );
    } catch (e) {
      setState(() {
        _creating = false;
        _createError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dépôt")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Alimenter mon compte 1xBet",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            const Text("Montant (FCFA)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Ex : 1000",
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            const Text("Compte 1xBet", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _playerIdController,
                    keyboardType: TextInputType.number,
                    onChanged: _onPlayerIdChanged,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "ID 1xBet",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _verifying ? null : _verifyPlayer,
                  child: _verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Vérifier"),
                ),
              ],
            ),
            if (_verifiedPlayerName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 6),
                  Text(_verifiedPlayerName!, style: const TextStyle(color: Colors.green)),
                ],
              ),
            ],
            if (_verifyError != null) ...[
              const SizedBox(height: 8),
              Text(_verifyError!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            const Text("Numéro Orange Money", style: TextStyle(fontWeight: FontWeight.bold)),
            const Text(
              "Le numéro qui servira à effectuer le paiement",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "07 XX XX XX",
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    "${(_amount ?? 0) + _indicativeBonus} FCFA",
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Le montant exact du bonus est confirmé à l'étape suivante",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            if (_createError != null) ...[
              const SizedBox(height: 16),
              Text(_createError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ],

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _canContinue ? _createDeposit : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Continuer"),
            ),
          ],
        ),
      ),
    );
  }
}
