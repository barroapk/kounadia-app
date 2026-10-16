import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/coupon.dart';
import 'forecast_card.dart' show K, hm, two;

/// Reçu visuel d'un coupon (partagé en image).
class CouponReceipt extends StatelessWidget {
  final Coupon coupon;
  const CouponReceipt({super.key, required this.coupon});

  Widget _leg(Leg l) {
    final d = l.date;
    final when = d == null ? '' : '${two(d.day)}/${two(d.month)} · ${hm(d)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: K.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.emoji_events_rounded, color: K.amber, size: 14),
          const SizedBox(width: 5),
          Expanded(
            child: Text(l.league,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: K.amber, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
          Text(when, style: const TextStyle(color: K.muted, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        Text('${l.home} – ${l.away}',
            style: const TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Row(children: [
          Expanded(
            child: Text(l.label,
                style: const TextStyle(color: K.indigoText, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0x3322C55E), borderRadius: BorderRadius.circular(8)),
            child: Text('@${fx(l.odd)}',
                style: const TextStyle(color: K.green, fontSize: 13, fontWeight: FontWeight.w900)),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = coupon;
    final now = c.created;
    return Container(
      width: 360,
      color: K.bg,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('KOUNADIA',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                Text('Coupon du ${two(now.day)}/${two(now.month)}/${now.year}',
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11.5)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('×${fx(c.total)}',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const Text('cote totale', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(children: c.legs.map(_leg).toList()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(children: [
            Text('${c.legs.length} matchs',
                style: const TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('Probabilité estimée ≈ ${c.pctText()}',
                style: const TextStyle(color: K.muted, fontSize: 12)),
          ]),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF0D9488)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(children: [
            Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text('Code promo 1xBet : 99KND\n+200 % de bonus sur ta 1re recharge',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.35)),
            ),
          ]),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x2225D366),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x8825D366)),
          ),
          child: const Row(children: [
            Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pour tout besoin de dépôt / retrait 1xBet, contactez KOUNADIA SERVICE sur WhatsApp : +226 55 33 77 82',
                style: TextStyle(color: K.text, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('18+ · Jouez de manière responsable · KOUNADIA',
              textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 10.5)),
        ),
      ]),
    );
  }
}

Future<void> _shareImage(GlobalKey key, Coupon c) async {
  try {
    final b = key.currentContext?.findRenderObject();
    if (b is! RenderRepaintBoundary) throw Exception('rendu');
    final img = await b.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw Exception('png');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/coupon_kounadia_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(data.buffer.asUint8List());
    await Share.shareXFiles([XFile(f.path)],
        text: 'Coupon KOUNADIA · cote ×${fx(c.total)} · Code promo 1xBet : 99KND');
  } catch (_) {
    await Share.share(c.shareText());
  }
}

/// Ouvre l'aperçu du reçu, puis partage en image (ou en texte).
Future<void> shareCoupon(BuildContext context, Coupon c) async {
  final key = GlobalKey();
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: K.card,
      insetPadding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RepaintBoundary(key: key, child: CouponReceipt(coupon: c)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Share.share(c.shareText()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: K.text,
                  side: const BorderSide(color: K.border),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.notes_rounded, size: 18),
                label: const Text('Texte'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => _shareImage(key, c),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.image_rounded, size: 18),
                label: const Text("Partager l'image", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}
