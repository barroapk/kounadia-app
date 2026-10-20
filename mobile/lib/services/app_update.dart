import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  /// Nouvelle version connue et pas encore installée (bandeau permanent).
  static final pending = ValueNotifier<AppRelease?>(null);
  static DateTime? _shown;

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

  /// À chaque ouverture (et retour dans l'app après 1 h) : la carte revient tant que
  /// la nouvelle version n'est pas installée.
  static Future<void> checkOnStart(BuildContext context) async {
    if (kAppBuild <= 0) return; // compilation de test
    final rel = await latest();
    if (rel == null || rel.build <= kAppBuild || !context.mounted) {
      pending.value = null;
      return;
    }
    pending.value = rel;
    final s = _shown;
    if (s != null && DateTime.now().difference(s) < const Duration(hours: 1)) return;
    _shown = DateTime.now();
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
      barrierDismissible: false,
      builder: (ctx) => PopScope(canPop: false, child: AlertDialog(
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
      )),
    );
  }
}

/// Bandeau en haut de l'app tant qu'une mise à jour attend.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppRelease?>(
      valueListenable: AppUpdate.pending,
      builder: (_, rel, __) {
        if (rel == null) return const SizedBox.shrink();
        return Material(
          color: K.indigo,
          child: InkWell(
            onTap: () => AppUpdate.show(context, rel),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
              child: Row(children: [
                const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${tr('Mise à jour disponible')} · ${rel.version}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Text(tr('Mettre à jour'),
                      style: TextStyle(color: K.indigo, fontWeight: FontWeight.w900, fontSize: 12.5)),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
