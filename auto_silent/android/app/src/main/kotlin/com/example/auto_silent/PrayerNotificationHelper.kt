package com.example.auto_silent

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class PrayerNotificationHelper {
    
    companion object {
        private const val TAG = "PrayerNotificationHelper"
        
        // Separate channels for different purposes
        private const val SILENT_MODE_CHANNEL_ID = "prayer_silent_mode"
        private const val PRAYER_REMINDER_CHANNEL_ID = "prayer_reminder"
        private const val SERVICE_STATUS_CHANNEL_ID = "service_status"
        
        // Notification IDs
        private const val SILENT_MODE_NOTIFICATION_ID = 1001
        private const val PRAYER_REMINDER_NOTIFICATION_ID = 1002
        private const val SERVICE_STATUS_NOTIFICATION_ID = 1003
        
        // ===== SILENT MODE NOTIFICATIONS =====
        
        fun showSilentModeNotification(context: Context, prayerName: String) {
            try {
                createAllNotificationChannels(context)
                
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("open_screen", "prayer_status")
                }
                
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                
                // Action to manually disable silent mode
                val disableIntent = Intent(context, MainActivity::class.java).apply {
                    action = "DISABLE_SILENT_MODE"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val disablePendingIntent = PendingIntent.getActivity(
                    context, 1, disableIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                
                val notificationBuilder = NotificationCompat.Builder(context, SILENT_MODE_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
                    .setContentTitle("🔇 $prayerName Prayer - Silent Mode Active")
                    .setContentText("Device silenced for $prayerName prayer time")
                    .setStyle(NotificationCompat.BigTextStyle()
                        .bigText("Your device is in silent mode for $prayerName prayer. Tap to open app or use the button below to disable silent mode."))
                    .setPriority(NotificationCompat.PRIORITY_LOW) // LOW priority to avoid interruption during DND
                    .setCategory(NotificationCompat.CATEGORY_STATUS)
                    .setOngoing(true) // Can't be dismissed by user swipe
                    .setAutoCancel(false)
                    .setContentIntent(pendingIntent)
                    .setLocalOnly(true) // Don't sync to other devices
                    .setShowWhen(true)
                    .setWhen(System.currentTimeMillis())
                    .addAction(
                        android.R.drawable.ic_media_play, 
                        "Disable Silent", 
                        disablePendingIntent
                    )
                    .setColor(0xFF8B5A2B.toInt()) // Brown color for prayer theme
                
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.notify(SILENT_MODE_NOTIFICATION_ID, notificationBuilder.build())
                
                android.util.Log.d(TAG, "✅ Silent mode notification shown for $prayerName")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ Failed to show silent mode notification", e)
            }
        }
        
        fun updateSilentModeNotification(
            context: Context, 
            prayerName: String, 
            timeRemaining: String
        ) {
            try {
                createAllNotificationChannels(context)
                
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                
                val notificationBuilder = NotificationCompat.Builder(context, SILENT_MODE_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
                    .setContentTitle("🔇 $prayerName Prayer - $timeRemaining left")
                    .setContentText("Device silenced for $prayerName prayer time")
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setCategory(NotificationCompat.CATEGORY_STATUS)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setContentIntent(pendingIntent)
                    .setLocalOnly(true)
                    .setOnlyAlertOnce(true) // Don't alert again on updates
                    .setColor(0xFF8B5A2B.toInt())
                
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.notify(SILENT_MODE_NOTIFICATION_ID, notificationBuilder.build())
                
            } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ Failed to update silent mode notification", e)
            }
        }
        
        fun cancelSilentModeNotification(context: Context) {
            try {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(SILENT_MODE_NOTIFICATION_ID)
                android.util.Log.d(TAG, "✅ Silent mode notification cancelled")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ Failed to cancel silent mode notification", e)
            }
        }
        
        // ===== PRAYER REMINDER NOTIFICATIONS =====
        
        fun showPrayerReminderNotification(
            context: Context, 
            prayerName: String, 
            prayerTime: String,
            minutesUntil: Int
        ) {
            try {
                createAllNotificationChannels(context)
                
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                
                val notificationBuilder = NotificationCompat.Builder(context, PRAYER_REMINDER_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                    .setContentTitle("🕌 $prayerName Prayer Time")
                    .setContentText("$prayerName prayer is at $prayerTime (in $minutesUntil minutes)")
                    .setStyle(NotificationCompat.BigTextStyle()
                        .bigText("$prayerName prayer time is approaching at $prayerTime. Your device will be silenced automatically."))
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT) // DEFAULT priority for prayer reminders
                    .setCategory(NotificationCompat.CATEGORY_REMINDER)
                    .setAutoCancel(true) // User can dismiss
                    .setContentIntent(pendingIntent)
                    .setLocalOnly(true)
                    .setShowWhen(true)
                    .setColor(0xFF228B22.toInt()) // Green color for prayer theme
                
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.notify(PRAYER_REMINDER_NOTIFICATION_ID, notificationBuilder.build())
                
                android.util.Log.d(TAG, "✅ Prayer reminder notification shown for $prayerName")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ Failed to show prayer reminder notification", e)
            }
        }
        
        // ===== PRAYER TIME END NOTIFICATIONS =====
        
        fun showPrayerEndNotification(context: Context, prayerName: String) {
            try {
                createAllNotificationChannels(context)
                
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                
                val notificationBuilder = NotificationCompat.Builder(context, PRAYER_REMINDER_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
                    .setContentTitle("🔊 $prayerName Prayer Complete")
                    .setContentText("Silent mode disabled. Sound restored.")
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setCategory(NotificationCompat.CATEGORY_STATUS)
                    .setAutoCancel(true)
                    .setContentIntent(pendingIntent)
                    .setLocalOnly(true)
                    .setTimeoutAfter(5000) // Auto-dismiss after 5 seconds
                    .setColor(0xFF228B22.toInt())
                
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.notify(PRAYER_REMINDER_NOTIFICATION_ID, notificationBuilder.build())
                
                android.util.Log.d(TAG, "✅ Prayer end notification shown for $prayerName")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ Failed to show prayer end notification", e)
            }
        }
        
        // ===== SERVICE STATUS NOTIFICATIONS =====
        
        fun showServiceStatusNotification(
            context: Context, 
            title: String, 
            message: String, 
            isError: Boolean = false
        ) {
            try {
                createAllNotificationChannels(context)
                
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                
                val notificationBuilder = NotificationCompat.Builder(context, SERVICE_STATUS_CHANNEL_ID)
                    .setSmallIcon(
                        if (isError) android.R.drawable.ic_dialog_alert 
                        else android.R.drawable.ic_dialog_info
                    )
                    .setContentTitle(title)
                    .setContentText(message)
                    .setPriority(
                        if (isError) NotificationCompat.PRIORITY_HIGH 
                        else NotificationCompat.PRIORITY_LOW
                    )
                    .setCategory(NotificationCompat.CATEGORY_STATUS)
                    .setAutoCancel(true)
                    .setContentIntent(pendingIntent)
                    .setLocalOnly(true)
                    .setColor(
                        if (isError) 0xFFFF0000.toInt() 
                        else 0xFF0066CC.toInt()
                    )
                
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.notify(SERVICE_STATUS_NOTIFICATION_ID, notificationBuilder.build())
                
                android.util.Log.d(TAG, "✅ Service status notification shown: $title")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ Failed to show service status notification", e)
            }
        }
        
        // ===== NOTIFICATION CHANNEL MANAGEMENT =====
        
        private fun createAllNotificationChannels(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                
                // Silent Mode Channel - LOW importance to avoid DND interruption
                val silentModeChannel = NotificationChannel(
                    SILENT_MODE_CHANNEL_ID,
                    "Prayer Silent Mode",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Notifications shown when device is in prayer silent mode"
                    setSound(null, null) // No sound
                    enableLights(false)
                    enableVibration(false)
                    setShowBadge(true)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
                
                // Prayer Reminder Channel - DEFAULT importance for normal reminders
                val prayerReminderChannel = NotificationChannel(
                    PRAYER_REMINDER_CHANNEL_ID,
                    "Prayer Reminders",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "Prayer time reminders and notifications"
                    setSound(null, null) // Respect user's notification sound settings
                    enableLights(true)
                    lightColor = 0xFF228B22.toInt()
                    enableVibration(true)
                    setShowBadge(true)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
                
                // Service Status Channel - HIGH importance for errors, LOW for info
                val serviceStatusChannel = NotificationChannel(
                    SERVICE_STATUS_CHANNEL_ID,
                    "Service Status",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Prayer app service status and error notifications"
                    setSound(null, null)
                    enableLights(false)
                    enableVibration(false)
                    setShowBadge(false)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
                
                // Create all channels
                notificationManager.createNotificationChannels(
                    listOf(silentModeChannel, prayerReminderChannel, serviceStatusChannel)
                )
                
                android.util.Log.d(TAG, "✅ All notification channels created")
            }
        }
        
        // ===== UTILITY METHODS =====
        
        fun cancelAllNotifications(context: Context) {
            try {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(SILENT_MODE_NOTIFICATION_ID)
                notificationManager.cancel(PRAYER_REMINDER_NOTIFICATION_ID)
                notificationManager.cancel(SERVICE_STATUS_NOTIFICATION_ID)
                android.util.Log.d(TAG, "✅ All notifications cancelled")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ Failed to cancel notifications", e)
            }
        }
        
        fun areNotificationsEnabled(context: Context): Boolean {
            return try {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    notificationManager.areNotificationsEnabled()
                } else {
                    true // Assume enabled for older versions
                }
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error checking notification status", e)
                false
            }
        }
        
        fun getChannelImportance(context: Context, channelId: String): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val channel = notificationManager.getNotificationChannel(channelId)
                    channel?.importance ?: NotificationManager.IMPORTANCE_NONE
                } catch (e: Exception) {
                    NotificationManager.IMPORTANCE_NONE
                }
            } else {
                NotificationManager.IMPORTANCE_DEFAULT
            }
        }
    }
}
