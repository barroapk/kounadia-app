import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/analytics.dart';
import '../../widgets/forecast_card.dart' show K;
import 'deposit_screen.dart' show kWhatsAppNumber;
import '../../l10n/tr.dart';

final kMinWithdrawal = 500;

class WithdrawalScreen extends StatefulWidget {
  WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _amount = TextEditingController();
  final _phone = TextEditingController();
  String? _amountError;
  String? _phoneError;
  bool _sending = false;

  @override
  void dispose() {
    _amount.dispose();
    _phone.dispose();
    super.dispose();
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: T(msg)));
  }

  Future<void> _send() async {
    final n = int.tryParse(_amount.text.trim());
    final phone = _phone.text.trim();
    setState(() {
      _amountError = n == null
          ? 'Saisis un montant.'
          : n < kMinWithdrawal
              ? 'Montant minimum : ${_fmt(kMinWithdrawal)} FCFA.'
              : null;
      _phoneError = phone.length < 8 ? 'Saisis un numéro valide (8 chiffres).' : null;
    });
    if (_amountError != null || _phoneError != null) return;

    final msg = 'Bonjour KOUNADIA SERVICE 👋\n'
        'Je souhaite effectuer un *RETRAIT* 1xBet.\n\n'
        '• Montant : ${_fmt(n!)} FCFA\n'
        '• Numéro Orange Money : $phone\n\n'
        'Merci de me confirmer la procédure.';
    final uri = Uri.parse('https://wa.me/$kWhatsAppNumber?text=${Uri.encodeComponent(msg)}');

    setState(() => _sending = true);
    try {
      Analytics.log('withdraw_whatsapp');
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack("WhatsApp n'est pas disponible sur ce téléphone.");
    } catch (_) {
      _snack("Impossible d'ouvrir WhatsApp. Réessaie dans un instant.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _deco(String hint, String? error, IconData icon) => InputDecoration(
        hintText: tr(hint),
        hintStyle: TextStyle(color: K.muted),
        errorText: error == null ? null : tr(error),
        counterText: '',
        prefixIcon: Icon(icon, color: K.muted),
        filled: true,
        fillColor: K.card,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: K.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: K.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: K.amber, width: 1.5)),
      );

  Widget _label(String t) => Padding(
        padding: EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: T(t, style: TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w700)),
      );

  Widget _pill(String text, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: K.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: K.border),
          ),
          child: T(text, style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        backgroundColor: K.bg,
        foregroundColor: K.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: T('Retrait 1xBet', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0x22F59E0B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0x55F59E0B)),
            ),
            child: Row(children: [
              Icon(Icons.north_east_rounded, color: K.amber, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: T(
                  'Ton retrait est traité par notre agent sur WhatsApp. '
                  'Remplis le formulaire puis envoie le message pré-rempli.',
                  style: TextStyle(color: K.text, fontSize: 14, height: 1.4),
                ),
              ),
            ]),
          ),
          _label('Montant à retirer (FCFA)'),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 7,
            style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w600),
            decoration: _deco('Ex : 10000', _amountError, Icons.payments_outlined),
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [2000, 5000, 10000, 25000, 50000]
                .map<Widget>((v) => _pill('${_fmt(v)} F', () {
                      _amount.text = '$v';
                      setState(() => _amountError = null);
                    }))
                .toList(),
          ),
          _label('Numéro Orange Money (pour recevoir)'),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 12,
            style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w600),
            decoration: _deco('Ex : 07 00 00 00', _phoneError, Icons.phone_android_rounded),
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
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
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.send_rounded),
              label: T('Envoyer sur WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          SizedBox(height: 18),
          T(
            'Réservé aux personnes majeures. Jouez de manière responsable.',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
