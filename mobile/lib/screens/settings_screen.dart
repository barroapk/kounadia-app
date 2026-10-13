import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import 'competitions_settings_screen.dart';

const _appVersion = '1.0.0';
const _supportEmail = 'pierreclavers56@gmail.com';

class _C {
  static const bg = Color(0xFFEEF0F3);
  static const card = Color(0xFFFAFAFB);
  static const line = Color(0xFFE3E6EA);
  static const text = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const amber = Color(0xFFD97706);
  static const blue = Color(0xFF2563EB);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _server = 'Non vérifié';
  Color _serverColor = _C.muted;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _checkServer() async {
    _set(() {
      _checking = true;
      _server = 'Vérification… (jusqu\'à 1 min si le serveur dort)';
      _serverColor = _C.muted;
    });
    final sw = Stopwatch()..start();
    try {
      final r = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/'))
          .timeout(const Duration(seconds: 90));
      sw.stop();
      final ok = r.statusCode < 500;
      _set(() {
        _server = ok ? 'En ligne · ${sw.elapsedMilliseconds} ms' : 'Erreur ${r.statusCode}';
        _serverColor = ok ? _C.green : _C.red;
      });
    } catch (_) {
      _set(() {
        _server = 'Hors ligne · vérifie ta connexion';
        _serverColor = _C.red;
      });
    } finally {
      _set(() => _checking = false);
    }
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider le cache ?'),
        content: const Text(
            'Les images et fichiers temporaires seront supprimés. Tes réglages et ton historique sont conservés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    var freed = 0;
    try {
      final dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        await for (final e in dir.list(recursive: true, followLinks: false)) {
          if (e is File) {
            try {
              freed += await e.length();
            } catch (_) {}
          }
        }
        for (final e in dir.listSync()) {
          try {
            e.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
      PaintingBinding.instance.imageCache.clear();
    } catch (_) {}
    _snack('Cache vidé · ${(freed / (1024 * 1024)).toStringAsFixed(1)} Mo libérés');
  }

  Future<void> _share() async {
    await Share.share(
        'Découvre KOUNADIA : scores en direct, classements et pronostics foot du jour, en français. ⚽');
  }

  Future<void> _contact() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent('KOUNADIA $_appVersion - Support')}',
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok) _snack('Aucune application e-mail trouvée');
    } catch (_) {
      _snack('Aucune application e-mail trouvée');
    }
  }

  void _info(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body, style: const TextStyle(height: 1.4))),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.green),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        foregroundColor: _C.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _header(),
          _section('Contenu', [
            _tile(
              icon: Icons.emoji_events_outlined,
              title: 'Compétitions affichées',
              subtitle: 'Choisis les championnats à suivre',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompetitionsSettingsScreen()),
              ),
            ),
          ]),
          _section('Application', [
            _tile(
              icon: Icons.cloud_outlined,
              iconColor: _C.blue,
              title: 'État du serveur',
              subtitle: _server,
              subColor: _serverColor,
              trailing: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _C.green))
                  : const Icon(Icons.refresh, color: _C.muted),
              onTap: _checking ? null : _checkServer,
            ),
            _tile(
              icon: Icons.cleaning_services_outlined,
              iconColor: _C.amber,
              title: 'Vider le cache',
              subtitle: 'Libère de l\'espace sur ton téléphone',
              onTap: _clearCache,
            ),
            _tile(
              icon: Icons.share_outlined,
              title: 'Partager KOUNADIA',
              subtitle: 'Invite tes amis',
              onTap: _share,
            ),
          ]),
          _section('Aide', [
            _tile(
              icon: Icons.mail_outline,
              iconColor: _C.blue,
              title: 'Contacter le support',
              subtitle: 'Signaler un problème ou une idée',
              onTap: _contact,
            ),
            _tile(
              icon: Icons.health_and_safety_outlined,
              iconColor: _C.red,
              title: 'Jeu responsable',
              subtitle: 'À lire avant de parier',
              onTap: () => _info(
                'Jeu responsable',
                'Les paris sont réservés aux personnes majeures (18 ans et plus).\n\n'
                    'Ne mise jamais plus que ce que tu peux te permettre de perdre, '
                    'et ne cherche pas à « te refaire » après une perte.\n\n'
                    'Aucun pronostic n\'est garanti, même avec une forte confiance.\n\n'
                    'Si le jeu devient un problème, parles-en à un proche ou à un professionnel.',
              ),
            ),
          ]),
          _section('À propos', [
            _tile(
              icon: Icons.info_outline,
              iconColor: _C.muted,
              title: 'À propos de KOUNADIA',
              subtitle: 'Version $_appVersion',
              onTap: () => _info(
                'KOUNADIA',
                'Scores, classements et pronostics de football.\n\n'
                    'Les pronostics sont fournis à titre informatif uniquement. '
                    'Ils ne constituent ni une garantie de résultat ni un conseil financier.\n\n'
                    'Développé au Burkina Faso 🇧🇫',
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.sports_soccer, color: Colors.white, size: 30),
          ),
          SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KOUNADIA',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              SizedBox(height: 2),
              Text('Version $_appVersion',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> tiles) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        children.add(const Divider(height: 1, indent: 64, color: _C.line));
      }
      children.add(tiles[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(
                  color: _C.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.line),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? subColor,
    Color iconColor = _C.green,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              color: _C.text, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style: TextStyle(color: subColor ?? _C.muted, fontSize: 13)),
      trailing: trailing ??
          (onTap != null ? const Icon(Icons.chevron_right, color: _C.muted) : null),
    );
  }
}
