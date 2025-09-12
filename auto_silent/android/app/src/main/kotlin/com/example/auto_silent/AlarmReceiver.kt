package com.example.auto_silent

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("AlarmReceiver", "Prayer alarm triggered at ${System.currentTimeMillis()}")
        
        if (context == null) {
            Log.e("AlarmReceiver", "Context is null")
            return
        }

        val action = intent?.getStringExtra("action") ?: return
        val prayerName = intent.getStringExtra("prayer_name") ?: "Prayer"
        
        when (action) {
            "ENABLE_DND" -> enableDND(context, prayerName)
            "DISABLE_DND" -> disableDND(context)
            else -> Log.w("AlarmReceiver", "Unknown action: $action")
        }
    }

    private fun enableDND(context: Context, prayerName: String) {
        try {
            // Check if DND permission is granted
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!notificationManager.isNotificationPolicyAccessGranted) {
                    Log.w("AlarmReceiver", "DND permission not granted")
                    return
                }
            }

            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val sharedPrefs = context.getSharedPreferences("prayer_prefs", Context.MODE_PRIVATE)
            
            // Save current state
            sharedPrefs.edit()
                .putInt("previous_ringer_mode", audioManager.ringerMode)
                .putInt("previous_interruption_filter", 
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                        notificationManager.currentInterruptionFilter 
                    else NotificationManager.INTERRUPTION_FILTER_ALL)
                .putBoolean("is_in_dnd_mode", true)
                .putString("current_prayer", prayerName)
                .putLong("dnd_start_time", System.currentTimeMillis())
                .apply()

            // Enable DND
            var success = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                    success = true
                    Log.d("AlarmReceiver", "DND Priority mode enabled for $prayerName")
                } catch (e: Exception) {
                    try {
                        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                        success = true
                        Log.d("AlarmReceiver", "DND None mode enabled for $prayerName")
                    } catch (e2: Exception) {
                        Log.e("AlarmReceiver", "Failed to set DND", e2)
                    }
                }
            }

            // Fallback to ringer mode if DND fails
            if (!success) {
                try {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                    success = true
                    Log.d("AlarmReceiver", "Vibrate mode enabled for $prayerName")
                } catch (e: Exception) {
                    try {
                        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                        success = true
                        Log.d("AlarmReceiver", "Silent mode enabled for $prayerName")
                    } catch (e2: Exception) {
                        Log.e("AlarmReceiver", "Failed to set silent mode", e2)
                    }
                }
            }

            if (success) {
                Log.i("AlarmReceiver", "✅ Silent mode activated for $prayerName prayer")
                
                // Show notification
                PrayerNotificationHelper.showSilentModeNotification(context, prayerName)
            }

        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error enabling DND", e)
        }
    }

    private fun disableDND(context: Context) {
        try {
            val sharedPrefs = context.getSharedPreferences("prayer_prefs", Context.MODE_PRIVATE)
            
            if (!sharedPrefs.getBoolean("is_in_dnd_mode", false)) {
                Log.d("AlarmReceiver", "Not in DND mode, nothing to disable")
                return
            }

            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            val previousRingerMode = sharedPrefs.getInt("previous_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
            val previousInterruptionFilter = sharedPrefs.getInt("previous_interruption_filter", NotificationManager.INTERRUPTION_FILTER_ALL)
            val currentPrayer = sharedPrefs.getString("current_prayer", "Prayer")

            // Restore DND state
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    notificationManager.setInterruptionFilter(previousInterruptionFilter)
                    Log.d("AlarmReceiver", "DND state restored")
                } catch (e: Exception) {
                    Log.e("AlarmReceiver", "Failed to restore DND state", e)
                }
            }

            // Restore ringer mode
            try {
                audioManager.ringerMode = previousRingerMode
                Log.d("AlarmReceiver", "Ringer mode restored")
            } catch (e: Exception) {
                try {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                    Log.d("AlarmReceiver", "Forced ringer mode to normal")
                } catch (e2: Exception) {
                    Log.e("AlarmReceiver", "Failed to restore ringer mode", e2)
                }
            }

            // Clear state
            sharedPrefs.edit()
                .putBoolean("is_in_dnd_mode", false)
                .remove("current_prayer")
                .remove("dnd_start_time")
                .apply()

            Log.i("AlarmReceiver", "✅ Silent mode disabled after $currentPrayer prayer")
            
            // Cancel notification
            PrayerNotificationHelper.cancelSilentModeNotification(context)

        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error disabling DND", e)
        }
    }
}
