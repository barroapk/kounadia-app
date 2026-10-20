import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/supabase_config.dart';
import '../services/analytics.dart';
import '../services/user_prefs.dart';
import '../services/live_socket.dart' show kLiveBase;
import '../l10n/tr.dart';

Color _hex(String s, Color fallback) {
  var h = s.replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final v = int.tryParse(h.length >= 6 ? h.substring(0, 6) : '', radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// Une page de publicité : une photo (url) ou un texte sur le fond de couleur.
class AdPg {
  final String? url;
  final String title, text;
  const AdPg(this.url, this.title, this.text);
  bool get photo => url != null;
}

/// Une publicité : 1 à 5 pages (photo ou texte).
class BannerSlide {
  final String id, title, text, cta, link;
  final List<AdPg> pages;
  final List<Color> colors;
  BannerSlide.fromAd(Map<String, dynamic> raw) : this._(_localized(raw));

  /// Textes dans la langue de l'utilisateur (traduits à la publication), sinon d'origine.
  static Map<String, dynamic> _localized(Map<String, dynamic> j) {
    final all = j['i18n'];
    final t = all is Map ? all[UserPrefs.lang] : null;
    if (t is! Map) return j;
    final out = Map<String, dynamic>.from(j);
    for (final k in ['title', 'text', 'cta']) {
      final v = t[k]?.toString() ?? '';
      if (v.isNotEmpty) out[k] = v;
    }
    final tp = t['pages'];
    final pg = j['pages'];
    if (tp is List && pg is List && tp.length == pg.length) {
      out['pages'] = [
        for (var i = 0; i < pg.length; i++) (pg[i] is Map && tp[i] is Map) ? {...Map<String, dynamic>.from(pg[i] as Map), ...Map<String, dynamic>.from(tp[i] as Map)} : pg[i],
      ];
    }
    return out;
  }

  BannerSlide._(Map<String, dynamic> j)
      : id = j['id']?.toString() ?? '',
        title = j['title']?.toString() ?? '',
        text = j['text']?.toString() ?? '',
        cta = j['cta']?.toString() ?? '',
        link = j['link']?.toString() ?? '',
        pages = _pages(j),
        colors = [
          _hex(j['color1']?.toString() ?? '', const Color(0xFF4F46E5)),
          _hex(j['color2']?.toString() ?? '', const Color(0xFF7C3AED)),
        ];

  static List<AdPg> _pages(Map<String, dynamic> j) {
    final l = <AdPg>[];
    final p = j['pages'];
    if (p is List) {
      for (final e in p) {
        if (l.length >= 5) break;
        if (e is Map) {
          final t = e['title']?.toString() ?? '';
          final x = e['text']?.toString() ?? '';
          if (t.isNotEmpty || x.isNotEmpty) l.add(AdPg(null, t, x));
        } else if (e is String && e.startsWith('http')) {
          l.add(AdPg(e, '', ''));
        }
      }
    }
    if (l.isEmpty) {
      final img = j['image_url']?.toString() ?? '';
      // Le titre est un nom interne (KND Tigui) : jamais affiché seul.
      if (img.startsWith('http')) l.add(AdPg(img, '', ''));
    }
    return l;
  }

  bool get hasButton => cta.isNotEmpty && link.isNotEmpty;
}

class BannerConfig {
  final bool active;
  final int every;
  final List<BannerSlide> slides;
  BannerConfig(this.active, this.every, this.slides);
}

/// Publicités gérées depuis KND Tigui (table kounadia_ads de Supabase).
class BannerService {
  static BannerConfig? _mem;
  static DateTime? _at;
  static Future<BannerConfig?>? _pending;

  /// Change quand de nouvelles publicités arrivent : les bannières se redessinent.
  static final version = ValueNotifier<int>(0);
  static BannerConfig? get cached => _mem;
  static String? _lang;

  /// Textes des publicités traduits par le robot KOUNADIA (gardés sur le téléphone).
  static Future<void> _translate(List<Map<String, dynamic>> ads, SharedPreferences prefs) async {
    final lang = UserPrefs.lang;
    if (lang == 'fr' || kLiveBase.isEmpty) return;
    final key = 'ktr_$lang';
    final known = <String, String>{};
    try {
      final c = prefs.getString(key);
      if (c != null) known.addAll(Map<String, String>.from(jsonDecode(c) as Map));
    } catch (_) {}
    // Textes à traduire : ceux sans traduction fournie par KND Tigui.
    final need = <String>{};
    void want(String? t) {
      if (t != null && t.trim().isNotEmpty && !known.containsKey(t)) need.add(t);
    }
    for (final j in ads) {
      final t = j['i18n'] is Map ? (j['i18n'] as Map)[lang] : null;
      if (t is Map && (t['text']?.toString() ?? '').isNotEmpty) continue;
      want(j['text']?.toString());
      want(j['cta']?.toString());
      final pg = j['pages'];
      if (pg is List) {
        for (final e in pg) {
          if (e is Map) {
            want(e['title']?.toString());
            want(e['text']?.toString());
          }
        }
      }
    }
    if (need.isNotEmpty) {
      try {
        final list = need.take(40).toList();
        final r = await http
            .post(Uri.parse('$kLiveBase/tr'),
                headers: {'content-type': 'application/json'}, body: jsonEncode({'to': lang, 'texts': list}))
            .timeout(const Duration(seconds: 40));
        if (r.statusCode == 200) {
          final out = (jsonDecode(utf8.decode(r.bodyBytes))['out'] as List).map((e) => '$e').toList();
          for (var i = 0; i < list.length && i < out.length; i++) {
            if (out[i] != list[i]) known[list[i]] = out[i];
          }
          await prefs.setString(key, jsonEncode(known));
        }
      } catch (_) {}
    }
    // Injecte les traductions là où KND Tigui n'en a pas fourni.
    for (final j in ads) {
      final i18n = j['i18n'] is Map ? Map<String, dynamic>.from(j['i18n'] as Map) : <String, dynamic>{};
      final cur = i18n[lang] is Map ? Map<String, dynamic>.from(i18n[lang] as Map) : <String, dynamic>{};
      if ((cur['text']?.toString() ?? '').isNotEmpty) continue;
      String? tr(dynamic v) => v == null ? null : known[v.toString()];
      if (tr(j['text']) != null) cur['text'] = tr(j['text']);
      if (tr(j['cta']) != null) cur['cta'] = tr(j['cta']);
      final pg = j['pages'];
      if (pg is List) {
        cur['pages'] = [
          for (final e in pg)
            e is Map ? {if (tr(e['title']) != null) 'title': tr(e['title']), if (tr(e['text']) != null) 'text': tr(e['text'])} : <String, dynamic>{}
        ];
      }
      i18n[lang] = cur;
      j['i18n'] = i18n;
    }
  }

  /// Recharge tout de suite (retour dans l'app, actualisation, toutes les 3 min).
  static Future<void> reload() async {
    _at = null;
    await load();
    version.value++;
  }

  static Future<BannerConfig?> load() {
    final m = _mem;
    if (m != null && _at != null && _lang == UserPrefs.lang && DateTime.now().difference(_at!) < const Duration(minutes: 3)) {
      return Future.value(m);
    }
    return _pending ??= _fetch();
  }

  static Future<BannerConfig?> _fetch() async {
    final prefs = await SharedPreferences.getInstance();
    String? body;
    try {
      final r = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/kounadia_ads'
            '?select=id,title,text,cta,link,image_url,color1,color2,pages,ends_at,countries,i18n&active=eq.true&order=position.asc'),
        headers: {'apikey': kSupabaseAnon, 'Authorization': 'Bearer $kSupabaseAnon'},
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        body = utf8.decode(r.bodyBytes);
        await prefs.setString('kads', body);
      }
    } catch (_) {}
    body ??= prefs.getString('kads');
    _pending = null;
    if (body == null) return _mem;
    try {
      final now = DateTime.now();
      final slides = <BannerSlide>[];
      final ads = [for (final e in jsonDecode(body) as List) Map<String, dynamic>.from(e as Map)];
      await _translate(ads, prefs);
      _lang = UserPrefs.lang;
      for (final j in ads) {
        final end = DateTime.tryParse(j['ends_at']?.toString() ?? '');
        if (end != null && end.isBefore(now)) continue;
        // Pays de diffusion choisis dans KND Tigui (liste vide = tous les pays).
        final cs = j['countries'];
        if (cs is List && cs.isNotEmpty && !cs.map((e) => e.toString()).contains(UserPrefs.iso)) continue;
        final s = BannerSlide.fromAd(j);
        if (s.pages.isNotEmpty) slides.add(s);
      }
      final c = BannerConfig(slides.isNotEmpty, 10, slides);
      _mem = c;
      _at = DateTime.now();
      return c;
    } catch (_) {
      return _mem;
    }
  }
}

class KndBanner extends StatelessWidget {
  final int afterCards;
  final int total;
  const KndBanner({super.key, this.afterCards = 0, this.total = 0});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BannerService.version,
      builder: (_, __, ___) => FutureBuilder<BannerConfig?>(
      future: BannerService.load(),
      initialData: BannerService.cached,
      builder: (context, snap) {
        final c = snap.data;
        if (c == null || !c.active || c.slides.isEmpty) return const SizedBox.shrink();
        if (afterCards > 0 && (afterCards % c.every != 0 || afterCards >= total)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _Carousel(key: ValueKey(c.slides.map((s) => s.id).join(',')), slides: c.slides),
        );
      },
    ));
  }
}

/// Défilement : pages d'une pub du bas vers le haut, puis pub suivante de droite à gauche.
/// Ordre aléatoire à chaque bannière.
class _Carousel extends StatefulWidget {
  final List<BannerSlide> slides;
  const _Carousel({super.key, required this.slides});
  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  static const _pageTime = Duration(seconds: 4);
  static const _singleTime = Duration(seconds: 6);
  static const _anim = Duration(milliseconds: 650);
  late final List<BannerSlide> _order = [...widget.slides]..shuffle(Random());
  late int _ad = _order.length * 1000;
  late final PageController _h = PageController(initialPage: _ad);
  int _page = 0;
  Timer? _t;

  BannerSlide _s(int i) => _order[i % _order.length];

  @override
  void initState() {
    super.initState();
    _seen();
    _schedule();
  }

  @override
  void dispose() {
    _t?.cancel();
    _h.dispose();
    super.dispose();
  }

  void _seen() {
    final s = _s(_ad);
    if (s.id.isNotEmpty) Analytics.once('adv_${s.id}', 'ad_view', {'ad': s.id});
  }

  void _schedule() {
    _t?.cancel();
    _t = Timer(_s(_ad).pages.length > 1 ? _pageTime : _singleTime, _next);
  }

  void _next() {
    if (!mounted) return;
    final n = _s(_ad).pages.length;
    if (_page < n - 1) {
      setState(() => _page++);
      _schedule();
    } else if (_order.length > 1 && _h.hasClients) {
      _h.nextPage(duration: _anim, curve: Curves.easeInOutCubic);
    } else if (n > 1) {
      setState(() => _page = 0);
      _schedule();
    } else {
      _schedule();
    }
  }

  Future<void> _tap(BannerSlide s) async {
    if (_page < s.pages.length - 1) {
      _next();
      return;
    }
    if (s.link.isEmpty) return;
    if (s.id.isNotEmpty) Analytics.log('ad_click', {'ad': s.id});
    try {
      await launchUrl(Uri.parse(s.link), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.75,
      child: PageView.builder(
        controller: _h,
        onPageChanged: (i) {
          setState(() {
            _ad = i;
            _page = 0;
          });
          _seen();
          _schedule();
        },
        itemBuilder: (_, i) {
          final s = _s(i);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _AdView(slide: s, page: i == _ad ? _page : 0, onTap: () => _tap(s)),
          );
        },
      ),
    );
  }
}

class _AdView extends StatefulWidget {
  final BannerSlide slide;
  final int page;
  final VoidCallback onTap;
  const _AdView({required this.slide, required this.page, required this.onTap});
  @override
  State<_AdView> createState() => _AdViewState();
}

class _AdViewState extends State<_AdView> {
  late final PageController _v = PageController(initialPage: widget.page);
  bool _cached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cached) return;
    _cached = true;
    for (final p in widget.slide.pages) {
      final u = p.url;
      if (u != null) precacheImage(CachedNetworkImageProvider(u), context).catchError((_) {});
    }
  }

  @override
  void didUpdateWidget(_AdView old) {
    super.didUpdateWidget(old);
    if (old.page == widget.page || !_v.hasClients) return;
    if (widget.page == 0) {
      _v.jumpToPage(0);
    } else {
      _v.animateToPage(widget.page, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  Widget _textPage(AdPg p) => Stack(children: [
        Positioned(
          right: -40,
          top: -50,
          child: Container(
            width: 170,
            height: 170,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x1FFFFFFF)),
          ),
        ),
        Positioned(
          left: -30,
          bottom: -60,
          child: Container(
            width: 130,
            height: 130,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x14FFFFFF)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 34, 18, 54),
          // Texte entier : la taille se réduit d'elle-même si le texte est long.
          child: LayoutBuilder(
            builder: (_, bc) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                width: bc.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.title.isNotEmpty)
                      Text(p.title,
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.15)),
                    if (p.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(p.text, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13.5, height: 1.3)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ]);

  Widget _chip(String t, {double size = 10}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black.withAlpha(110), borderRadius: BorderRadius.circular(20)),
        child: T(t,
            style: TextStyle(color: Colors.white, fontSize: size, fontWeight: FontWeight.w800, letterSpacing: .6)),
      );

  Widget _button(BannerSlide s, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 170),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: T(s.cta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_rounded, color: c, size: 15),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.slide;
    final c1 = s.colors[0];
    final c2 = s.colors[1];
    final n = s.pages.length;
    final last = n == 0 || widget.page >= n - 1;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: c1.withAlpha(70), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Stack(children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _v,
              scrollDirection: Axis.vertical,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: n,
              itemBuilder: (_, i) {
                final p = s.pages[i];
                final u = p.url;
                if (u != null) {
                  return CachedNetworkImage(
                    imageUrl: u,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  );
                }
                return _textPage(p);
              },
            ),
          ),
          Positioned(top: 10, left: 10, child: _chip('SPONSORISÉ', size: 9)),
          if (n > 1) Positioned(top: 10, right: 10, child: _chip('${widget.page + 1}/$n', size: 11)),
          if (s.hasButton)
            Positioned(
              right: 12,
              bottom: 12,
              child: AnimatedOpacity(
                opacity: last ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(ignoring: !last, child: _button(s, c1)),
              ),
            ),
        ]),
      ),
    );
  }
}
