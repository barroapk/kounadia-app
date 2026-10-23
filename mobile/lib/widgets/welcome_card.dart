import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'forecast_card.dart' show K;
import '../screens/account_screen.dart';
import '../services/user_prefs.dart';
import '../config/store.dart';
import '../l10n/tr.dart';

final _seenKey = 'welcome_seen_v2';

Future<void> maybeShowWelcome(BuildContext context) async {
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_seenKey) == true) return;
    if (!context.mounted) return;
    await showWelcome(context);
    await p.setBool(_seenKey, true);
  } catch (_) {}
}

Future<void> showWelcome(BuildContext context) async {
  final premium = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(canPop: false, child: _WelcomeDialog()),
  );
  if (premium == true && context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AccountScreen()));
  }
}

class _WelcomeDialog extends StatelessWidget {
  Widget _section(String title, IconData icon, Color c, List<Widget> children) => Padding(
        padding: EdgeInsets.only(top: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: c.withAlpha(40), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: c, size: 18),
            ),
            SizedBox(width: 10),
            Expanded(
              child: T(title, style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ]),
          SizedBox(height: 8),
          ...children,
        ]),
      );

  Widget _point(String title, String text) => Padding(
        padding: EdgeInsets.only(left: 6, bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: K.indigoText, shape: BoxShape.circle)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${tr(title)} : ', style: TextStyle(color: K.text, fontWeight: FontWeight.w800)),
                TextSpan(text: tr(text), style: TextStyle(color: K.muted)),
              ]),
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
        ]),
      );

  Widget _para(String t) => T(t, style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.45));

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: K.card,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: h * 0.86),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: Color(0x33FFFFFF), borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 34),
                ),
                SizedBox(height: 12),
                T('Bienvenue sur KOUNADIA',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                T('« Kounadia » : la chance, en dioula. Mets-la de ton côté.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _section('Gratuit, pour tous', Icons.sports_soccer_rounded, K.green, [
                  _point('Scores en direct', 'tous les championnats, minute par minute.'),
                  _point('Mes matchs', 'tes championnats favoris toujours en premier.'),
                  _point('Classements', 'le monde entier en un geste.'),
                ]),
                _section('Premium, pour aller plus loin', Icons.workspace_premium_rounded, Color(0xFFD4A017), [
                  _point('Prédictions', 'Kounadia IA et nos experts, chaque jour.'),
                  _point('Coup sûr', 'les sélections du jour les mieux notées par nos analyses.'),
                  _point('Coupons', 'un coupon prêt selon la cote que tu veux.'),
                  _point('Fiches match', 'forme, faits du jour et statistiques complètes.'),
                  _para('Dès 250 F pour 3 jours. Sans engagement.'),
                ]),
                if (!kPlay && UserPrefs.iso == 'BF')
                  _section('Dépôt · Retrait 1xBet', Icons.swap_vert_rounded, K.indigoText, [
                    _para('Rapide via WhatsApp avec KOUNADIA SERVICE · code promo 99KND.'),
                  ]),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: K.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: K.border),
                  ),
                  child: T(
                    'Fondé par M. Pierre Clavers BARRO,\njeune entrepreneur burkinabè 🇧🇫',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.4),
                  ),
                ),
                SizedBox(height: 10),
                T("18+ · Joue de manière responsable · aucun pronostic n'est garanti",
                    textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11.5)),
                SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(0xFFD4A017),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(Icons.workspace_premium_rounded),
                    label: T('Découvrir Premium', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ),
                SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: T('Explorer l\'application', style: TextStyle(color: K.muted, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
