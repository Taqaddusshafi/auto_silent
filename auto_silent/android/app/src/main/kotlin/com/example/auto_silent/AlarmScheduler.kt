package com.example.auto_silent

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.*

class AlarmScheduler {

    companion object {
        private const val ENABLE_DND_REQUEST_CODE = 1001
        private const val DISABLE_DND_REQUEST_CODE = 1002
        private val PRAYER_NAMES = listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")

        fun schedulePrayerAlarm(
            context: Context,
            prayerName: String,
            startTimeMillis: Long,
            durationMinutes: Int
        ) {
            try {
                // Schedule enable DND alarm
                scheduleAlarm(
                    context = context,
                    requestCode = ENABLE_DND_REQUEST_CODE + prayerName.hashCode(),
                    triggerTimeMillis = startTimeMillis,
                    action = "ENABLE_DND",
                    prayerName = prayerName
                )

                // Schedule disable DND alarm
                val endTimeMillis = startTimeMillis + (durationMinutes * 60 * 1000)
                scheduleAlarm(
                    context = context,
                    requestCode = DISABLE_DND_REQUEST_CODE + prayerName.hashCode(),
                    triggerTimeMillis = endTimeMillis,
                    action = "DISABLE_DND",
                    prayerName = prayerName
                )

                Log.d(
                    "AlarmScheduler",
                    "Scheduled alarms for $prayerName: ${Date(startTimeMillis)} to ${Date(endTimeMillis)}"
                )

                // Save to SharedPreferences (persist)
                val prefs = context.getSharedPreferences("prayer_prefs", Context.MODE_PRIVATE)
                prefs.edit()
                    .putLong("${prayerName}_start", startTimeMillis)
                    .putInt("${prayerName}_duration", durationMinutes)
                    .apply()

            } catch (e: Exception) {
                Log.e("AlarmScheduler", "Failed to schedule prayer alarm", e)
            }
        }

        private fun scheduleAlarm(
            context: Context,
            requestCode: Int,
            triggerTimeMillis: Long,
            action: String,
            prayerName: String
        ) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

                val intent = Intent(context, AlarmReceiver::class.java).apply {
                    putExtra("action", action)
                    putExtra("prayer_name", prayerName)
                    this.action = "com.example.auto_silent.PRAYER_ALARM"
                }

                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    intent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    else PendingIntent.FLAG_UPDATE_CURRENT
                )

                // Primary: AlarmClock (highest reliability for exact time, shows system alarm icon)
                try {
                    val alarmInfo = AlarmManager.AlarmClockInfo(triggerTimeMillis, pendingIntent)
                    alarmManager.setAlarmClock(alarmInfo, pendingIntent)
                    Log.d("AlarmScheduler", "setAlarmClock scheduled for $prayerName at ${Date(triggerTimeMillis)}")
                } catch (e: Exception) {
                    Log.w("AlarmScheduler", "setAlarmClock failed, falling back to setExactAndAllowWhileIdle: ${e.message}")
                }

                // Fallback: exact allow while idle
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
                    } else {
                        alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
                    }
                    Log.d("AlarmScheduler", "setExact scheduled for $prayerName at ${Date(triggerTimeMillis)}")
                } catch (e: Exception) {
                    Log.e("AlarmScheduler", "setExactAndAllowWhileIdle failed: ${e.message}")
                }

            } catch (e: Exception) {
                Log.e("AlarmScheduler", "scheduleAlarm error", e)
            }
        }

        fun cancelPrayerAlarm(context: Context, prayerName: String) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

                val enablePendingIntent = PendingIntent.getBroadcast(
                    context,
                    ENABLE_DND_REQUEST_CODE + prayerName.hashCode(),
                    Intent(context, AlarmReceiver::class.java).apply { this.action = "com.example.auto_silent.PRAYER_ALARM" },
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_NO_CREATE
                )
                enablePendingIntent?.let { alarmManager.cancel(it) }

                val disablePendingIntent = PendingIntent.getBroadcast(
                    context,
                    DISABLE_DND_REQUEST_CODE + prayerName.hashCode(),
                    Intent(context, AlarmReceiver::class.java).apply { this.action = "com.example.auto_silent.PRAYER_ALARM" },
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_NO_CREATE
                )
                disablePendingIntent?.let { alarmManager.cancel(it) }

                Log.d("AlarmScheduler", "Cancelled alarms for $prayerName")
            } catch (e: Exception) {
                Log.e("AlarmScheduler", "Failed to cancel alarm", e)
            }
        }

        fun cancelAllAlarms(context: Context) {
            try {
                PRAYER_NAMES.forEach { cancelPrayerAlarm(context, it) }
                Log.d("AlarmScheduler", "Cancelled all prayer alarms")
            } catch (e: Exception) {
                Log.e("AlarmScheduler", "Failed to cancel all alarms", e)
            }
        }

        fun rescheduleAllAlarms(context: Context) {
            try {
                val prefs = context.getSharedPreferences("prayer_prefs", Context.MODE_PRIVATE)
                val now = System.currentTimeMillis()

                for (prayer in PRAYER_NAMES) {
                    var start = prefs.getLong("${prayer}_start", -1L)
                    val duration = prefs.getInt("${prayer}_duration", -1)

                    if (start <= 0 || duration <= 0) {
                        // nothing saved for this prayer
                        continue
                    }

                    // If saved time is already in the past, advance to next possible occurrence
                    while (start <= now) {
                        start += 24L * 60L * 60L * 1000L // add one day
                    }

                    schedulePrayerAlarm(context, prayer, start, duration)
                    Log.d("AlarmScheduler", "Rescheduled $prayer at ${Date(start)}")
                }
            } catch (e: Exception) {
                Log.e("AlarmScheduler", "Error while rescheduling alarms", e)
            }
        }
    }
}
