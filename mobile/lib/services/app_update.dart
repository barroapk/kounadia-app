import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/tr.dart';
import '../config/store.dart';
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
  static const _laterKey = 'upd_later';

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
    if (kAppBuild <= 0 || kPlay) return; // compilation de test, ou Play Store (il gère les mises à jour)
    final rel = await latest();
    if (rel == null || rel.build <= kAppBuild || !context.mounted) {
      pending.value = null;
      return;
    }
    pending.value = rel;
    // « Plus tard » : la fenêtre ne revient pas avant 24 h (le bandeau en haut reste visible).
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getInt(_laterKey) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - t < const Duration(hours: 24).inMilliseconds) return;
    } catch (_) {}
    if (!context.mounted) return;
    final s = _shown;
    if (s != null && DateTime.now().difference(s) < const Duration(hours: 1)) return;
    _shown = DateTime.now();
    if (context.mounted) await show(context, rel);
  }

  /// Depuis Paramètres : vérification à la demande.
  static Future<void> checkNow(BuildContext context) async {
    final m = ScaffoldMessenger.of(context);
    if (kPlay) {
      m.showSnackBar(SnackBar(content: Text(tr('Les mises à jour se font par le Play Store.'))));
      return;
    }
    m.showSnackBar(SnackBar(duration: const Duration(seconds: 2), content: Text(tr('Recherche de mise à jour…'))));
    final rel = await latest();
    if (!context.mounted) return;
    m.hideCurrentSnackBar();
    if (rel == null) {
      m.showSnackBar(SnackBar(content: Text(tr('Vérification impossible. Vérifie internet puis réessaie.'))));
    } else if (kIsWeb || rel.build <= kAppBuild || kAppBuild <= 0) {
      m.showSnackBar(SnackBar(content: Text(tr('Tu as déjà la dernière version.'))));
    } else {
      await show(context, rel);
    }
  }

  /// Rien ne démarre tout seul : l'utilisateur choisit « Mettre à jour » ou « Plus tard ».
  static Future<void> show(BuildContext context, AppRelease rel) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateDialog(rel),
    );
    // Fenêtre fermée sans installer : on ne la remontre pas avant 24 h.
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_laterKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}

/// Carte de mise à jour : téléchargement dans l'app (barre de progression), puis installation.
/// L'installation se fait par-dessus l'ancienne version : compte et données sont conservés.
class _UpdateDialog extends StatefulWidget {
  final AppRelease rel;
  const _UpdateDialog(this.rel);

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> with WidgetsBindingObserver {
  static const _ch = MethodChannel('kounadia/update');
  double? _progress; // null = pas commencé
  int _got = 0, _total = 0;
  String? _error;
  File? _file;
  bool _needPerm = false, _cancel = false, _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _cancel = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Retour des réglages Android après avoir autorisé l'installation : on installe.
    if (s == AppLifecycleState.resumed && _needPerm && _file != null) _install();
  }

  String _mo(int b) => (b / 1048576).toStringAsFixed(1).replaceAll('.', ',');

  Future<void> _download() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    final rel = widget.rel;
    http.Client? client;
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/update');
      await dir.create(recursive: true);
      final f = File('${dir.path}/kounadia-${rel.build}.apk');
      // Anciennes versions téléchargées : supprimées.
      for (final e in dir.listSync()) {
        if (e is File && e.path != f.path) {
          try {
            e.deleteSync();
          } catch (_) {}
        }
      }
      if (await f.exists() && rel.size > 0 && await f.length() == rel.size) {
        _done(f);
        return;
      }
      client = http.Client();
      final res = await client.send(http.Request('GET', Uri.parse(rel.url))).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      _total = res.contentLength ?? rel.size;
      final tmp = File('${f.path}.part');
      final sink = tmp.openWrite();
      _got = 0;
      var shown = -1;
      try {
        await for (final chunk in res.stream.timeout(const Duration(seconds: 30))) {
          if (_cancel) throw const HttpException('annulé');
          sink.add(chunk);
          _got += chunk.length;
          final pct = _total > 0 ? (_got * 100 ~/ _total) : 0;
          if (pct != shown && mounted) {
            shown = pct;
            setState(() => _progress = _total > 0 ? _got / _total : null);
          }
        }
      } finally {
        await sink.close();
      }
      // Vérification : fichier complet et vraie application Android (commence par « PK »).
      final head = await tmp.openRead(0, 2).first;
      if ((_total > 0 && _got != _total) || _got < 1000000 || head.length < 2 || head[0] != 0x50 || head[1] != 0x4B) {
        await tmp.delete();
        throw const HttpException('fichier incomplet');
      }
      await tmp.rename(f.path);
      _done(f);
    } catch (e) {
      if (!mounted || _cancel) return;
      setState(() {
        _progress = null;
        _error = tr('Téléchargement interrompu. Vérifie internet puis réessaie.');
      });
    } finally {
      client?.close();
    }
  }

  void _done(File f) {
    if (!mounted) return;
    setState(() {
      _file = f;
      _progress = 1;
    });
  }

  Future<void> _install() async {
    final f = _file;
    if (f == null || _busy) return;
    _busy = true;
    try {
      final ok = await _ch.invokeMethod<bool>('canInstall') ?? false;
      if (!ok) {
        setState(() => _needPerm = true);
        await _ch.invokeMethod('allowInstall');
        return;
      }
      setState(() => _needPerm = false);
      await _ch.invokeMethod('install', {'path': f.path});
    } catch (_) {
      if (mounted) setState(() => _error = tr("Installation impossible. Utilise le lien du site ci-dessous."));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rel = widget.rel;
    final ready = _file != null;
    final pct = ((_progress ?? 0) * 100).round();
    final idle = _progress == null && _file == null && _error == null;
    Widget body;
    if (idle) {
      body = Text(
        tr('Installe la nouvelle version pour profiter des dernières améliorations. Tes données et ton compte sont conservés.'),
        textAlign: TextAlign.center,
        style: TextStyle(color: K.muted, height: 1.4, fontSize: 13.5),
      );
    } else if (_error != null) {
      body = Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: K.red, height: 1.4, fontSize: 13.5));
    } else if (ready) {
      body = Text(
        _needPerm
            ? tr("Autorise KOUNADIA à installer la mise à jour (interrupteur « Autoriser »), puis reviens ici.")
            : tr('Téléchargement terminé. Touche « Mettre à jour » : ton compte et tes données sont conservés.'),
        textAlign: TextAlign.center,
        style: TextStyle(color: K.muted, height: 1.4, fontSize: 13.5),
      );
    } else {
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress == null || _total <= 0 ? null : _progress,
            minHeight: 10,
            backgroundColor: K.border,
            color: K.indigo,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _total > 0 ? '${tr('Téléchargement')} $pct % · ${_mo(_got)} / ${_mo(_total)} Mo' : tr('Téléchargement…'),
          style: TextStyle(color: K.text, fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ]);
    }
    return AlertDialog(
      backgroundColor: K.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(ready ? Icons.check_circle_rounded : Icons.system_update_rounded,
          color: ready ? K.green : K.indigoText, size: 38),
      title: Text(ready ? tr('Nouvelle version prête') : tr('Mise à jour disponible'),
          textAlign: TextAlign.center, style: TextStyle(color: K.text, fontWeight: FontWeight.w900)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('KOUNADIA ${rel.version}${rel.sizeText.isEmpty ? '' : ' · ${rel.sizeText}'}',
            textAlign: TextAlign.center, style: TextStyle(color: K.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        body,
        if (_error != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(rel.url), mode: LaunchMode.externalApplication),
            child: Text(tr('Télécharger depuis le site'), style: TextStyle(color: K.indigoText)),
          ),
        ],
      ]),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            _cancel = true;
            Navigator.pop(context);
          },
          child: Text(tr(_progress != null && !ready ? 'Annuler' : 'Plus tard'), style: TextStyle(color: K.muted)),
        ),
        if (idle)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: K.indigo),
            onPressed: Platform.isAndroid
                ? _download
                : () => launchUrl(Uri.parse(rel.url), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.download_rounded),
            label: Text(tr('Mettre à jour')),
          )
        else if (_error != null || !Platform.isAndroid)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: K.indigo),
            onPressed: Platform.isAndroid
                ? _download
                : () => launchUrl(Uri.parse(rel.url), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(Platform.isAndroid ? tr('Réessayer') : tr('Mettre à jour')),
          )
        else if (ready)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: K.green),
            onPressed: _install,
            icon: const Icon(Icons.install_mobile_rounded),
            label: Text(_needPerm ? tr('Autoriser') : tr('Mettre à jour')),
          ),
      ],
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
        if (rel == null || kPlay) return const SizedBox.shrink();
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
