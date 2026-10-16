import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/knd/player_cache_service.dart';
import '../../widgets/forecast_card.dart' show K;

final kWhatsAppNumber = '22655337782';
final kMinDeposit = 500;
final kMaxDeposit = 1000000;

class DepositScreen extends StatefulWidget {
  DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _id = TextEditingController();
  final _amount = TextEditingController();
  final _cache = PlayerCacheService();
  List<Map<String, String>> _recent = [];
  String? _idError;
  String? _amountError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _id.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final r = await _cache.getPlayers();
      if (mounted) setState(() => _recent = r);
    } catch (_) {}
  }

  String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  String? _checkId(String v) {
    final d = v.trim();
    if (d.isEmpty) return 'Saisis ton ID 1xBet.';
    if (!RegExp(r'^\d+$').hasMatch(d)) {
      return "L'ID 1xBet contient uniquement des chiffres.";
    }
    return null;
  }

  String? _checkAmount(String v) {
    final n = int.tryParse(v.replaceAll(RegExp(r'\s'), ''));
    if (n == null) return 'Saisis un montant.';
    if (n < kMinDeposit) return 'Montant minimum : ${_fmt(kMinDeposit)} FCFA.';
    if (n > kMaxDeposit) return 'Montant maximum : ${_fmt(kMaxDeposit)} FCFA.';
    return null;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _send() async {
    final idErr = _checkId(_id.text);
    final amErr = _checkAmount(_amount.text);
    setState(() {
      _idError = idErr;
      _amountError = amErr;
    });
    if (idErr != null || amErr != null) return;

    final id = _id.text.trim();
    final amount = int.parse(_amount.text.replaceAll(RegExp(r'\s'), ''));
    final msg = 'Bonjour KOUNADIA 👋\n'
        'Je souhaite effectuer un *DÉPÔT* 1xBet.\n\n'
        '• ID 1xBet : $id\n'
        '• Montant : ${_fmt(amount)} FCFA\n\n'
        'Merci de me confirmer la procédure.';
    final uri = Uri.parse('https://wa.me/$kWhatsAppNumber?text=${Uri.encodeComponent(msg)}');

    setState(() => _sending = true);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) {
        final known = _recent.firstWhere((p) => p['id'] == id, orElse: () => {'name': ''});
        await _cache.savePlayer(id, known['name'] ?? '');
        await _loadRecent();
      } else {
        _snack("WhatsApp n'est pas disponible sur ce téléphone.");
      }
    } catch (_) {
      _snack("Impossible d'ouvrir WhatsApp. Réessaie dans un instant.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _deco(String hint, String? error, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: K.muted),
      errorText: error,
      counterText: '',
      prefixIcon: Icon(icon, color: K.muted),
      filled: true,
      fillColor: K.card,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: K.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: K.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: K.indigo, width: 1.5),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Text(t,
            style: TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w700)),
      );

  Widget _pill(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: K.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: K.border),
        ),
        child: Text(text,
            style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        backgroundColor: K.bg,
        foregroundColor: K.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Dépôt 1xBet', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0x2225D366),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0x5525D366)),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ton dépôt est traité par notre agent sur WhatsApp. '
                    'Remplis le formulaire puis envoie le message pré-rempli.',
                    style: TextStyle(color: K.text, fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          _label('ID 1xBet'),
          TextField(
            controller: _id,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w600),
            decoration: _deco('Ex : 123456789', _idError, Icons.badge_outlined),
            onChanged: (_) {
              if (_idError != null) setState(() => _idError = null);
            },
          ),
          if (_recent.isNotEmpty) ...[
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Derniers ID utilisés',
                  style: TextStyle(color: K.muted, fontSize: 12)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recent.map<Widget>((p) {
                final id = p['id'] ?? '';
                final name = p['name'] ?? '';
                return _pill(name.isEmpty ? id : '$id · $name', () {
                  _id.text = id;
                  setState(() => _idError = null);
                });
              }).toList(),
            ),
          ],
          _label('Montant (FCFA)'),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 7,
            style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w600),
            decoration: _deco('Ex : 5000', _amountError, Icons.payments_outlined),
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [1000, 2000, 5000, 10000, 25000]
                .map<Widget>((v) => _pill('${_fmt(v)} F', () {
                      _amount.text = '$v';
                      setState(() => _amountError = null);
                    }))
                .toList(),
          ),
          SizedBox(height: 30),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.send_rounded),
              label: Text('Envoyer sur WhatsApp',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Réservé aux personnes majeures. Jouez de manière responsable.',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
