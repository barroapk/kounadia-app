// Décompression gzip : dart:io sur téléphone, package archive dans le navigateur.
export 'gz_io.dart' if (dart.library.js_interop) 'gz_web.dart';
