package com.kounadia.kounadia

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Canal « Matchs en direct » : notifications prioritaires (bannière + son).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel("live", "Matchs en direct", NotificationManager.IMPORTANCE_HIGH)
            ch.description = "Buts, coups d'envoi, mi-temps et fins de match"
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(ch)
        }
    }
}
