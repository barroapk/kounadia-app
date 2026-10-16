import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/forecast_card.dart' show K;
import '../widgets/k_ui.dart';
import 'football/facts_screen.dart';
import 'football/form_screen.dart';
import 'football/tables_screen.dart';

const kAppVersion = '1.0.0';
const _supportEmail = 'pierreclavers56@gmail.com';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _open(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  void _snack(BuildContext c, String m) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _contact(BuildContext c) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent('KOUNADIA $kAppVersion - Support')}',
    );
    try {
      if (!await launchUrl(uri) && c.mounted) _snack(c, 'Aucune application e-mail trouvée');
    } catch (_) {
      if (c.mounted) _snack(c, 'Aucune application e-mail trouvée');
    }
  }

  void _info(BuildContext c, String title, String body) {
    showDialog<void>(
      context: c,
      builder: (ctx) => AlertDialog(
        backgroundColor: K.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(color: K.text, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Text(body, style: const TextStyle(color: K.text, height: 1.45, fontSize: 14)),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: K.indigo),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, Color color, String title, String sub, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: K.muted, fontSize: 12.5)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: K.muted),
          ]),
        ),
      );

  Widget _header() => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 30),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('KOUNADIA',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
              SizedBox(height: 3),
              Text('Scores · Pronostics · Statistiques',
                  style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 13)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: kAppBar('Paramètres'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _header(),
          kTitle('Football'),
          kDividers([
            _tile(Icons.leaderboard_rounded, K.indigoText, 'Classements', 'Tous les championnats du monde',
                () => _open(context, const TablesScreen())),
            _tile(Icons.lightbulb_rounded, K.amber, 'Faits du jour', 'Séries et chiffres clés des matchs',
                () => _open(context, const FactsScreen())),
            _tile(Icons.trending_up_rounded, K.green, 'Forme des équipes', 'Les équipes en forme et en difficulté',
                () => _open(context, const FormScreen())),
          ]),
          kTitle('Application'),
          kDividers([
            _tile(Icons.share_rounded, const Color(0xFF06B6D4), 'Partager KOUNADIA', 'Invite tes amis',
                () => Share.share(
                    'Découvre KOUNADIA : scores en direct, classements et pronostics foot du jour, en français. ⚽')),
          ]),
          kTitle('Aide'),
          kDividers([
            _tile(Icons.mail_rounded, K.indigoText, 'Contacter le support', 'Signaler un problème ou une idée',
                () => _contact(context)),
            _tile(
              Icons.health_and_safety_rounded,
              K.red,
              'Jeu responsable',
              'À lire avant de parier',
              () => _info(
                context,
                'Jeu responsable',
                'Les paris sont réservés aux personnes majeures (18 ans et plus).\n\n'
                    'Ne mise jamais plus que ce que tu peux te permettre de perdre, '
                    'et ne cherche pas à « te refaire » après une perte.\n\n'
                    "Aucun pronostic n'est garanti, même avec une forte probabilité.\n\n"
                    'Si le jeu devient un problème, parles-en à un proche ou à un professionnel.',
              ),
            ),
            _tile(
              Icons.info_rounded,
              K.muted,
              'À propos',
              'Version $kAppVersion',
              () => _info(
                context,
                'KOUNADIA',
                'Scores en direct, classements, statistiques et pronostics de football.\n\n'
                    'Les pronostics sont fournis à titre informatif uniquement. '
                    'Ils ne constituent ni une garantie de résultat ni un conseil financier.\n\n'
                    'Développé au Burkina Faso 🇧🇫',
              ),
            ),
          ]),
          const SizedBox(height: 24),
          const Center(
            child: Text('KOUNADIA v$kAppVersion · Fait au Burkina Faso 🇧🇫',
                style: TextStyle(color: K.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
