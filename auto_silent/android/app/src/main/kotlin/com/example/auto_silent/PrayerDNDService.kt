package com.example.auto_silent

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class PrayerDNDService : Service() {

    companion object {
        private const val TAG = "PrayerDNDService"
        private const val CHANNEL_ID = "native_prayer_dnd_channel"
        private const val NOTIF_ID = 998
    }

    override fun onCreate() {
        super.onCreate()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Native Prayer DND",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Keeps prayer DND active reliably"
                    setSound(null, null); enableLights(false); enableVibration(false)
                }
            )
        }
        startForeground(NOTIF_ID, buildNotification("🕌 Native DND Monitor", "Maintaining silent mode during prayer"))
        Log.d(TAG, "Foreground service started")
    }

    private fun buildNotification(title: String, text: String): Notification {
        val pi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            else PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pi)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Nothing long-running here; receiver already applied DND.
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "Foreground service destroyed")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
