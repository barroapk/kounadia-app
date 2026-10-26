import '../config/store.dart';
import '../services/kounadia_data_service.dart' show FriendlyError;

/// Texte d'erreur montré à l'utilisateur : jamais de détail technique dans KOUNADIA V2.
String kErr(Object? e) {
  if (e is FriendlyError) return e.message;
  if (!kV2) return '$e';
  return 'Les données ne sont pas disponibles pour le moment. Tire vers le bas pour réessayer.';
}
