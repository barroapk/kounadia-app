import 'package:flutter/material.dart';
import 'forecast_card.dart' show K;
import 'k_ui.dart';
import '../l10n/tr.dart';

/// Une rubrique de document : titre, icône et lignes (« • » = puce).
class DocSection {
  final String title;
  final IconData icon;
  final List<String> lines;
  const DocSection(this.title, this.icon, this.lines);
}

/// Page de lecture (guide, conditions, confidentialité…) : rubriques dépliables.
class DocView extends StatefulWidget {
  final String title;
  final String? intro;
  final List<DocSection> sections;
  final String? footer;
  final bool openAll;
  DocView({super.key, required this.title, this.intro, required this.sections, this.footer, this.openAll = false});

  @override
  State<DocView> createState() => _DocViewState();
}

class _DocViewState extends State<DocView> {
  late final Set<int> _open = widget.openAll ? {for (var i = 0; i < widget.sections.length; i++) i} : {0};

  Widget _line(String l) {
    if (l.startsWith('• ')) {
      return Padding(
        padding: EdgeInsets.only(left: 4, bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.only(top: 7),
            child: Container(width: 5, height: 5, decoration: BoxDecoration(color: K.indigoText, shape: BoxShape.circle)),
          ),
          SizedBox(width: 10),
          Expanded(child: T(l.substring(2), style: TextStyle(color: K.text, fontSize: 13.5, height: 1.45))),
        ]),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 9),
      child: T(l, style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.5)),
    );
  }

  Widget _section(int i, DocSection s) {
    final open = _open.contains(i);
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: kBox(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => open ? _open.remove(i) : _open.add(i)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 13, 10, 13),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: K.indigoSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(s.icon, color: K.indigoText, size: 19),
              ),
              SizedBox(width: 12),
              Expanded(child: T(s.title, style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w800))),
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: K.muted),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: s.lines.map(_line).toList()),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: kAppBar(widget.title),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (widget.intro != null)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 14),
              child: T(widget.intro!, style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.45)),
            ),
          for (var i = 0; i < widget.sections.length; i++) _section(i, widget.sections[i]),
          if (widget.footer != null)
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: T(widget.footer!, textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12, height: 1.4)),
            ),
        ],
      ),
    );
  }
}
