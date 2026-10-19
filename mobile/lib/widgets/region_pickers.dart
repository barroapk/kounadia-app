import 'package:flutter/material.dart';
import '../config/countries.dart';
import '../services/currency.dart';
import '../services/user_prefs.dart';
import 'forecast_card.dart' show K;
import '../l10n/tr.dart';

String _n(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[àâäá]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îïí]'), 'i')
    .replaceAll(RegExp('[ôöó]'), 'o')
    .replaceAll(RegExp('[ùûüú]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll('’', "'");

Future<R?> _sheet<R>(BuildContext context, String title, Widget Function(String q) list) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    backgroundColor: K.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) {
      var q = '';
      return StatefulBuilder(
        builder: (ctx, set) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.82,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(children: [
              SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: K.border, borderRadius: BorderRadius.circular(4))),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: T(title, style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  style: TextStyle(color: K.text),
                  onChanged: (v) => set(() => q = v),
                  decoration: InputDecoration(
                    hintText: tr('Rechercher…'),
                    hintStyle: TextStyle(color: K.muted),
                    prefixIcon: Icon(Icons.search_rounded, color: K.muted),
                    filled: true,
                    fillColor: K.bg,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              SizedBox(height: 6),
              Expanded(child: list(_n(q.trim()))),
            ]),
          ),
        ),
      );
    },
  );
}

/// Choix du pays avec recherche (nom ou code).
Future<KCountry?> pickCountry(BuildContext context, {String? selected}) {
  return _sheet<KCountry>(context, 'Choisis ton pays', (q) {
    bool hit(KCountry c) =>
        q.isEmpty ||
        _n(c.name).contains(q) ||
        c.aliases.any((a) => _n(a).contains(q)) ||
        c.iso.toLowerCase() == q;
    final list = kCountries.where(hit).toList()..sort((a, b) => _n(a.label).compareTo(_n(b.label)));
    Widget row(KCountry c) => ListTile(
          onTap: () => Navigator.pop(context, c),
          leading: T(c.flag, style: TextStyle(fontSize: 24)),
          title: T(c.label, style: TextStyle(color: K.text, fontWeight: c.iso == selected ? FontWeight.w900 : FontWeight.w600)),
          subtitle: T('${c.currency} · ${Fx.symbol(c.currency)}', style: TextStyle(color: K.muted, fontSize: 12)),
          trailing: c.iso == selected ? Icon(Icons.check_circle_rounded, color: K.indigoText) : null,
        );
    if (list.isEmpty) {
      return Center(child: T('Aucun pays trouvé', style: TextStyle(color: K.muted)));
    }
    return ListView(children: list.map(row).toList());
  });
}

Future<String?> pickLang(BuildContext context, String selected) {
  return _sheet<String>(context, 'Langue', (q) {
    final l = kLangs.where((e) => q.isEmpty || _n(e.$2).contains(q) || e.$1 == q).toList();
    return ListView(children: [
      for (final (code, name) in l)
        ListTile(
          onTap: () => Navigator.pop(context, code),
          title: T(name, style: TextStyle(color: K.text, fontWeight: FontWeight.w700)),
          trailing: code == selected ? Icon(Icons.check_circle_rounded, color: K.indigoText) : null,
        ),
    ]);
  });
}

Future<String?> pickCurrency(BuildContext context, String selected) {
  final cur = <String, List<String>>{};
  for (final c in kCountries) {
    cur.putIfAbsent(c.currency, () => []).add(c.name);
  }
  final codes = cur.keys.toList()..sort();
  for (final top in ['EUR', 'USD', 'XAF', 'XOF']) {
    codes
      ..remove(top)
      ..insert(0, top);
  }
  return _sheet<String>(context, 'Devise', (q) {
    final l = codes.where((c) => q.isEmpty || _n(c).contains(q) || cur[c]!.any((n) => _n(n).contains(q))).toList();
    return ListView(children: [
      for (final c in l)
        ListTile(
          onTap: () => Navigator.pop(context, c),
          title: T('$c · ${Fx.symbol(c)}', style: TextStyle(color: K.text, fontWeight: FontWeight.w700)),
          subtitle: T(cur[c]!.take(3).join(', ') + (cur[c]!.length > 3 ? '…' : ''),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.muted, fontSize: 12)),
          trailing: c == selected ? Icon(Icons.check_circle_rounded, color: K.indigoText) : null,
        ),
    ]);
  });
}
