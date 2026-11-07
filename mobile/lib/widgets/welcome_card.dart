import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'forecast_card.dart' show K;
import '../screens/account_screen.dart';
import '../services/user_prefs.dart';
import '../config/store.dart';
import '../l10n/tr.dart';

final _seenKey = kV2 ? 'welcome_seen_k2' : 'welcome_seen_v2';

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
  // Une fonctionnalité : icône en couleur, titre et une phrase.
  Widget _feature(IconData icon, List<Color> g, String title, String text) => Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          SizedBox(height: 9),
          T(title, style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          T(text, style: TextStyle(color: K.muted, fontSize: 12.5, height: 1.35)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final features = [
      _feature(Icons.bolt_rounded, [Color(0xFF4F46E5), Color(0xFF7C3AED)], 'Faits du jour',
          'Séries, face-à-face, absents : ce qu\'il faut savoir avant chaque grand match.'),
      _feature(Icons.play_circle_rounded, [Color(0xFFEF4444), Color(0xFFF97316)], 'Direct et temps forts',
          'Scores minute par minute, buts en alerte et vidéos des temps forts.'),
      if (kV2)
        _feature(Icons.confirmation_number_rounded, [Color(0xFF16A34A), Color(0xFF22C55E)], 'Coupons du jour',
            'Chaque matin, des coupons prêts à jouer, code à copier en un geste.')
      else
        _feature(Icons.insights_rounded, [Color(0xFF16A34A), Color(0xFF22C55E)], 'Prédictions', 'Kounadia IA et nos experts, chaque jour.'),
      _feature(Icons.workspace_premium_rounded, [Color(0xFFB8860B), Color(0xFFF5C542)], 'Premium',
          'Coupons VIP, Coups sûrs et analyses, preuves chiffrées à l\'appui.'),
    ];
    return Dialog(
      backgroundColor: K.card,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: h * 0.88),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: EdgeInsets.fromLTRB(20, 26, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 34),
                ),
                SizedBox(height: 12),
                T('Bienvenue sur KOUNADIA',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                T('« Kounadia » : la chance, en dioula. Mets-la de ton côté.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Deux fonctionnalités par ligne.
                for (var i = 0; i < features.length; i += 2) ...[
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: features[i]),
                      SizedBox(width: 10),
                      Expanded(child: i + 1 < features.length ? features[i + 1] : SizedBox()),
                    ]),
                  ),
                  SizedBox(height: 10),
                ],
                SizedBox(height: 4),
                T('Dès 525 F pour 3 jours · 4 200 F le mois · 10 500 F les 3 mois. Sans engagement.',
                    textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12.5, height: 1.4)),
                if (!kPlay && UserPrefs.iso == 'BF') ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Icon(Icons.swap_vert_rounded, color: K.indigoText, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          T('Dépôt · Retrait 1xBet', style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                          T('Rapide via WhatsApp avec KOUNADIA SERVICE · code promo 99KND.',
                              style: TextStyle(color: K.muted, fontSize: 12.5)),
                        ]),
                      ),
                    ]),
                  ),
                ],
                SizedBox(height: 16),
                T('Une application de KOUNADIA SERVICE',
                    textAlign: TextAlign.center, style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                T('Des milliers de passionnés de football nous font confiance.',
                    textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12.5)),
                SizedBox(height: 8),
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
