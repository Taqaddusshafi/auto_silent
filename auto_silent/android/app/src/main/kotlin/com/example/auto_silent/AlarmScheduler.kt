package com.example.auto_silent

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

object AlarmScheduler {
    private const val TAG = "AlarmScheduler"

    // Stable IDs
    private const val FAJR_ALARM_ID = 1001
    private const val DHUHR_ALARM_ID = 1002
    private const val ASR_ALARM_ID = 1003
    private const val MAGHRIB_ALARM_ID = 1004
    private const val ISHA_ALARM_ID = 1005
    private const val FAJR_END_ALARM_ID = 1101
    private const val DHUHR_END_ALARM_ID = 1102
    private const val ASR_END_ALARM_ID = 1103
    private const val MAGHRIB_END_ALARM_ID = 1104
    private const val ISHA_END_ALARM_ID = 1105

    // Toggle this true for maximum reliability on restrictive OEMs (shows alarm icon)
    private const val ROBUST_MODE = true

    fun schedulePrayerAlarm(
        context: Context,
        prayerName: String,
        startTimeMillis: Long,
        durationMinutes: Int
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.e(TAG, "Exact alarms not granted by user on Android 12+")
                return
            }
        }

        // ENABLE
        val enableIntent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("action", "ENABLE_DND")
            putExtra("prayer_name", prayerName)
            putExtra("duration_minutes", durationMinutes)
        }
        val enablePI = PendingIntent.getBroadcast(
            context,
            getAlarmIdForPrayer(prayerName),
            enableIntent,
            if (Build.VERSION.SDK_INT >= 23)
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            else
                PendingIntent.FLAG_UPDATE_CURRENT
        )

        // DISABLE
        val endTimeMillis = startTimeMillis + durationMinutes * 60 * 1000L
        val disableIntent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("action", "DISABLE_DND")
            putExtra("prayer_name", prayerName)
        }
        val disablePI = PendingIntent.getBroadcast(
            context,
            getEndAlarmIdForPrayer(prayerName),
            disableIntent,
            if (Build.VERSION.SDK_INT >= 23)
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            else
                PendingIntent.FLAG_UPDATE_CURRENT
        )

        if (ROBUST_MODE && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            // Show intent for the alarm clock icon (taps open app)
            val showIntent = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
            )
            // Enable
            val enableInfo = AlarmManager.AlarmClockInfo(startTimeMillis, showIntent)
            alarmManager.setAlarmClock(enableInfo, enablePI)
            // Disable
            val disableInfo = AlarmManager.AlarmClockInfo(endTimeMillis, showIntent)
            alarmManager.setAlarmClock(disableInfo, disablePI)
        } else {
            // Fallback to exact + allow while idle
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, startTimeMillis, enablePI)
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endTimeMillis, disablePI)
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, startTimeMillis, enablePI)
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, endTimeMillis, disablePI)
                }
                else -> {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, startTimeMillis, enablePI)
                    alarmManager.set(AlarmManager.RTC_WAKEUP, endTimeMillis, disablePI)
                }
            }
        }

        Log.i(TAG, "Scheduled $prayerName: enable ${java.util.Date(startTimeMillis)}, disable ${java.util.Date(endTimeMillis)}")
    }

    fun cancelPrayerAlarm(context: Context, prayerName: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val enablePI = PendingIntent.getBroadcast(
            context,
            getAlarmIdForPrayer(prayerName),
            Intent(context, AlarmReceiver::class.java).apply { putExtra("action", "ENABLE_DND"); putExtra("prayer_name", prayerName) },
            if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE else PendingIntent.FLAG_NO_CREATE
        )
        val disablePI = PendingIntent.getBroadcast(
            context,
            getEndAlarmIdForPrayer(prayerName),
            Intent(context, AlarmReceiver::class.java).apply { putExtra("action", "DISABLE_DND"); putExtra("prayer_name", prayerName) },
            if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE else PendingIntent.FLAG_NO_CREATE
        )

        enablePI?.let { alarmManager.cancel(it) }
        disablePI?.let { alarmManager.cancel(it) }
        Log.i(TAG, "Cancelled alarms for $prayerName")
    }

    private fun getAlarmIdForPrayer(prayerName: String): Int = when (prayerName.lowercase()) {
        "fajr" -> FAJR_ALARM_ID
        "dhuhr" -> DHUHR_ALARM_ID
        "asr" -> ASR_ALARM_ID
        "maghrib" -> MAGHRIB_ALARM_ID
        "isha" -> ISHA_ALARM_ID
        else -> prayerName.hashCode()
    }

    private fun getEndAlarmIdForPrayer(prayerName: String): Int = when (prayerName.lowercase()) {
        "fajr" -> FAJR_END_ALARM_ID
        "dhuhr" -> DHUHR_END_ALARM_ID
        "asr" -> ASR_END_ALARM_ID
        "maghrib" -> MAGHRIB_END_ALARM_ID
        "isha" -> ISHA_END_ALARM_ID
        else -> prayerName.hashCode() + 100
    }

    // Simple defaults; replace with real times if available from Flutter/SharedPreferences.
    fun getTodaysPrayerTimes(): List<Pair<String, Long>> {
        val c = Calendar.getInstance().apply { set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
        return listOf(
            "Fajr" to c.cloneAs(5, 30),
            "Dhuhr" to c.cloneAs(12, 30),
            "Asr" to c.cloneAs(15, 30),
            "Maghrib" to c.cloneAs(18, 30),
            "Isha" to c.cloneAs(20, 30),
        )
    }

    private fun Calendar.cloneAs(h: Int, m: Int): Long {
        val t = this.clone() as Calendar
        t.set(Calendar.HOUR_OF_DAY, h); t.set(Calendar.MINUTE, m)
        return t.timeInMillis
    }
}
