import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/supabase_config.dart';
import '../services/analytics.dart';

Color _hex(String s, Color fallback) {
  var h = s.replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final v = int.tryParse(h.length >= 6 ? h.substring(0, 6) : '', radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

class BannerSlide {
  final String id, title, text, cta, link, image;
  final List<Color> colors;
  BannerSlide.fromAd(Map<String, dynamic> j)
      : id = j['id']?.toString() ?? '',
        title = j['title']?.toString() ?? '',
        text = j['text']?.toString() ?? '',
        cta = j['cta']?.toString() ?? '',
        link = j['link']?.toString() ?? '',
        image = j['image_url']?.toString() ?? '',
        colors = [
          _hex(j['color1']?.toString() ?? '', const Color(0xFF4F46E5)),
          _hex(j['color2']?.toString() ?? '', const Color(0xFF7C3AED)),
        ];
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

  static Future<BannerConfig?> load() {
    final m = _mem;
    if (m != null && _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 15)) {
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
            '?select=id,title,text,cta,link,image_url,color1,color2&active=eq.true&order=position.asc'),
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
      final slides = (jsonDecode(body) as List)
          .map((e) => BannerSlide.fromAd(Map<String, dynamic>.from(e as Map)))
          .where((s) => s.title.isNotEmpty)
          .toList();
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
    return FutureBuilder<BannerConfig?>(
      future: BannerService.load(),
      builder: (context, snap) {
        final c = snap.data;
        if (c == null || !c.active || c.slides.isEmpty) return const SizedBox.shrink();
        if (afterCards > 0 && (afterCards % c.every != 0 || afterCards >= total)) {
          return const SizedBox.shrink();
        }
        final start = afterCards == 0 ? 0 : afterCards ~/ c.every;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _Carousel(slides: c.slides, start: start),
        );
      },
    );
  }
}

class _Carousel extends StatefulWidget {
  final List<BannerSlide> slides;
  final int start;
  const _Carousel({required this.slides, required this.start});
  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  late final PageController _pc;
  late int _index;
  Timer? _timer;

  void _seen(int i) {
    final s = widget.slides[i];
    if (s.id.isNotEmpty) Analytics.once('adv_${s.id}', 'ad_view', {'ad': s.id});
  }

  @override
  void initState() {
    super.initState();
    _index = widget.start % widget.slides.length;
    _pc = PageController(initialPage: _index);
    _seen(_index);
    if (widget.slides.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_pc.hasClients) return;
        final next = (_index + 1) % widget.slides.length;
        _pc.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  Future<void> _open(BannerSlide s) async {
    if (s.link.isEmpty) return;
    if (s.id.isNotEmpty) Analytics.log('ad_click', {'ad': s.id});
    try {
      await launchUrl(Uri.parse(s.link), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Stack(children: [
        PageView.builder(
          controller: _pc,
          itemCount: widget.slides.length,
          onPageChanged: (i) {
            setState(() => _index = i);
            _seen(i);
          },
          itemBuilder: (_, i) => _slide(widget.slides[i]),
        ),
        if (widget.slides.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.slides.length, (i) {
                final on = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: on ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: on ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ]),
    );
  }

  Widget _slide(BannerSlide s) {
    final c1 = s.colors[0];
    final c2 = s.colors[1];
    final hasImage = s.image.isNotEmpty;
    return GestureDetector(
      onTap: () => _open(s),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: c1.withAlpha(90), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Stack(children: [
          if (hasImage) ...[
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: s.image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withAlpha(200), Colors.black.withAlpha(40)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x1FFFFFFF)),
              ),
            ),
            Positioned(
              right: 60,
              bottom: -50,
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x14FFFFFF)),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 16),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('SPONSORISÉ',
                        style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 2),
                    Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(s.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12, height: 1.2)),
                  ],
                ),
              ),
              if (s.cta.isNotEmpty && s.link.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  constraints: const BoxConstraints(maxWidth: 92),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(s.cta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c1, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: c1, size: 12),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
