package com.kounadia.kounadia

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Juste après l'installation de la nouvelle version : rouvre KOUNADIA (ou propose de l'ouvrir). */
class UpdatedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP) ?: return
        // Android 9 et moins : l'app se rouvre toute seule.
        if (Build.VERSION.SDK_INT < 29) {
            try {
                context.startActivity(launch)
                return
            } catch (e: Exception) {}
        }
        // Android 10 et plus bloque l'ouverture automatique : notification « touchez pour ouvrir ».
        try {
            val pi = PendingIntent.getActivity(
                context, 7, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(context, "live")
            else Notification.Builder(context)
            val n = b.setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("KOUNADIA est à jour ✅")
                .setContentText("Touchez pour ouvrir la nouvelle version.")
                .setContentIntent(pi)
                .setAutoCancel(true)
                .build()
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(7007, n)
        } catch (e: Exception) {}
    }
}
