package com.example.auto_silent

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

class PrayerNotificationHelper {
    
    companion object {
        private const val CHANNEL_ID = "prayer_silent_mode"
        private const val NOTIFICATION_ID = 1001
        
        fun showSilentModeNotification(context: Context, prayerName: String) {
            createNotificationChannel(context)
            
            val notificationBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
                .setContentTitle("🔇 $prayerName Prayer - Silent Mode")
                .setContentText("Device silenced for $prayerName prayer time")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setOngoing(true)
                .setAutoCancel(false)
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())
        }
        
        fun cancelSilentModeNotification(context: Context) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(NOTIFICATION_ID)
        }
        
        private fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Prayer Silent Mode",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications for prayer time silent mode"
                    setSound(null, null)
                }
                
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }
        }
    }
}
