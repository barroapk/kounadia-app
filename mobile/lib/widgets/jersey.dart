import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _fallback = [
  Color(0xFF16A34A), Color(0xFF2563EB), Color(0xFFDC2626), Color(0xFF9333EA),
  Color(0xFFEA580C), Color(0xFF0891B2), Color(0xFFCA8A04), Color(0xFFDB2777),
  Color(0xFF4F46E5), Color(0xFF0D9488),
];

List<Color> colorsFor(String name, List<Color> given) {
  if (given.isNotEmpty) return given;
  var h = 0;
  for (final c in name.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return [_fallback[h % _fallback.length]];
}

class Jersey extends StatelessWidget {
  final List<Color> colors;
  final double size;
  const Jersey({super.key, required this.colors, this.size = 28});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _JerseyPainter(colors));
}

class _JerseyPainter extends CustomPainter {
  final List<Color> colors;
  _JerseyPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(20.38 * s, 3.46 * s)
      ..lineTo(16 * s, 2 * s)
      ..quadraticBezierTo(12 * s, 6 * s, 8 * s, 2 * s)
      ..lineTo(3.62 * s, 3.46 * s)
      ..quadraticBezierTo(2.0 * s, 4.2 * s, 2.28 * s, 5.69 * s)
      ..lineTo(2.86 * s, 9.16 * s)
      ..quadraticBezierTo(3.0 * s, 10 * s, 3.85 * s, 10 * s)
      ..lineTo(6 * s, 10 * s)
      ..lineTo(6 * s, 20 * s)
      ..quadraticBezierTo(6 * s, 22 * s, 8 * s, 22 * s)
      ..lineTo(16 * s, 22 * s)
      ..quadraticBezierTo(18 * s, 22 * s, 18 * s, 20 * s)
      ..lineTo(18 * s, 10 * s)
      ..lineTo(20.15 * s, 10 * s)
      ..quadraticBezierTo(21 * s, 10 * s, 21.14 * s, 9.16 * s)
      ..lineTo(21.72 * s, 5.69 * s)
      ..quadraticBezierTo(22 * s, 4.2 * s, 20.38 * s, 3.46 * s)
      ..close();
    final c1 = colors.isEmpty ? const Color(0xFF6B7280) : colors.first;
    final c2 = colors.length > 1 ? colors[1] : Color.lerp(c1, Colors.black, 0.35)!;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c1, c2],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 * s
        ..color = const Color(0x47FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _JerseyPainter old) => old.colors != colors;
}

class TeamCrest extends StatelessWidget {
  final String name;
  final String? logo;
  final List<Color> colors;
  final double size;

  const TeamCrest({
    super.key,
    required this.name,
    this.logo,
    this.colors = const [],
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final jersey = Jersey(colors: colorsFor(name, colors), size: size);
    final url = logo;
    if (url == null || url.isEmpty) return jersey;
    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: url,
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) KOUNADIA',
          'Referer': 'https://nerdytips.com/',
        },
        fit: BoxFit.contain,
        placeholder: (_, __) => jersey,
        errorWidget: (_, __, ___) => jersey,
      ),
    );
  }
}
