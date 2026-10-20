import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/forecast_card.dart' show K;
import '../widgets/k_ui.dart';
import '../services/analytics.dart';
import '../widgets/theme_selector.dart';
import '../widgets/welcome_card.dart';
import 'football/facts_screen.dart';
import 'football/form_screen.dart';
import 'football/tables_screen.dart';
import 'fav_leagues_screen.dart';
import 'account_screen.dart';
import '../widgets/premium_gate.dart';
import '../services/account.dart';
import '../services/user_prefs.dart';
import '../services/currency.dart';
import '../widgets/region_pickers.dart';
import 'guide_screen.dart';
import 'legal_screen.dart';
import '../l10n/tr.dart';
import '../services/app_update.dart';
import '../services/notif.dart';

final _supportEmail = 'pierreclavers56@gmail.com';
final _businessWhatsApp = '22655337782';

class SettingsScreen extends StatelessWidget {
  SettingsScreen({super.key});

  void _open(BuildContext c, Widget w) {
    Analytics.log('settings_open', {'page': w.runtimeType.toString()});
    Navigator.push(c, MaterialPageRoute(builder: (_) => w));
  }

  void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: T(m)));

  Future<void> _launch(BuildContext c, Uri uri, String fail) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && c.mounted) _snack(c, fail);
    } catch (_) {
      if (c.mounted) _snack(c, fail);
    }
  }

  Uri _mail(String subject) => Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: 'subject=${Uri.encodeComponent(subject)}',
      );

  Uri _wa(String text) => Uri.parse('https://wa.me/$_businessWhatsApp?text=${Uri.encodeComponent(text)}');

  /// Fenêtre de contact : WhatsApp ou e-mail, avec un message déjà préparé.
  void _contactSheet(BuildContext c, {required String title, required String pitch, required String subject, required String message, required String event}) {
    Analytics.log(event);
    showModalBottomSheet<void>(
      context: c,
      backgroundColor: K.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: K.border, borderRadius: BorderRadius.circular(4))),
            ),
            SizedBox(height: 16),
            T(title, style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            T(pitch, style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.4)),
            SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Color(0xFF25D366), minimumSize: Size.fromHeight(50)),
              onPressed: () {
                Navigator.pop(ctx);
                _launch(c, _wa(message), 'WhatsApp introuvable');
              },
              icon: Icon(Icons.chat_rounded),
              label: T('Écrire sur WhatsApp', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(50), side: BorderSide(color: K.border)),
              onPressed: () {
                Navigator.pop(ctx);
                _launch(c, _mail(subject), 'Aucune application e-mail trouvée');
              },
              icon: Icon(Icons.mail_rounded, color: K.text),
              label: T('Envoyer un e-mail', style: TextStyle(color: K.text, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }

  void _info(BuildContext c, String title, String body) {
    showDialog<void>(
      context: c,
      builder: (ctx) => AlertDialog(
        backgroundColor: K.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: T(title, style: TextStyle(color: K.text, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(child: T(body, style: TextStyle(color: K.text, height: 1.45, fontSize: 14))),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: K.indigo),
            onPressed: () => Navigator.pop(ctx),
            child: T('Compris'),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, Color color, String title, String sub, VoidCallback onTap, {Widget? trailing}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color, size: 21),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                T(title, style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w700)),
                if (sub.isNotEmpty) ...[
                  SizedBox(height: 2),
                  T(sub, style: TextStyle(color: K.muted, fontSize: 12.5)),
                ],
              ]),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: K.muted),
          ]),
        ),
      );

  /// En-tête : profil + statut Premium (ou invitation à s'abonner).
  Widget _header(BuildContext context) => ValueListenableBuilder<KUser?>(
        valueListenable: Account.user,
        builder: (_, u, __) {
          final prem = u?.premium ?? false;
          final title = u == null ? 'KOUNADIA' : u.username;
          final sub = u == null
              ? 'Connecte-toi pour sauvegarder tes favoris'
              : prem
                  ? '👑 Premium actif'
                  : 'Compte gratuit';
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _open(context, AccountScreen()),
              child: Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: prem ? [Color(0xFF8A6A12), Color(0xFFD4A017)] : [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0x33FFFFFF),
                      child: u == null
                          ? Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 28)
                          : T(u.username.isEmpty ? '?' : u.username[0].toUpperCase(),
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        T(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        T(sub, style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 13)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  ]),
                  if (!prem) ...[
                    SizedBox(height: 14),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Icon(Icons.workspace_premium_rounded, color: Color(0xFFD4A017), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: T(tr('Passe à Premium · dès 250 F') + (Fx.approx(250) == null ? '' : ' (${Fx.approx(250)})'),
                              style: TextStyle(color: Color(0xFF1F2937), fontSize: 13.5, fontWeight: FontWeight.w800)),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: Color(0xFF4F46E5), size: 18),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: kAppBar('Paramètres'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _header(context),

          kTitle('Football'),
          kDividers([
            _tile(Icons.star_rounded, K.amber, 'Mes championnats', 'Tes favoris en premier dans Matchs',
                () => _open(context, FavLeaguesScreen())),
            ValueListenableBuilder<bool>(
              valueListenable: Notif.enabled,
              builder: (_, on, __) => _tile(Icons.notifications_active_rounded, K.red, 'Notifications en direct',
                  'Buts et résultats de tes favoris et coupons', () => Notif.setEnabled(!on),
                  trailing: Switch(value: on, activeThumbColor: K.indigo, onChanged: Notif.setEnabled)),
            ),
            _tile(Icons.leaderboard_rounded, K.indigoText, 'Classements', 'Tous les championnats du monde',
                () => _open(context, TablesScreen())),
            _tile(Icons.lightbulb_rounded, K.amber, 'Faits du jour', 'Séries et chiffres clés des matchs',
                () => _open(context, PremiumGate(
                    standalone: true,
                    title: "Faits du jour",
                    pitch: "Les séries et chiffres clés des matchs du jour, pour parier en connaissance de cause.",
                    perks: ["Séries en cours : victoires, buts, matchs nuls", "Chiffres clés de chaque équipe", "Mis à jour chaque jour"],
                    icon: Icons.lightbulb_rounded,
                    child: FactsScreen()))),
            _tile(Icons.trending_up_rounded, K.green, 'Forme des équipes', 'Les équipes en forme et en difficulté',
                () => _open(context, PremiumGate(
                    standalone: true,
                    title: "Forme des équipes",
                    pitch: "Repère en un coup d'œil les équipes en forme et celles en difficulté.",
                    perks: ["Équipes en forme et en difficulté", "Résultats récents de chaque équipe", "Tous les grands championnats"],
                    icon: Icons.trending_up_rounded,
                    child: FormScreen()))),
          ]),

          kTitle('Préférences'),
          ValueListenableBuilder<int>(
            valueListenable: UserPrefs.changed,
            builder: (_, __, ___) {
              final c = UserPrefs.country;
              return kDividers([
                _tile(Icons.public_rounded, K.green, 'Pays', c == null ? 'Choisir mon pays' : '${c.flag} ${c.label}',
                    () async {
                  final n = await pickCountry(context, selected: c?.iso);
                  if (n != null) await UserPrefs.setCountry(n);
                }),
                _tile(Icons.payments_rounded, K.amber, 'Devise', '${UserPrefs.currency} · ${Fx.symbol(UserPrefs.currency)}',
                    () async {
                  final v = await pickCurrency(context, UserPrefs.currency);
                  if (v != null) await UserPrefs.setCurrency(v);
                }),
                _tile(Icons.translate_rounded, K.indigoText, 'Langue', langName(UserPrefs.lang), () async {
                  final v = await pickLang(context, UserPrefs.lang);
                  if (v != null) await UserPrefs.setLang(v);
                }),
                _tile(Icons.schedule_rounded, Color(0xFF06B6D4), 'Fuseau horaire', '${UserPrefs.gmt()} · ${tr('heure du téléphone')}', () {},
                    trailing: SizedBox.shrink()),
              ]);
            },
          ),
          SizedBox(height: 12),
          ThemeSelector(),

          kTitle('KOUNADIA'),
          kDividers([
            _tile(Icons.campaign_rounded, Color(0xFFEC4899), 'Partenariat & publicité', 'Fais connaître ta marque sur KOUNADIA',
                () => _contactSheet(
                      context,
                      title: 'Partenariat & publicité',
                      pitch: 'Bannières dans l\'application, partenariats, offres pour bookmakers et marques : '
                          'parlons de ton projet. Réponse rapide de l\'équipe KOUNADIA.',
                      subject: 'KOUNADIA - Partenariat / Publicité',
                      message: 'Bonjour KOUNADIA 👋\nJe souhaite discuter d\'un partenariat / d\'une publicité sur l\'application.\n\nMon entreprise : \nMon projet : ',
                      event: 'contact_partner',
                    )),
            _tile(Icons.share_rounded, Color(0xFF06B6D4), 'Partager KOUNADIA', 'Invite tes amis',
                () => Share.share('${tr('⚽ KOUNADIA : scores en direct, prédictions IA et Coup sûr du jour. Essaie-la !')}\n👉 https://kounadia.pages.dev')),
            _tile(Icons.auto_awesome_rounded, K.amber, 'Découvrir KOUNADIA', 'Tout ce que l\'application t\'offre',
                () => showWelcome(context)),
          ]),

          kTitle('Aide'),
          kDividers([
            _tile(Icons.menu_book_rounded, K.green, "Guide d'utilisation", 'Tout savoir sur KOUNADIA',
                () => _open(context, GuideScreen())),
            _tile(Icons.support_agent_rounded, K.indigoText, 'Contacter le support', 'Un problème, une question, une idée',
                () => _contactSheet(
                      context,
                      title: 'Contacter le support',
                      pitch: 'Un souci avec l\'application ou ton abonnement ? Écris-nous, on te répond rapidement.',
                      subject: 'KOUNADIA $kAppVersion - Support',
                      message: 'Bonjour KOUNADIA 👋\nJ\'ai besoin d\'aide : ',
                      event: 'contact_support',
                    )),
            _tile(Icons.health_and_safety_rounded, K.red, 'Jeu responsable', '18+ · À lire avant de parier',
                () => _open(context, ResponsibleScreen())),
          ]),

          kTitle('Informations légales'),
          kDividers([
            _tile(Icons.description_rounded, K.indigoText, "Conditions d'utilisation", 'Les règles du service',
                () => _open(context, TermsScreen())),
            _tile(Icons.privacy_tip_rounded, K.green, 'Confidentialité', 'Tes données et tes droits',
                () => _open(context, PrivacyScreen())),
            _tile(Icons.system_update_rounded, K.indigoText, 'Mises à jour', 'Version $kAppVersion',
                () => AppUpdate.checkNow(context)),
            _tile(Icons.info_rounded, K.muted, 'À propos', 'Version $kAppVersion', () => _info(
                  context,
                  'KOUNADIA',
                  'Scores en direct, classements, statistiques et pronostics de football.\n\n'
                      'Les pronostics sont fournis à titre informatif uniquement. '
                      'Ils ne constituent ni une garantie de résultat ni un conseil financier.\n\n'
                      'Fondateur & PDG : Pierre Clavers BARRO\nKOUNADIA SERVICE\n\nDéveloppé au Burkina Faso 🇧🇫',
                )),
          ]),
          SizedBox(height: 24),
          Center(
            child: T('KOUNADIA SERVICE · v$kAppVersion\nFait au Burkina Faso 🇧🇫',
                textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
