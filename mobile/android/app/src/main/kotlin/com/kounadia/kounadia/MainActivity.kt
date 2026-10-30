package com.kounadia.kounadia

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Canal « Matchs en direct » : notifications prioritaires (bannière + son).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel("live", "Matchs en direct", NotificationManager.IMPORTANCE_HIGH)
            ch.enableVibration(true)
            ch.description = "Buts, coups d'envoi, mi-temps et fins de match"
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(ch)
            // Un son KOUNADIA par type de notification (reconnaissable sans regarder l'écran).
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            for ((id, name, desc) in listOf(
                Triple("k_goal", "Buts", "Un but dans un match suivi"),
                Triple("k_fulltime", "Fins de match", "Le coup de sifflet final"),
                Triple("k_sure", "Coups sûrs validés", "Un Coup sûr gagné"),
                Triple("k_coupon", "Coupons validés", "Un coupon gagné"),
                Triple("k_tips", "Coupons et Coups sûrs disponibles", "Les coupons et Coups sûrs du jour sont prêts"),
            )) {
                val snd = if (id == "k_sure") "k_sure_won" else if (id == "k_coupon") "k_coupon_won" else id
                val c = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH)
                c.description = desc
                c.enableVibration(true)
                c.setSound(Uri.parse("android.resource://$packageName/raw/$snd"), attrs)
                nm?.createNotificationChannel(c)
            }
            // Infos personnalisées : discrètes (son léger + petite vibration, pas de bannière insistante).
            val info = NotificationChannel("k_info", "Infos pour toi", NotificationManager.IMPORTANCE_DEFAULT)
            info.description = "Tes équipes du jour et les faits de tes championnats (rarement)"
            info.enableVibration(true)
            info.vibrationPattern = longArrayOf(0, 120)
            info.setSound(Uri.parse("android.resource://$packageName/raw/k_info"), attrs)
            nm?.createNotificationChannel(info)
        }
    }

    // Mise à jour dans l'app : autorisation d'installer + lancement de l'installation.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kounadia/update").setMethodCallHandler { call, result ->
            when (call.method) {
                // Réglages des notifications de l'app (quand Android ne montre plus sa fenêtre d'autorisation).
                "notifSettings" -> {
                    try {
                        val i = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                        }
                        startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
                )
                "allowInstall" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "install" -> {
                    try {
                        val path = call.argument<String>("path") ?: throw IllegalArgumentException("chemin")
                        val uri = FileProvider.getUriForFile(this, "$packageName.update", File(path))
                        val i = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("install", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
