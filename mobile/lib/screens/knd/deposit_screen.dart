import "dart:async";
import "package:flutter/material.dart";
import "../../services/knd/knd_api_service.dart";
import "../../services/knd/player_cache_service.dart";
import "package:shared_preferences/shared_preferences.dart";
import "payment_screen.dart";

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  static const _minDeposit = 200;
  static const _quickAmounts = [200, 500, 1000, 2000, 5000, 10000];
  static const _lastPlayerIdKey = "knd_last_valid_player_id";
  static const _lastPhoneKey = "knd_last_valid_orange_phone";

  final _kndApi = KndApiService();
  final _playerCache = PlayerCacheService();
  List<Map<String, String>> _recentPlayers = [];
  final _amountController = TextEditingController();
  final _playerIdController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _verifiedPlayerName;
  bool _verifying = false;
  String? _verifyError;

  bool _creating = false;
  String? _createError;

  bool _previewing = false;
  String? _previewError;
  Map<String, dynamic>? _preview;

  Timer? _bonusInfoTimer;
  Map<String, dynamic>? _bonusInfo;
  String? _lastBonusInfoKey;
  int _bonusInfoRequestId = 0;
  bool _isFirstDeposit = false;

  @override
  void initState() {
    super.initState();
    _loadRecentPlayers();
    _loadLastValidInputs();
  }

  Future<void> _loadRecentPlayers() async {
    final players = await _playerCache.getPlayers();
    if (!mounted) return;
    setState(() => _recentPlayers = players);
  }

  /// Preremplit l'ID 1xBet et le numero Orange Money avec les dernieres
  /// valeurs reellement validees (jamais une simple saisie non verifiee).
  Future<void> _loadLastValidInputs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPlayerId = prefs.getString(_lastPlayerIdKey);
      final lastPhone = prefs.getString(_lastPhoneKey);

      if (!mounted) return;

      setState(() {
        if (lastPlayerId != null && lastPlayerId.isNotEmpty) {
          _playerIdController.text = lastPlayerId;
        }
        if (lastPhone != null && lastPhone.isNotEmpty) {
          _phoneController.text = lastPhone;
        }
      });
    } catch (_) {
      // Prefill est une commodite locale : une erreur ici ne doit jamais
      // bloquer l'ouverture de l'ecran.
    }
  }

  Future<void> _saveLastValidPlayerId(String playerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPlayerIdKey, playerId);
    } catch (_) {
      // Pas bloquant : commodite locale uniquement.
    }
  }

  Future<void> _saveLastValidPhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPhoneKey, phone);
    } catch (_) {
      // Pas bloquant : commodite locale uniquement.
    }
  }

  @override
  void dispose() {
    _bonusInfoTimer?.cancel();
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
    _onAmountChanged();
  }

  void _onAmountChanged() {
    _bonusInfoTimer?.cancel();
    _bonusInfoRequestId++;

    final amount = _amount;

    setState(() {
      _bonusInfo = null;
      _lastBonusInfoKey = null;
    });

    if (amount == null || amount < _minDeposit) {
      return;
    }

    final key = "$amount";

    // Debounce court : le bonus ordinaire ne depend pas de NafaCash,
    // donc l'appel est rapide, mais on evite quand meme une requete
    // par caractere tape.
    _bonusInfoTimer = Timer(const Duration(milliseconds: 250), () {
      _loadBonusOrdinary(amount, key);
    });
  }

  Future<void> _loadBonusOrdinary(int amount, String key) async {
    if (_lastBonusInfoKey == key) {
      return;
    }

    final requestId = ++_bonusInfoRequestId;

    try {
      final result = await _kndApi.bonusOrdinary(amount: amount);

      if (!mounted || requestId != _bonusInfoRequestId || _amount != amount) {
        return;
      }

      setState(() {
        _bonusInfo = result;
        _lastBonusInfoKey = key;
      });
    } catch (_) {
      if (!mounted || requestId != _bonusInfoRequestId) {
        return;
      }

      setState(() {
        _bonusInfo = null;
        _lastBonusInfoKey = null;
      });
    }
  }

  Future<bool> _verifyPlayer() async {
    final playerId = _playerIdController.text.trim();
    if (playerId.isEmpty) return false;

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

      if (valid && name != null) {
        try {
          await _playerCache.savePlayer(playerId, name);
          await _loadRecentPlayers();
          await _saveLastValidPlayerId(playerId);
        } catch (_) {
          // Le cache est une commodité locale : une erreur de cache ne
          // doit jamais invalider une vérification NafaCash réussie.
        }

        setState(() {
          _isFirstDeposit = result["isFirstDeposit"] == true;
        });
        return true;
      }
      return false;
    } catch (e) {
      setState(() {
        _verifying = false;
        _verifyError = e.toString();
      });
      return false;
    }
  }

  void _onPlayerIdChanged(String _) {
    if (_verifiedPlayerName != null ||
        _verifyError != null ||
        _isFirstDeposit) {
      setState(() {
        _verifiedPlayerName = null;
        _verifyError = null;
        _isFirstDeposit = false;
      });
    }
  }

  bool _isValidOrangePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 8) {
      return RegExp(r'^\d[4567]\d{6}$').hasMatch(digits);
    }

    if (digits.length == 11 && digits.startsWith('226')) {
      final local = digits.substring(3);
      return RegExp(r'^\d[4567]\d{6}$').hasMatch(local);
    }

    return false;
  }

  bool get _canContinue {
    final amount = _amount;
    final phone = _phoneController.text.trim();
    final playerId = _playerIdController.text.trim();
    return amount != null &&
        amount >= _minDeposit &&
        playerId.isNotEmpty &&
        _isValidOrangePhone(phone) &&
        !_creating &&
        !_previewing &&
        !_verifying;
  }

  Future<void> _previewDeposit() async {
    final amount = _amount;
    final playerId = _playerIdController.text.trim();
    final phone = _phoneController.text.trim();

    if (amount == null) return;

    setState(() {
      _previewing = true;
      _previewError = null;
      _createError = null;
    });

    // Verification automatique : l'utilisateur n'a pas besoin d'appuyer
    // sur "Vérifier" au prealable si l'ID n'a pas deja ete valide.
    if (_verifiedPlayerName == null) {
      final verified = await _verifyPlayer();
      if (!mounted) return;
      if (!verified) {
        setState(() => _previewing = false);
        return;
      }
    }

    if (_isValidOrangePhone(phone)) {
      await _saveLastValidPhone(phone);
    }

    try {
      final preview = await _kndApi.previewDeposit(
        playerId: playerId,
        amount: amount,
      );

      if (!mounted) return;

      setState(() {
        _previewing = false;
        _preview = preview;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _previewing = false;
        _previewError = e.toString();
      });
    }
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

  Widget _buildBonusMarketing() {
    final bonus = _bonusInfo;

    if (bonus == null) {
      return const SizedBox.shrink();
    }

    final bonusAmount = (bonus["bonusAmount"] as num?)?.toInt() ?? 0;
    final totalCredit = (bonus["totalCredit"] as num?)?.toInt() ?? 0;
    final percentage =
        (bonus["bonusPercentage"] as num?)?.toDouble() ?? 0;
    final minDeposit = (bonus["minDeposit"] as num?)?.toInt();

    if (bonusAmount <= 0) {
      if (minDeposit == null || minDeposit <= 0) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          "🎁 Bonus dès $minDeposit FCFA",
          style: TextStyle(
            color: Colors.orange[900],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "🎁 Bonus : +$bonusAmount FCFA "
        "(${percentage.toStringAsFixed(0)} %) → "
        "$totalCredit FCFA crédités",
        style: TextStyle(
          color: Colors.green[800],
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
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

  Widget _buildConfirmation(BuildContext context, Color primaryColor) {
    final preview = _preview!;

    final playerName = preview["playerName"]?.toString() ?? "";
    final playerId = preview["playerId"]?.toString() ?? "";
    final amount = (preview["amount"] as num?)?.toInt() ?? 0;
    final bonusPercentage =
        (preview["bonusPercentage"] as num?)?.toDouble() ?? 0;
    final bonusAmount = (preview["bonusAmount"] as num?)?.toInt() ?? 0;
    final totalCredit = (preview["totalCredit"] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Confirmation",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _creating ? null : () {
            setState(() {
              _preview = null;
              _previewError = null;
            });
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Vérifie ton dépôt",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 18),

                  _confirmationRow("Compte", playerName),
                  _confirmationRow("ID 1xBet", playerId),
                  _confirmationRow(
                    "Numéro Orange Money",
                    _phoneController.text.trim(),
                  ),
                  _confirmationRow(
                    "Montant",
                    "$amount FCFA",
                  ),
                  _confirmationRow(
                    "Bonus",
                    "$bonusAmount FCFA (${bonusPercentage.toStringAsFixed(0)} %)",
                  ),

                  const Divider(height: 28),

                  _confirmationRow(
                    "Crédit total",
                    "$totalCredit FCFA",
                    bold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_previewError != null) ...[
              Text(
                _previewError!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            if (_createError != null) ...[
              Text(
                _createError!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _creating ? null : _createDeposit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _creating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Continuer au paiement →",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _creating
                  ? null
                  : () {
                      setState(() {
                        _preview = null;
                        _previewError = null;
                      });
                    },
              child: const Text("Modifier"),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _confirmationRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                fontSize: bold ? 17 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1A56DB);

    if (_preview != null) {
      return _buildConfirmation(context, primaryColor);
    }

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
                    onChanged: (_) => _onAmountChanged(),
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
                  const SizedBox(height: 8),
                  _buildBonusMarketing(),
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
                  const Text(
                    "Ton compte 1xBet",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (_isFirstDeposit) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "🎉 Première recharge : bonus spécial applicable",
                        style: TextStyle(
                          color: Colors.purple[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                           contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _verifying ? null : _verifyPlayer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _verifying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Vérifier"),
                      ),
                    ],
                  ),
                  if (_recentPlayers.isNotEmpty &&
                      _verifiedPlayerName == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      "Comptes récents",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recentPlayers.map((player) {
                        return GestureDetector(
                          onTap: () {
                            _playerIdController.text = player["id"] ?? "";
                            setState(() {
                              _verifiedPlayerName = null;
                              _verifyError = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${player["id"]} · ${player["name"]}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (_verifiedPlayerName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _verifiedPlayerName!,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Vérifie bien le nom avant de continuer",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  if (_verifyError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _verifyError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
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
                  if (_phoneController.text.trim().isNotEmpty &&
                      !_isValidOrangePhone(_phoneController.text)) ...[
                    const SizedBox(height: 6),
                    const Text(
                      "Numéro Orange incorrect",
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_previewError != null) ...[
              Text(_previewError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _canContinue ? _previewDeposit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _previewing
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
