import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/tr.dart';
import '../widgets/forecast_card.dart' show K;
import 'analytics.dart';
import 'fav_leagues.dart';
import 'notif.dart';
import 'primatips_service.dart' show frLeague;
import 'scores_service.dart';
import 'user_prefs.dart';

/// Accueil en douceur, une seule question par ouverture de l'app :
/// 1. « Quels championnats aimes-tu ? » (1er lancement, puis de temps en temps tant qu'il n'a rien choisi) ;
/// 2. relance des notifications quand elles ne sont pas autorisées (« Autoriser » ou « Plus tard »).
class Engage {
  static bool _done = false;

  static Future<void> run(BuildContext context) async {
    if (_done) return;
    _done = true;
    try {
      final p = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      p.setInt('eng_first', p.getInt('eng_first') ?? now);
      // Jours d'utilisation (pour ne relancer que les utilisateurs qui reviennent).
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final days = (p.getStringList('eng_days') ?? const <String>[]).toList();
      if (!days.contains(today)) {
        days.add(today);
        if (days.length > 30) days.removeAt(0);
        await p.setStringList('eng_days', days);
      }
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!context.mounted) return;
      if (await _askLeagues(context, p, days, now)) return;
      if (!context.mounted) return;
      await _askNotif(context, p, now);
    } catch (_) {}
  }

  // ---------- championnats préférés ----------

  static Future<bool> _askLeagues(BuildContext context, SharedPreferences p, List<String> days, int now) async {
    if (p.getBool('fav_chosen') == true || UserPrefs.iso == null) return false;
    final n = p.getInt('eng_lg_n') ?? 0;
    final last = p.getInt('eng_lg_at') ?? 0;
    if (n >= 4) return false;
    if (n > 0) {
      // Relance : au moins 3 jours après, et l'utilisateur est revenu au moins 2 jours depuis.
      final since = days.where((d) => DateTime.parse(d).millisecondsSinceEpoch > last).length;
      if (now - last < 3 * 86400000 || since < 2) return false;
    }
    await p.setInt('eng_lg_n', n + 1);
    await p.setInt('eng_lg_at', now);
    final groups = await _suggestions();
    if (!context.mounted || groups.isEmpty) return false;
    Analytics.log('ask_leagues', {'n': n + 1});
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: K.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _LeaguesSheet(groups: groups, preset: FavLeagues.set.value),
    );
    if (picked == null || picked.isEmpty) return true;
    await FavLeagues.load();
    for (final k in picked) {
      if (!FavLeagues.set.value.contains(k)) await FavLeagues.toggleExact(k);
    }
    await p.setBool('fav_chosen', true);
    Analytics.log('fav_onboard', {'n': picked.length});
    return true;
  }

  static const _africa = {
    'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CV', 'CM', 'CF', 'TD', 'KM', 'CG', 'CD', 'CI', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GM',
    'GH', 'GN', 'GW', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ', 'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL',
    'SO', 'ZA', 'SS', 'SD', 'TZ', 'TG', 'TN', 'UG', 'ZM', 'ZW',
  };
  static const _americas = {
    'AR', 'BO', 'BR', 'CA', 'CL', 'CO', 'CR', 'CU', 'DO', 'EC', 'SV', 'GT', 'HT', 'HN', 'JM', 'MX', 'NI', 'PA', 'PY', 'PE', 'US', 'UY', 'VE',
  };
  static const _asia = {
    'SA', 'AE', 'QA', 'KW', 'BH', 'OM', 'JO', 'LB', 'IQ', 'IR', 'SY', 'YE', 'IN', 'CN', 'JP', 'KR', 'ID', 'MY', 'TH', 'VN', 'SG', 'UZ', 'KZ',
  };
  static const _big = [
    'England - Premier League', 'Spain - La Liga', 'Italy - Serie A', 'Germany - Bundesliga', 'France - Ligue 1', 'Champions League',
    'Europa League', 'Portugal - Primeira Liga', 'Netherlands - Eredivisie', 'Saudi Arabia - Pro League',
  ];
  static const _byContinent = {
    'af': [
      'CAF Champions League', 'Morocco - Botola', 'Egypt - Premier League', 'South Africa - Premier Soccer League', 'Algeria - Ligue 1',
      'Tunisia - Ligue 1', 'Nigeria - NPFL', 'Ivory Coast - Ligue 1', 'Cameroon - Elite One', 'Senegal - Ligue 1',
    ],
    'am': ['Brazil - Serie A', 'Argentina - Liga Profesional', 'USA - MLS', 'Mexico - Liga MX', 'Colombia - Primera A'],
    'as': ['Saudi Arabia - Pro League', 'Qatar - Stars League', 'United Arab Emirates - Pro League', 'Japan - J1 League'],
    'eu': ['Scotland - Premiership', 'Belgium - Pro League', 'Turkiye - Super Lig', 'England - Championship', 'Spain - La Liga 2'],
  };

  /// Propositions : son pays (championnats vus dans les matchs), son continent, les grands championnats.
  static Future<List<(String, List<String>)>> _suggestions() async {
    final c = UserPrefs.country;
    final out = <(String, List<String>)>[];
    final used = <String>{};
    List<String> keep(Iterable<String> l) => [for (final k in l) if (used.add(k)) k];
    if (c != null) {
      final names = {for (final a in [...c.aliases, c.name]) a.toLowerCase()};
      final count = <String, int>{};
      try {
        final (days, _) = await ScoresService.load();
        for (final m in days.values.expand((l) => l)) {
          if (names.contains(m.country.trim().toLowerCase())) count[m.leagueLabel] = (count[m.leagueLabel] ?? 0) + 1;
        }
      } catch (_) {}
      final mine = count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
      final own = keep(mine.take(6));
      if (own.isEmpty && c.aliases.isNotEmpty) own.addAll(keep([c.aliases.first]));
      out.add(('${c.flag}  ${c.label}', own));
    }
    final iso = c?.iso ?? '';
    final cont = _africa.contains(iso) ? 'af' : _americas.contains(iso) ? 'am' : _asia.contains(iso) ? 'as' : 'eu';
    final title = {'af': 'Afrique', 'am': 'Amériques', 'as': 'Asie et Moyen-Orient', 'eu': 'Europe'}[cont]!;
    final region = keep(_byContinent[cont]!);
    if (region.isNotEmpty) out.add(('🌍  $title', region));
    out.add(('⭐  Grands championnats', keep(_big)));
    return out.where((g) => g.$2.isNotEmpty).toList();
  }

  // ---------- autorisation des notifications ----------

  static const _msgs = [
    ('Ne rate plus aucun but ⚽', "Active les notifications : buts en direct de tes équipes, coupons gagnés et Coups sûrs du jour. Pas de spam, promis."),
    ('Reste informé sur KOUNADIA 🔔', "Coups d'envoi, mi-temps et résultats de tes championnats favoris : l'essentiel, au bon moment."),
    ('Tes coupons te préviennent 🎟️', "Sache tout de suite quand un coupon est validé, sans avoir à ouvrir l'application."),
    ('Les Coups sûrs arrivent chaque matin ☀️', "Reçois une petite alerte dès qu'ils sont prêts, pour jouer avant les autres."),
  ];
  // Délai avant la question suivante après « Plus tard » : 6 h, 1 jour, 3 jours, puis 7 jours.
  static const _waits = [6, 24, 72, 168];

  static Future<bool> _askNotif(BuildContext context, SharedPreferences p, int now) async {
    if (kIsWeb || !Notif.ready || !Notif.enabled.value) return false;
    NotificationSettings s;
    try {
      s = await FirebaseMessaging.instance.getNotificationSettings();
    } catch (_) {
      return false;
    }
    if (s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional) return false;
    final n = p.getInt('eng_nt_n') ?? 0;
    final first = p.getInt('eng_first') ?? now;
    final last = p.getInt('eng_nt_at') ?? 0;
    if (n >= 8) return false;
    // Première fois : quelques heures après la découverte de l'app ; ensuite selon « Plus tard ».
    final wait = n == 0 ? 3 : _waits[(n - 1).clamp(0, _waits.length - 1)];
    if (now - (n == 0 ? first : last) < wait * 3600000) return false;
    await p.setInt('eng_nt_n', n + 1);
    await p.setInt('eng_nt_at', now);
    if (!context.mounted) return false;
    final (title, text) = _msgs[n % _msgs.length];
    Analytics.log('ask_notif', {'n': n + 1});
    final yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: K.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: K.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 18),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: K.indigo.withAlpha(36), shape: BoxShape.circle),
                child: Icon(Icons.notifications_active_rounded, color: K.indigo, size: 34),
              ),
            ),
            const SizedBox(height: 14),
            T(title, textAlign: TextAlign.center, style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            T(text, textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 14, height: 1.35)),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: K.indigo, minimumSize: const Size.fromHeight(50)),
              onPressed: () => Navigator.pop(ctx, true),
              child: T('Autoriser', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: T('Plus tard', style: TextStyle(color: K.muted, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
    if (yes != true) {
      Analytics.log('notif_later', {'n': n + 1});
      return true;
    }
    Analytics.log('notif_yes', {'n': n + 1});
    try {
      final r = await FirebaseMessaging.instance.requestPermission();
      if (r.authorizationStatus != AuthorizationStatus.authorized) {
        // Android ne montre plus sa fenêtre après deux refus : on ouvre directement les réglages de l'app.
        await const MethodChannel('kounadia/update').invokeMethod('notifSettings');
      }
    } catch (_) {}
    unawaited(Notif.sync());
    return true;
  }
}

class _LeaguesSheet extends StatefulWidget {
  final List<(String, List<String>)> groups;
  final Set<String> preset;
  const _LeaguesSheet({required this.groups, required this.preset});
  @override
  State<_LeaguesSheet> createState() => _LeaguesSheetState();
}

class _LeaguesSheetState extends State<_LeaguesSheet> {
  late final Set<String> _on = {
    for (final g in widget.groups)
      for (final k in g.$2)
        if (widget.preset.contains(k)) k
  };

  String _label(String k) {
    final l = frLeague(k);
    return l.replaceFirst(' - ', ' · ');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: K.border, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 16),
              T('Quels championnats aimes-tu le plus ?', style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              T('Leurs matchs passent en premier, avec les buts en direct. Tu pourras changer quand tu veux dans Mes championnats.',
                  style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.3)),
            ]),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), children: [
              for (final g in widget.groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: T(g.$1, style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final k in g.$2)
                    FilterChip(
                      label: Text(_label(k)),
                      selected: _on.contains(k),
                      showCheckmark: true,
                      checkmarkColor: Colors.white,
                      selectedColor: K.indigo,
                      backgroundColor: K.bg,
                      side: BorderSide(color: _on.contains(k) ? K.indigo : K.border),
                      labelStyle: TextStyle(
                          color: _on.contains(k) ? Colors.white : K.text, fontWeight: FontWeight.w700, fontSize: 13),
                      onSelected: (v) => setState(() => v ? _on.add(k) : _on.remove(k)),
                    ),
                ]),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Row(children: [
              TextButton(
                onPressed: () => Navigator.pop(context, <String>{}),
                child: T('Plus tard', style: TextStyle(color: K.muted, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: K.indigo, minimumSize: const Size.fromHeight(48)),
                  onPressed: _on.isEmpty ? null : () => Navigator.pop(context, Set<String>.from(_on)),
                  child: Text(_on.isEmpty ? tr('Choisis au moins un') : '${tr('Valider')} (${_on.length})',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
