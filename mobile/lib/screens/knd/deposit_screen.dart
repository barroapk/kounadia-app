import "package:flutter/material.dart";
import "../../services/knd/knd_api_service.dart";
import "payment_screen.dart";

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  static const _minDeposit = 200;
  static const _quickAmounts = [200, 500, 1000, 2000, 5000, 10000];

  final _kndApi = KndApiService();
  final _amountController = TextEditingController();
  final _playerIdController = TextEditingController();
  final _phoneController = TextEditingController();

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

  bool get _amountBelowMinimum {
    final amount = _amount;
    return amount != null && amount < _minDeposit;
  }

  void _selectQuickAmount(int amount) {
    _amountController.text = amount.toString();
    setState(() {});
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
        amount >= _minDeposit &&
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

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1A56DB);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Dépôt", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bandeau d'accroche
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryColor, primaryColor.withValues(alpha: 0.8)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Dépôt rapide et sécurisé",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Ton paiement est suivi automatiquement",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Montant
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Combien veux-tu déposer ?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      suffixText: "FCFA",
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Montant minimum : $_minDeposit FCFA",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _amountBelowMinimum ? FontWeight.bold : FontWeight.normal,
                      color: _amountBelowMinimum ? Colors.red : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAmounts.map((amount) {
                      final selected = _amount == amount;
                      return GestureDetector(
                        onTap: () => _selectQuickAmount(amount),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? primaryColor : const Color(0xFFF0F2F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            amount >= 1000 ? "${amount ~/ 1000}K" : amount.toString(),
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Compte 1xBet
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ton compte 1xBet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _playerIdController,
                          keyboardType: TextInputType.number,
                          onChanged: _onPlayerIdChanged,
                          decoration: InputDecoration(
                            hintText: "ID joueur",
                            filled: true,
                            fillColor: const Color(0xFFF5F7FA),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _verifying ? null : _verifyPlayer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _verifying
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Vérifier"),
                      ),
                    ],
                  ),
                  if (_verifiedPlayerName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_verifiedPlayerName!,
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("Vérifie bien le nom avant de continuer",
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                  if (_verifyError != null) ...[
                    const SizedBox(height: 8),
                    Text(_verifyError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Orange Money
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Numéro Orange Money", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text("Le numéro qui servira à effectuer le paiement",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "07 XX XX XX",
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_createError != null) ...[
              Text(_createError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _canContinue ? _createDeposit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _creating
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Continuer →", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
