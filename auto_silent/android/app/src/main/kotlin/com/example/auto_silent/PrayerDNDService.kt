package com.example.auto_silent

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.*

class PrayerDNDService : Service() {
    companion object {
        private const val TAG = "PrayerDNDService"
        private const val NOTIFICATION_ID = 998
        private const val CHANNEL_ID = "native_prayer_dnd_channel"
    }
    
    private var handler: Handler? = null
    private var prayerChecker: Runnable? = null
    private var notificationManager: NotificationManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var isDNDCurrentlyActive = false
    private var currentPrayerName = ""

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🚀 Native Prayer DND Service created - INDEPENDENT OF FLUTTER")
        
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "PrayerApp::NativeDNDWakeLock")
        wakeLock?.let { if (!it.isHeld) it.acquire(10 * 60 * 1000L) }
        
        startForeground(NOTIFICATION_ID, createNotification("🕌 Native DND Monitor", "Independent prayer time monitoring"))
        startPrayerTimeMonitoring()
        
        Log.d(TAG, "✅ Native Prayer DND Service started - will work even when Flutter app is killed")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Native Prayer DND Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Native service that monitors prayer times independently"
                setSound(null, null)
                setShowBadge(false)
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(title: String, text: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun startPrayerTimeMonitoring() {
        handler = Handler(Looper.getMainLooper())
        prayerChecker = Runnable {
            try {
                performPrayerTimeCheck()
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error in native prayer check: ${e.message}", e)
            }
            handler?.postDelayed(prayerChecker!!, 30000)
        }
        
        handler?.post(prayerChecker!!)
        Log.d(TAG, "✅ Native prayer time monitoring started (30-second intervals)")
    }

    private fun performPrayerTimeCheck() {
        val now = Calendar.getInstance()
        Log.d(TAG, "🔍 [NATIVE] Checking prayer times at: ${now.time}")
        
        val prayerTimes = getTodaysPrayerTimes()
        var shouldBeInDND = false
        var activePrayer = ""
        val dndDuration = getDNDDurationMinutes()

        for (prayer in prayerTimes) {
            val prayerStart = prayer.startTime
            val prayerEnd = prayerStart.clone() as Calendar
            prayerEnd.add(Calendar.MINUTE, dndDuration)
            
            if (now.after(prayerStart) && now.before(prayerEnd)) {
                shouldBeInDND = true
                activePrayer = prayer.name
                Log.d(TAG, "✅ [NATIVE] PRAYER TIME DETECTED: $activePrayer")
                break
            }
        }

        Log.d(TAG, "🎯 [NATIVE] Should be in DND: $shouldBeInDND | Currently in DND: $isDNDCurrentlyActive")

        when {
            shouldBeInDND && !isDNDCurrentlyActive -> {
                if (enableNativeDND(activePrayer)) {
                    isDNDCurrentlyActive = true
                    currentPrayerName = activePrayer
                    updateNotification("🔇 $activePrayer Prayer - SILENT", "Device silenced by native service")
                    Log.d(TAG, "✅ [NATIVE] DND ENABLED for $activePrayer")
                } else {
                    Log.e(TAG, "❌ [NATIVE] FAILED to enable DND for $activePrayer")
                }
            }
            !shouldBeInDND && isDNDCurrentlyActive -> {
                if (disableNativeDND()) {
                    val prevPrayer = currentPrayerName
                    isDNDCurrentlyActive = false
                    currentPrayerName = ""
                    updateNotification("🔊 $prevPrayer Complete", "Sound restored by native service")
                    Log.d(TAG, "✅ [NATIVE] DND DISABLED after $prevPrayer")
                } else {
                    Log.e(TAG, "❌ [NATIVE] FAILED to disable DND")
                }
            }
            else -> {
                val nextPrayer = getNextPrayer(prayerTimes, now)
                val statusText = nextPrayer?.let { 
                    "Next: ${it.name} at ${formatTime(it.startTime)}" 
                } ?: "Native monitoring active..."
                updateNotification("🕌 Native DND Monitor", statusText)
            }
        }
    }

    private fun enableNativeDND(prayerName: String): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                try {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                    Log.d(TAG, "✅ [NATIVE] DND enabled successfully for $prayerName")
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "❌ [NATIVE] Exception enabling DND: ${e.message}")
                    false
                }
            } else {
                Log.e(TAG, "❌ [NATIVE] DND permission not granted - user must enable in settings")
                false
            }
        } else {
            Log.e(TAG, "❌ [NATIVE] DND not supported on this Android version")
            false
        }
    }

    private fun disableNativeDND(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                try {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                    Log.d(TAG, "✅ [NATIVE] DND disabled successfully")
                    true
                } catch (e: Exception) {
                    Log.e(TAG, "❌ [NATIVE] Exception disabling DND: ${e.message}")
                    false
                }
            } else {
                Log.e(TAG, "❌ [NATIVE] DND permission not granted")
                false
            }
        } else false
    }

    private fun updateNotification(title: String, text: String) {
        val notification = createNotification(title, text)
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }

    private fun getTodaysPrayerTimes(): List<PrayerTime> {
        return listOf(
            PrayerTime("Fajr", createTimeToday(5, 30)),
            PrayerTime("Dhuhr", createTimeToday(12, 30)),
            PrayerTime("Asr", createTimeToday(15, 30)),
            PrayerTime("Maghrib", createTimeToday(18, 30)),
            PrayerTime("Isha", createTimeToday(20, 30))
        )
    }

    private fun createTimeToday(hour: Int, minute: Int): Calendar {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }

    private fun getDNDDurationMinutes(): Int {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getInt("flutter.silenceDuration", 20)
    }

    private fun getNextPrayer(prayers: List<PrayerTime>, now: Calendar): PrayerTime? {
        return prayers.firstOrNull { it.startTime.after(now) }
    }

    private fun formatTime(time: Calendar): String {
        return String.format("%02d:%02d", time.get(Calendar.HOUR_OF_DAY), time.get(Calendar.MINUTE))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "✅ [NATIVE] Service onStartCommand - will restart if killed")
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🛑 [NATIVE] Prayer DND Service destroyed")
        
        handler?.removeCallbacks(prayerChecker!!)
        if (isDNDCurrentlyActive) {
            disableNativeDND()
        }
        wakeLock?.let { if (it.isHeld) it.release() }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    data class PrayerTime(
        val name: String,
        val startTime: Calendar
    )
}
