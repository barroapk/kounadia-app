import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Color _hex(String s, Color fallback) {
  var h = s.replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final v = int.tryParse(h.length >= 6 ? h.substring(0, 6) : '', radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

class BannerSlide {
  final String title;
  final String text;
  final String cta;
  final String link;
  final String image;
  final List<Color> colors;

  BannerSlide.fromJson(Map<String, dynamic> j)
      : title = j['title']?.toString() ?? '',
        text = j['text']?.toString() ?? '',
        cta = j['cta']?.toString() ?? '',
        link = j['link']?.toString() ?? '',
        image = j['image']?.toString() ?? '',
        colors = ((j['colors'] as List?) ?? const [])
            .map((c) => _hex(c.toString(), const Color(0xFF4F46E5)))
            .toList();
}

class BannerConfig {
  final bool active;
  final int every;
  final List<BannerSlide> slides;

  BannerConfig.fromJson(Map<String, dynamic> j)
      : active = j['active'] == true,
        every = ((j['every'] as num?)?.toInt() ?? 4).clamp(2, 50),
        slides = ((j['slides'] as List?) ?? const [])
            .map((e) => BannerSlide.fromJson(e as Map<String, dynamic>))
            .where((s) => s.title.isNotEmpty)
            .toList();
}

class BannerService {
  static const _url =
      'https://raw.githubusercontent.com/barroapk/kounadia-data/main/data/banniere.json';
  static BannerConfig? _mem;
  static Future<BannerConfig?>? _pending;

  static Future<BannerConfig?> load() {
    final m = _mem;
    if (m != null) return Future.value(m);
    return _pending ??= _fetch();
  }

  static Future<BannerConfig?> _fetch() async {
    final prefs = await SharedPreferences.getInstance();
    String? body;
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 600000;
      final r = await http
          .get(Uri.parse('$_url?v=$bust'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        body = utf8.decode(r.bodyBytes);
        await prefs.setString('kbanner', body);
      }
    } catch (_) {}
    body ??= prefs.getString('kbanner');
    _pending = null;
    if (body == null) return null;
    try {
      final c = BannerConfig.fromJson(jsonDecode(body) as Map<String, dynamic>);
      _mem = c;
      return c;
    } catch (_) {
      return null;
    }
  }
}

/// [afterCards] : 0 = en haut de liste ; sinon nombre de cartes déjà affichées.
/// [total] : nombre total de cartes (pour ne pas afficher en toute fin de liste).
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

  @override
  void initState() {
    super.initState();
    _index = widget.start % widget.slides.length;
    _pc = PageController(initialPage: _index);
    if (widget.slides.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_pc.hasClients) return;
        final next = (_index + 1) % widget.slides.length;
        _pc.animateToPage(next,
            duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
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
    try {
      await launchUrl(Uri.parse(s.link), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _index = i),
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
        ],
      ),
    );
  }

  Widget _slide(BannerSlide s) {
    final c1 = s.colors.isNotEmpty ? s.colors[0] : const Color(0xFF4F46E5);
    final c2 = s.colors.length > 1 ? s.colors[1] : Color.lerp(c1, Colors.black, 0.3)!;
    return GestureDetector(
      onTap: () => _open(s),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c1, c2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: c1.withAlpha(90), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0x1FFFFFFF)),
              ),
            ),
            Positioned(
              right: 60,
              bottom: -50,
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0x14FFFFFF)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('SPONSORISÉ',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 2),
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(s.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xE6FFFFFF), fontSize: 12.5, height: 1.25)),
                      ],
                    ),
                  ),
                  if (s.image.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: s.image,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  if (s.cta.isNotEmpty && s.link.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.cta,
                              style: TextStyle(
                                  color: c1, fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, color: c1, size: 14),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
