import "dart:io";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

/// Capture un widget (via GlobalKey attache a un RepaintBoundary) en image
/// PNG, l'ecrit temporairement, puis ouvre le partage natif (WhatsApp,
/// galerie, etc.). Ne garde pas de copie permanente : fichier temporaire.
class ReceiptShareService {
  Future<void> shareFromKey(GlobalKey key, {String fileName = "recu_kounadia.png"}) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/$fileName");
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: "Mon reçu de dépôt KOUNADIA",
    );
  }
}
