/// Version Play Store (compilée avec --dart-define=STORE=play).
/// Paiement en pause, pas de mise à jour hors Play Store, pas de service 1xBet (règles de Google Play).
/// La version du site (APK) n'est pas concernée : elle garde tout.
const kPlay = String.fromEnvironment('STORE') == 'play';
