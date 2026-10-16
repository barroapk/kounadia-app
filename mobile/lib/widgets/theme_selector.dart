import 'package:flutter/material.dart';
import '../services/theme_controller.dart';
import 'forecast_card.dart' show K;
import 'k_ui.dart';

class ThemeSelector extends StatelessWidget {
  ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeCtl.mode,
      builder: (_, m, __) => Container(
        decoration: kBox(),
        padding: EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.brightness_6_rounded, color: K.indigoText, size: 21),
            SizedBox(width: 10),
            Text("Thème de l'affichage", style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          SizedBox(height: 4),
          Text('Auto : clair de 6h à 18h, sombre de 18h à 6h',
              style: TextStyle(color: K.muted, fontSize: 12.5)),
          SizedBox(height: 12),
          Row(children: [
            for (final (v, label, icon) in [
              ('light', 'Clair', Icons.light_mode_rounded),
              ('dark', 'Sombre', Icons.dark_mode_rounded),
              ('auto', 'Auto', Icons.brightness_auto_rounded),
            ])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => ThemeCtl.set(v),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 150),
                      height: 44,
                      decoration: BoxDecoration(
                        color: m == v ? K.indigo : K.bg,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: m == v ? K.indigo : K.border),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(icon, size: 18, color: m == v ? Colors.white : K.muted),
                        SizedBox(width: 6),
                        Text(label,
                            style: TextStyle(
                                color: m == v ? Colors.white : K.muted, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
