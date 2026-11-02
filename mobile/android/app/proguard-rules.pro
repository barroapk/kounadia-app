# Règles R8 de KOUNADIA (Flutter et ses extensions apportent déjà les leurs).
# Classes Play Core citées par Flutter mais absentes de l'app (modules à la demande non utilisés).
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
# Notre activité et ses canaux (mise à jour, vidéo, notifications) : gardés tels quels.
-keep class com.kounadia.kounadia.** { *; }
# Lecteur vidéo (WebView) : passerelle JavaScript.
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }
