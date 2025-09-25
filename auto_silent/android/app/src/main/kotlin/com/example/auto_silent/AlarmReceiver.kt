package com.example.auto_silent

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat

class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmReceiver"
        private const val PREFS_NAME = "prayer_prefs"
        private const val KEY_PREV_RINGER = "previous_ringer_mode"
        private const val KEY_PREV_FILTER = "previous_interruption_filter"
        private const val KEY_IN_DND = "is_in_dnd_mode"
        private const val KEY_CUR_PRAYER = "current_prayer"
        private const val KEY_START_TS = "dnd_start_time"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) {
            Log.e(TAG, "Null context/intent")
            return
        }
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "PrayerApp::AlarmWL")
        try {
            wl.acquire(60_000)
            val action = intent.getStringExtra("action") ?: intent.action ?: run {
                Log.e(TAG, "No action")
                return
            }
            val prayerName = intent.getStringExtra("prayer_name") ?: "Prayer"
            val duration = intent.getIntExtra("duration_minutes", 20)
            Log.i(TAG, "Received action=$action for $prayerName (dur=$duration)")

            when (action) {
                "ENABLE_DND" -> {
                    if (enableDND(context, prayerName)) {
                        try {
                            val s = Intent(context, PrayerDNDService::class.java).apply {
                                putExtra("prayer_name", prayerName)
                                putExtra("action", "maintain_dnd")
                                putExtra("duration_minutes", duration)
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                ContextCompat.startForegroundService(context, s)
                            } else {
                                context.startService(s)
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Service start failed", e)
                        }
                    }
                }
                "DISABLE_DND" -> {
                    if (disableDND(context)) {
                        try {
                            context.stopService(Intent(context, PrayerDNDService::class.java))
                        } catch (e: Exception) {
                            Log.w(TAG, "Service stop failed", e)
                        }
                    }
                }
                else -> Log.w(TAG, "Unknown action $action")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Receiver error", e)
        } finally {
            if (wl.isHeld) wl.release()
        }
    }

    private fun enableDND(context: Context, prayerName: String): Boolean {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        if (sp.getBoolean(KEY_IN_DND, false)) {
            Log.d(TAG, "Already in DND")
            return true
        }
        val prevRinger = am.ringerMode
        val prevFilter = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            nm.currentInterruptionFilter
        } else NotificationManager.INTERRUPTION_FILTER_ALL

        sp.edit()
            .putInt(KEY_PREV_RINGER, prevRinger)
            .putInt(KEY_PREV_FILTER, prevFilter)
            .putBoolean(KEY_IN_DND, true)
            .putString(KEY_CUR_PRAYER, prayerName)
            .putLong(KEY_START_TS, System.currentTimeMillis())
            .apply()

        var ok = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && nm.isNotificationPolicyAccessGranted) {
            ok = try {
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                true
            } catch (_: Exception) {
                try {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                    true
                } catch (_: Exception) { false }
            }
        }
        if (!ok) {
            ok = try {
                am.ringerMode = AudioManager.RINGER_MODE_VIBRATE; true
            } catch (_: Exception) {
                try { am.ringerMode = AudioManager.RINGER_MODE_SILENT; true } catch (_: Exception) { false }
            }
        }
        if (ok) {
            PrayerNotificationHelper.showSilentModeNotification(context, prayerName)
            Log.i(TAG, "DND enabled")
        } else {
            sp.edit().putBoolean(KEY_IN_DND, false).apply()
            Log.e(TAG, "DND enable failed")
        }
        return ok
    }

    private fun disableDND(context: Context): Boolean {
        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!sp.getBoolean(KEY_IN_DND, false)) return true

        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val prevRinger = sp.getInt(KEY_PREV_RINGER, AudioManager.RINGER_MODE_NORMAL)
        val prevFilter = sp.getInt(KEY_PREV_FILTER, NotificationManager.INTERRUPTION_FILTER_ALL)
        val prayer = sp.getString(KEY_CUR_PRAYER, "Prayer") ?: "Prayer"

        var ok = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && nm.isNotificationPolicyAccessGranted) {
            try { nm.setInterruptionFilter(prevFilter); ok = true } catch (_: Exception) {}
        }
        try { am.ringerMode = prevRinger; ok = true } catch (_: Exception) {
            try { am.ringerMode = AudioManager.RINGER_MODE_NORMAL; ok = true } catch (_: Exception) {}
        }

        sp.edit().putBoolean(KEY_IN_DND, false).remove(KEY_CUR_PRAYER).remove(KEY_START_TS).apply()
        if (ok) {
            PrayerNotificationHelper.cancelSilentModeNotification(context)
            PrayerNotificationHelper.showPrayerEndNotification(context, prayer)
            Log.i(TAG, "DND disabled")
        } else {
            Log.e(TAG, "DND disable failed")
        }
        return ok
    }
}
