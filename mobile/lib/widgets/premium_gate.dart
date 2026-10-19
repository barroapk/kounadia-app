import 'package:flutter/material.dart';
import '../screens/account_screen.dart';
import '../services/account.dart';
import 'forecast_card.dart' show K;
import '../l10n/tr.dart';

/// Affiche [child] aux abonnés Premium ; sinon une présentation de la rubrique + les offres.
class PremiumGate extends StatelessWidget {
  final Widget child;
  final String title;
  final String pitch;
  final List<String> perks;
  final IconData icon;
  final bool standalone;
  PremiumGate({
    super.key,
    required this.child,
    required this.title,
    required this.pitch,
    required this.perks,
    this.icon = Icons.workspace_premium_rounded,
    this.standalone = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KUser?>(
      valueListenable: Account.user,
      builder: (_, u, __) {
        if (u?.premium ?? false) return child;
        final promo = _promo(context, u != null);
        if (!standalone) return Scaffold(backgroundColor: K.bg, body: promo);
        return Scaffold(
          backgroundColor: K.bg,
          appBar: AppBar(
              backgroundColor: K.bg, foregroundColor: K.text, title: T(title, style: TextStyle(fontWeight: FontWeight.w800))),
          body: promo,
        );
      },
    );
  }

  Widget _promo(BuildContext context, bool logged) {
    return ListView(padding: EdgeInsets.fromLTRB(18, 18, 18, 96), children: [
      Center(
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF8A6A12), Color(0xFFD4A017)]),
            shape: BoxShape.circle,
          ),
          child: Stack(alignment: Alignment.center, children: [
            Icon(icon, color: Colors.white, size: 40),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(color: K.bg, shape: BoxShape.circle),
                child: Icon(Icons.lock_rounded, color: Color(0xFFD4A017), size: 16),
              ),
            ),
          ]),
        ),
      ),
      SizedBox(height: 16),
      T(title, textAlign: TextAlign.center, style: TextStyle(color: K.text, fontSize: 22, fontWeight: FontWeight.w900)),
      SizedBox(height: 8),
      T(pitch, textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 14, height: 1.45)),
      SizedBox(height: 18),
      Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.border)),
        child: Column(children: [
          for (final p in perks)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_circle_rounded, color: K.green, size: 19),
                SizedBox(width: 10),
                Expanded(child: T(p, style: TextStyle(color: K.text, fontSize: 14, height: 1.35))),
              ]),
            ),
        ]),
      ),
      SizedBox(height: 18),
      T('Dès ${fcfa(kPlans.first.price)} les 3 jours · ${fcfa(kPlans[2].price)} le mois',
          textAlign: TextAlign.center, style: TextStyle(color: K.amber, fontSize: 14, fontWeight: FontWeight.w800)),
      SizedBox(height: 12),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: Color(0xFFD4A017), foregroundColor: Colors.black, minimumSize: Size.fromHeight(52)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountScreen())),
        icon: Icon(Icons.workspace_premium_rounded),
        label: T(logged ? 'Débloquer avec Premium' : 'Créer mon compte et débloquer',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
      ),
      SizedBox(height: 10),
      T('Paiement Mobile Money · Sans engagement · 18+ · Aucun gain garanti',
          textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11.5)),
    ]);
  }
}
