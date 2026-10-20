import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/tr.dart';
import '../widgets/forecast_card.dart' show K;

/// Version de cette application (injectée à la compilation par GitHub Actions).
const kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
const kAppBuild = int.fromEnvironment('APP_BUILD', defaultValue: 0);

/// Dernière version publiée (fichier mis à jour automatiquement à chaque publication).
const _versionUrl = 'https://raw.githubusercontent.com/barroapk/kounadia-app/main/site/version.json';
const kApkUrl = 'https://github.com/barroapk/kounadia-app/releases/latest/download/kounadia.apk';

class AppRelease {
  final String version;
  final int build;
  final int size;
  final String url;
  AppRelease(this.version, this.build, this.size, this.url);

  String get sizeText => size <= 0 ? '' : '${(size / 1048576).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}

/// Avertit l'utilisateur quand une nouvelle version de KOUNADIA est disponible.
class AppUpdate {
  static Future<AppRelease?> latest() async {
    try {
      final r = await http
          .get(Uri.parse('$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch ~/ 600000}'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final j = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
      final b = (j['build'] as num?)?.toInt() ?? 0;
      if (b <= 0) return null;
      return AppRelease(
        (j['version'] ?? '').toString(),
        b,
        (j['size'] as num?)?.toInt() ?? 0,
        (j['url'] ?? kApkUrl).toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Au démarrage : au plus une fois par jour pour une même version.
  static Future<void> checkOnStart(BuildContext context) async {
    if (kAppBuild <= 0) return; // compilation de test
    final rel = await latest();
    if (rel == null || rel.build <= kAppBuild || !context.mounted) return;
    try {
      final p = await SharedPreferences.getInstance();
      final key = 'upd_${rel.build}';
      final last = p.getInt(key) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < 20 * 3600 * 1000) return;
      await p.setInt(key, now);
    } catch (_) {}
    if (context.mounted) await show(context, rel);
  }

  /// Depuis Paramètres : vérification à la demande.
  static Future<void> checkNow(BuildContext context) async {
    final m = ScaffoldMessenger.of(context);
    m.showSnackBar(SnackBar(duration: const Duration(seconds: 2), content: Text(tr('Recherche de mise à jour…'))));
    final rel = await latest();
    if (!context.mounted) return;
    m.hideCurrentSnackBar();
    if (rel == null) {
      m.showSnackBar(SnackBar(content: Text(tr('Vérification impossible. Vérifie internet puis réessaie.'))));
    } else if (rel.build <= kAppBuild || kAppBuild <= 0) {
      m.showSnackBar(SnackBar(content: Text(tr('Tu as déjà la dernière version.'))));
    } else {
      await show(context, rel);
    }
  }

  static Future<void> show(BuildContext context, AppRelease rel) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: K.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.system_update_rounded, color: K.indigoText, size: 36),
        title: Text(tr('Mise à jour disponible'),
            textAlign: TextAlign.center, style: TextStyle(color: K.text, fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'KOUNADIA ${rel.version}${rel.sizeText.isEmpty ? '' : ' · ${rel.sizeText}'}',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            tr("Installe la nouvelle version pour profiter des dernières améliorations. Tes données et ton compte sont conservés."),
            textAlign: TextAlign.center,
            style: TextStyle(color: K.muted, height: 1.4, fontSize: 13.5),
          ),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Plus tard'), style: TextStyle(color: K.muted))),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: K.indigo),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await launchUrl(Uri.parse(rel.url), mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            icon: const Icon(Icons.download_rounded),
            label: Text(tr('Mettre à jour')),
          ),
        ],
      ),
    );
  }
}
