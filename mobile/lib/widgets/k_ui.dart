import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'forecast_card.dart' show K;
import '../l10n/tr.dart';

BoxDecoration kBox({double r = 14}) => BoxDecoration(
      color: K.card,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: K.border),
    );

Widget kTitle(String t) => Padding(
      padding: EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: T(tr(t).toUpperCase(),
          style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
    );

Widget kLoader() => Center(child: CircularProgressIndicator(color: K.indigo));

PreferredSizeWidget kAppBar(String title) => AppBar(
      backgroundColor: K.bg,
      foregroundColor: K.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: T(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    );

Widget kPill(String t, bool sel, VoidCallback onTap, {double? height = 38}) => Material(
      color: sel ? K.indigo : K.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? K.indigo : K.border),
          ),
          child: T(t,
              style: TextStyle(
                  color: sel ? Colors.white : K.muted, fontWeight: FontWeight.w700, fontSize: 13.5)),
        ),
      ),
    );

Widget kDividers(List<Widget> items) {
  final out = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    if (i > 0) out.add(Container(height: 1, color: K.border));
    out.add(items[i]);
  }
  return Container(decoration: kBox(), clipBehavior: Clip.antiAlias, child: Column(children: out));
}

class PtImage extends StatelessWidget {
  final String url;
  final double w;
  final double h;
  PtImage(this.url, {super.key, this.w = 22, this.h = 16});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return SizedBox(width: w, height: h);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: CachedNetworkImage(
        imageUrl: url,
        width: w,
        height: h,
        fit: BoxFit.contain,
        httpHeaders: {'Referer': 'https://primatips.com/'},
        placeholder: (_, __) => SizedBox(width: w, height: h),
        errorWidget: (_, __, ___) => SizedBox(width: w, height: h),
      ),
    );
  }
}
