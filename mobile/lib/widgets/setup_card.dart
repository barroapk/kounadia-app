import 'package:flutter/material.dart';
import '../config/countries.dart';
import '../services/analytics.dart';
import '../services/currency.dart';
import '../services/user_prefs.dart';
import 'forecast_card.dart' show K;
import 'region_pickers.dart';
import '../l10n/tr.dart';

/// Première ouverture : pays + langue. Renvoie true (s'inscrire), false (se connecter) ou null.
Future<bool?> maybeShowSetup(BuildContext context) async {
  if (UserPrefs.done) return null;
  return showDialog<bool?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(canPop: false, child: _SetupDialog()),
  );
}

class _SetupDialog extends StatefulWidget {
  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> {
  late KCountry _c = UserPrefs.country ?? UserPrefs.guess();
  late String _lang = UserPrefs.done ? UserPrefs.lang : UserPrefs.supported(_c.lang);
  bool _langTouched = false;
  bool _countryTouched = false;

  @override
  void initState() {
    super.initState();
    // Pays détecté automatiquement : langue, monnaie et heure suivent.
    if (UserPrefs.country == null) {
      UserPrefs.detect().then((c) {
        if (!mounted || _countryTouched) return;
        setState(() {
          _c = c;
          if (!_langTouched) _lang = UserPrefs.supported(c.lang);
        });
        if (!_langTouched) UserPrefs.setLang(_lang);
      });
    }
  }

  Future<void> _finish(bool? auth) async {
    await UserPrefs.finishSetup(_c, _lang);
    Fx.init();
    Analytics.log('setup_done', {'country': _c.iso, 'lang': _lang});
    if (mounted) Navigator.pop(context, auth);
  }

  Widget _box(String label, String flag, String value, String sub, VoidCallback onTap) => Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Material(
          color: K.bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
              child: Row(children: [
                T(flag, style: TextStyle(fontSize: 26)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    T(label, style: TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .6)),
                    SizedBox(height: 2),
                    T(value, style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    if (sub.isNotEmpty) T(sub, style: TextStyle(color: K.muted, fontSize: 12)),
                  ]),
                ),
                Icon(Icons.expand_more_rounded, color: K.muted),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final small = TextStyle(color: K.indigoText, fontSize: 13.5, fontWeight: FontWeight.w700);
    return Dialog(
      backgroundColor: K.card,
      insetPadding: EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 34),
            ),
          ),
          SizedBox(height: 14),
          T('Bienvenue sur KOUNADIA',
              textAlign: TextAlign.center, style: TextStyle(color: K.text, fontSize: 21, fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          T('Choisis ton pays et ta langue pour une application faite pour toi.',
              textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.35)),
          SizedBox(height: 18),
          _box('PAYS', _c.flag, _c.label, '${_c.currency} · ${Fx.symbol(_c.currency)} · ${UserPrefs.gmt()}',
              () async {
            final c = await pickCountry(context, selected: _c.iso);
            if (c != null) {
              setState(() {
                _countryTouched = true;
                _c = c;
                if (!_langTouched) _lang = UserPrefs.supported(c.lang);
              });
              UserPrefs.setLang(_lang);
            }
          }),
          _box('LANGUE', '🌐', langName(_lang), '', () async {
            final l = await pickLang(context, _lang);
            if (l != null) {
              setState(() {
                _lang = l;
                _langTouched = true;
              });
              UserPrefs.setLang(l);
            }
          }),
          SizedBox(height: 4),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: K.indigo,
              minimumSize: Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _finish(null),
            child: T('Terminé', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)),
          ),
          SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => _finish(false), child: T('Se connecter', style: small)),
            T('ou', style: TextStyle(color: K.muted, fontSize: 13)),
            TextButton(onPressed: () => _finish(true), child: T("S'inscrire", style: small)),
          ]),
        ]),
      ),
    );
  }
}
