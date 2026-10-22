// Connexion WebSocket au robot : version téléphone (dart:io) ou navigateur (iPhone / web).
export 'sock_io.dart' if (dart.library.js_interop) 'sock_web.dart';
