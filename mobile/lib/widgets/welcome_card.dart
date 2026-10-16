import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'forecast_card.dart' show K;

final _seenKey = 'welcome_seen_v1';

Future<void> maybeShowWelcome(BuildContext context) async {
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_seenKey) == true) return;
    if (!context.mounted) return;
    await showWelcome(context);
    await p.setBool(_seenKey, true);
  } catch (_) {}
}

Future<void> showWelcome(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(canPop: false, child: _WelcomeDialog()),
  );
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
              child: Text(title, style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w900)),
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
                TextSpan(text: '$title : ', style: TextStyle(color: K.text, fontWeight: FontWeight.w800)),
                TextSpan(text: text, style: TextStyle(color: K.muted)),
              ]),
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
        ]),
      );

  Widget _para(String t) => Text(t, style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.45));

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
                Text('Bienvenue sur KOUNADIA',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('Mettez la chance de votre côté',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _section('KOUNADIA, la chance', Icons.auto_awesome_rounded, K.amber, [
                  _para('« Kounadia » signifie la chance en dioula et en bambara. '
                      'Scores en direct, statistiques et pronostics réunis au même endroit '
                      'pour vous aider à parier plus malin.'),
                ]),
                _section('Comment ça marche', Icons.touch_app_rounded, K.indigoText, [
                  _point('Matchs', "scores en direct d'hier, aujourd'hui et demain. "
                      'Touchez un match : pronostics, forme, H2H, classement et stats. Appui long : favori ⭐.'),
                  _point('Prédictions', 'les pronostics gratuits du jour Kounadia IA et Expert.'),
                  _point('Coupons', 'créez un coupon selon la cote voulue, enregistrez-le et partagez-le en image.'),
                  _point('Historique', "nos pronostics validés d'hier et d'aujourd'hui."),
                  _point('Paramètres', 'classements, faits du jour, forme des équipes et thème clair / sombre.'),
                ]),
                _section('Dépôt & retrait 1xBet', Icons.swap_vert_rounded, K.green, [
                  _point('Rapide', 'touchez « Dépôt · Retrait 1xBet » : un agent KOUNADIA SERVICE vous répond sur WhatsApp.'),
                  _point('Code promo 99KND', '+200 % de bonus sur votre 1re recharge.'),
                ]),
                _section('Nous contacter', Icons.mail_rounded, Color(0xFF06B6D4), [
                  _para('Avis, partenariat ou publicité : Paramètres → Contacter le support.'),
                ]),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: K.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: K.border),
                  ),
                  child: Text(
                    'Fondé par M. Pierre Clavers BARRO,\njeune entrepreneur burkinabè 🇧🇫',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.4),
                  ),
                ),
                SizedBox(height: 10),
                Text('18+ · Jouez de manière responsable',
                    textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11.5)),
                SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: K.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Compris', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
