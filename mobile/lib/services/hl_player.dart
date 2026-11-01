import 'package:flutter/foundation.dart';
import 'highlights.dart';

/// Lecteur des temps forts commun à toute l'app :
/// - « dock » : la vidéo reste en haut de l'écran, on continue d'utiliser KOUNADIA en dessous ;
/// - « mini » : petite fenêtre dans un coin ;
/// - « full » : plein écran (téléphone à l'horizontale).
/// En quittant l'app, la vidéo continue dans une fenêtre flottante (image dans l'image d'Android).
class HlPlayer {
  static final current = ValueNotifier<HlVideo?>(null);
  static final mode = ValueNotifier<String>('dock');
  static final pip = ValueNotifier<bool>(false);
  static String title = '';

  static void play(HlVideo v, {String? title}) {
    HlPlayer.title = title ?? (v.home.isNotEmpty ? '${v.home} - ${v.away}' : v.title);
    mode.value = 'dock';
    current.value = v;
  }

  static void close() {
    current.value = null;
    mode.value = 'dock';
  }
}
