package com.example.auto_silent

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.example.salah_silence/silent_mode"
        private const val NATIVE_DND_CHANNEL = "com.example.auto_silent/native_dnd"
        
        // Request codes for activities
        private const val DND_PERMISSION_REQUEST_CODE = 1001
        private const val BATTERY_OPTIMIZATION_REQUEST_CODE = 1002
    }
    
    private var previousRingerMode = AudioManager.RINGER_MODE_NORMAL
    private var previousInterruptionFilter = NotificationManager.INTERRUPTION_FILTER_ALL
    private var isInSilentMode = false
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 🔥 NATIVE DND SERVICE METHOD CHANNEL (Critical for app-kill survival)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_DND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startNativeDNDService" -> {
                    try {
                        val intent = Intent(this, PrayerDNDService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            ContextCompat.startForegroundService(this, intent)
                        }
                        android.util.Log.i(TAG, "✅ Native DND service started successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e(TAG, "❌ Failed to start native DND service", e)
                        result.error("SERVICE_ERROR", "Failed to start native DND service: ${e.message}", null)
                    }
                }
                "stopNativeDNDService" -> {
                    try {
                        val intent = Intent(this, PrayerDNDService::class.java)
                        stopService(intent)
                        android.util.Log.i(TAG, "✅ Native DND service stopped successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e(TAG, "❌ Failed to stop native DND service", e)
                        result.error("SERVICE_ERROR", "Failed to stop native DND service: ${e.message}", null)
                    }
                }
                "isNativeServiceRunning" -> {
                    try {
                        val isRunning = isServiceRunning(PrayerDNDService::class.java)
                        result.success(isRunning)
                    } catch (e: Exception) {
                        android.util.Log.e(TAG, "Error checking service status", e)
                        result.error("SERVICE_ERROR", "Failed to check service status: ${e.message}", null)
                    }
                }
                "getNativeServiceStatus" -> {
                    try {
                        val status = mapOf(
                            "isRunning" to isServiceRunning(PrayerDNDService::class.java),
                            "timestamp" to System.currentTimeMillis(),
                            "foregroundServiceSupported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        )
                        result.success(status)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", "Failed to get service status: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // FLUTTER DND METHOD CHANNEL (Enhanced with comprehensive error handling)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    // ===== PERMISSION & STATUS METHODS =====
                    "checkAllPermissions" -> {
                        result.success(checkAllRequiredPermissions())
                    }
                    "isDNDPermissionGranted" -> {
                        result.success(isDNDPermissionGranted())
                    }
                    "canModifyAudioSettings" -> {
                        result.success(canModifyAudioSettings())
                    }
                    "getCurrentRingerMode" -> {
                        result.success(getCurrentRingerMode())
                    }
                    "getCurrentInterruptionFilter" -> {
                        result.success(getCurrentInterruptionFilter())
                    }
                    "testDNDFunctionality" -> {
                        result.success(testDNDImplementation())
                    }
                    "getDeviceInfo" -> {
                        result.success(getDeviceInfo())
                    }
                    
                    // ===== DND CONTROL METHODS =====
                    "enableSilentMode" -> {
                        val duration = call.argument<Int>("duration") ?: 20
                        val prayerName = call.argument<String>("prayer_name") ?: "Prayer"
                        result.success(enableSilentMode(duration, prayerName))
                    }
                    "disableSilentMode" -> {
                        result.success(disableSilentMode())
                    }
                    "setVibrateMode" -> {
                        result.success(setVibrateMode())
                    }
                    "resetToNormalMode" -> {
                        result.success(resetToNormalMode())
                    }
                    "toggleSilentMode" -> {
                        result.success(toggleSilentMode())
                    }
                    
                    // ===== PERMISSION REQUEST METHODS =====
                    "requestDNDPermissionOnly" -> {
                        requestDNDPermissionOnly()
                        result.success(true)
                    }
                    "requestBatteryOptimizationOnly" -> {
                        requestBatteryOptimizationOnly()
                        result.success(true)
                    }
                    "requestAllPermissions" -> {
                        requestAllRequiredPermissions()
                        result.success(true)
                    }
                    
                    // ===== SETTINGS NAVIGATION METHODS =====
                    "openDNDSettings" -> {
                        openDNDSettings()
                        result.success(true)
                    }
                    "openAppSpecificDNDSettings" -> {
                        openAppSpecificDNDSettings()
                        result.success(true)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(true)
                    }
                    "openBatteryOptimizationSettings" -> {
                        openBatteryOptimizationSettings()
                        result.success(true)
                    }
                    "openAutoStartSettings" -> {
                        openAutoStartSettings()
                        result.success(true)
                    }
                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(true)
                    }
                    
                    // ===== ALARM MANAGER METHODS (With reflection for safety) =====
                    "schedulePrayerAlarm" -> {
                        val prayerName = call.argument<String>("prayer_name") ?: ""
                        val startTimeMillis = call.argument<Long>("start_time_millis") ?: 0L
                        val durationMinutes = call.argument<Int>("duration_minutes") ?: 20
                        
                        result.success(schedulePrayerAlarmSafe(prayerName, startTimeMillis, durationMinutes))
                    }
                    "cancelPrayerAlarm" -> {
                        val prayerName = call.argument<String>("prayer_name") ?: ""
                        result.success(cancelPrayerAlarmSafe(prayerName))
                    }
                    "cancelAllPrayerAlarms" -> {
                        result.success(cancelAllPrayerAlarmsSafe())
                    }
                    "scheduleAllTodaysPrayerAlarms" -> {
                        val prayerData = call.argument<List<Map<String, Any>>>("prayers") ?: emptyList()
                        val durationMinutes = call.argument<Int>("duration_minutes") ?: 20
                        result.success(scheduleAllPrayerAlarmsSafe(prayerData, durationMinutes))
                    }
                    "isAlarmScheduled" -> {
                        val prayerName = call.argument<String>("prayer_name") ?: ""
                        result.success(isAlarmScheduledSafe(prayerName))
                    }
                    
                    else -> {
                        android.util.Log.w(TAG, "Method not implemented: ${call.method}")
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error in method channel handler for method: ${call.method}", e)
                result.error("UNEXPECTED_ERROR", "Unexpected error: ${e.message}", e.stackTraceToString())
            }
        }
    }

    // ===== SERVICE MANAGEMENT METHODS =====
    
    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        return try {
            val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            @Suppress("DEPRECATION")
            val runningServices = manager.getRunningServices(Integer.MAX_VALUE)
            runningServices.any { it.service.className == serviceClass.name }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error checking if service is running", e)
            false
        }
    }
    
    // ===== PERMISSION CHECKING METHODS =====
    
    private fun checkAllRequiredPermissions(): Map<String, Any> {
        val permissions = mutableMapOf<String, Any>()
        
        try {
            permissions["dnd"] = isDNDPermissionGranted()
            permissions["battery_optimization"] = isBatteryOptimizationIgnored()
            permissions["audio_modification"] = canModifyAudioSettings()
            permissions["notification_access"] = isNotificationAccessGranted()
            permissions["current_ringer_mode"] = getCurrentRingerMode()
            permissions["current_interruption_filter"] = getCurrentInterruptionFilter()
            permissions["is_in_silent_mode"] = isInSilentMode
            permissions["device_info"] = getDeviceInfo()
            permissions["service_running"] = isServiceRunning(PrayerDNDService::class.java)
            permissions["foreground_service_supported"] = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            permissions["alarm_scheduler_available"] = isAlarmSchedulerAvailable()
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error checking permissions", e)
            permissions["error"] = e.message ?: "Unknown error occurred"
            permissions["dnd"] = false
            permissions["battery_optimization"] = false
            permissions["audio_modification"] = false
        }
        
        return permissions
    }
    
    private fun isDNDPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.isNotificationPolicyAccessGranted
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error checking DND permission", e)
                false
            }
        } else {
            true // DND permission not required for older Android versions
        }
    }
    
    private fun isBatteryOptimizationIgnored(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                pm.isIgnoringBatteryOptimizations(packageName)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error checking battery optimization", e)
                false
            }
        } else {
            true // Battery optimization not applicable for older versions
        }
    }
    
    private fun canModifyAudioSettings(): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.ringerMode // Test if we can access ringer mode
            true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Cannot modify audio settings", e)
            false
        }
    }
    
    private fun isNotificationAccessGranted(): Boolean {
        return try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.areNotificationsEnabled()
        } catch (e: Exception) {
            false
        }
    }
    
    private fun getDeviceInfo(): Map<String, Any> {
        return mapOf(
            "manufacturer" to (Build.MANUFACTURER ?: "unknown"),
            "model" to (Build.MODEL ?: "unknown"),
            "android_version" to Build.VERSION.SDK_INT,
            "android_release" to (Build.VERSION.RELEASE ?: "unknown"),
            "device" to (Build.DEVICE ?: "unknown"),
            "brand" to (Build.BRAND ?: "unknown")
        )
    }
    
    // ===== DND CONTROL METHODS =====
    
    private fun enableSilentMode(durationMinutes: Int, prayerName: String = "Prayer"): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Save current state if not already in silent mode
            if (!isInSilentMode) {
                previousRingerMode = audioManager.ringerMode
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    previousInterruptionFilter = notificationManager.currentInterruptionFilter
                }
            }
            
            var success = false
            var method = "none"
            
            // Try DND first (preferred method for API 23+)
            if (isDNDPermissionGranted() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    // Try priority mode first (allows alarms and important calls)
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                    method = "dnd_priority"
                    success = true
                    android.util.Log.i(TAG, "✅ DND Priority mode activated for $prayerName")
                } catch (e: Exception) {
                    try {
                        // Fallback to complete silence
                        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                        method = "dnd_none"
                        success = true
                        android.util.Log.i(TAG, "✅ DND None mode activated for $prayerName")
                    } catch (e2: Exception) {
                        android.util.Log.w(TAG, "DND methods failed: ${e2.message}")
                    }
                }
            }
            
            // Fallback to ringer modes if DND failed
            if (!success) {
                try {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                    method = "vibrate"
                    success = true
                    android.util.Log.i(TAG, "✅ Vibrate mode activated for $prayerName")
                } catch (e: Exception) {
                    try {
                        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                        method = "silent"
                        success = true
                        android.util.Log.i(TAG, "✅ Silent mode activated for $prayerName")
                    } catch (e2: Exception) {
                        android.util.Log.e(TAG, "❌ All silent mode methods failed", e2)
                    }
                }
            }
            
            if (success) {
                isInSilentMode = true
                android.util.Log.i(TAG, "🔕 Silent mode enabled for $prayerName using $method (${durationMinutes}min)")
            }
            
            success
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Error enabling silent mode", e)
            false
        }
    }
    
    private fun disableSilentMode(): Boolean {
        return try {
            if (!isInSilentMode) {
                android.util.Log.d(TAG, "Not in silent mode, nothing to disable")
                return true
            }
            
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            var success = false
            
            // Restore DND state if we have permission
            if (isDNDPermissionGranted() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    notificationManager.setInterruptionFilter(previousInterruptionFilter)
                    android.util.Log.d(TAG, "✅ DND state restored to filter: $previousInterruptionFilter")
                    success = true
                } catch (e: Exception) {
                    android.util.Log.w(TAG, "Failed to restore DND state: ${e.message}")
                }
            }
            
            // Restore ringer mode
            try {
                audioManager.ringerMode = previousRingerMode
                android.util.Log.d(TAG, "✅ Ringer mode restored to: $previousRingerMode")
                success = true
            } catch (e: Exception) {
                try {
                    // Force normal mode if restore fails
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                    android.util.Log.d(TAG, "✅ Forced ringer mode to normal")
                    success = true
                } catch (e2: Exception) {
                    android.util.Log.e(TAG, "Failed to restore ringer mode", e2)
                }
            }
            
            if (success) {
                isInSilentMode = false
                android.util.Log.i(TAG, "🔊 Silent mode disabled successfully")
            }
            
            success
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Error disabling silent mode", e)
            false
        }
    }
    
    private fun setVibrateMode(): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            if (!isInSilentMode) {
                previousRingerMode = audioManager.ringerMode
            }
            
            audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
            isInSilentMode = true
            android.util.Log.i(TAG, "📳 Vibrate mode enabled")
            true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to set vibrate mode", e)
            false
        }
    }
    
    private fun resetToNormalMode(): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Reset DND
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                } catch (e: Exception) {
                    android.util.Log.w(TAG, "Failed to reset DND: ${e.message}")
                }
            }
            
            // Reset ringer mode
            audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
            isInSilentMode = false
            android.util.Log.i(TAG, "🔊 Reset to normal mode")
            true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to reset to normal mode", e)
            false
        }
    }
    
    private fun toggleSilentMode(): Boolean {
        return if (isInSilentMode) {
            disableSilentMode()
        } else {
            enableSilentMode(20, "Manual Toggle")
        }
    }
    
    // ===== STATUS METHODS =====
    
    private fun getCurrentRingerMode(): Int {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.ringerMode
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error getting current ringer mode", e)
            AudioManager.RINGER_MODE_NORMAL
        }
    }
    
    private fun getCurrentInterruptionFilter(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.currentInterruptionFilter
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error getting current interruption filter", e)
                NotificationManager.INTERRUPTION_FILTER_ALL
            }
        } else {
            NotificationManager.INTERRUPTION_FILTER_ALL
        }
    }
    
    private fun testDNDImplementation(): Map<String, Any> {
        val testResults = mutableMapOf<String, Any>()
        
        try {
            testResults["dnd_permission"] = isDNDPermissionGranted()
            testResults["battery_optimization_ignored"] = isBatteryOptimizationIgnored()
            testResults["can_access_notification_manager"] = try {
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                true
            } catch (e: Exception) {
                false
            }
            testResults["can_access_audio_manager"] = canModifyAudioSettings()
            testResults["current_ringer_mode"] = getCurrentRingerMode()
            testResults["current_interruption_filter"] = getCurrentInterruptionFilter()
            testResults["is_in_silent_mode"] = isInSilentMode
            testResults["service_running"] = isServiceRunning(PrayerDNDService::class.java)
            testResults["device_info"] = getDeviceInfo()
            testResults["test_timestamp"] = System.currentTimeMillis()
            testResults["alarm_scheduler_available"] = isAlarmSchedulerAvailable()
            
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error in DND test", e)
            testResults["error"] = e.message ?: "Test failed"
        }
        
        return testResults
    }
    
    // ===== PERMISSION REQUEST METHODS =====
    
    private fun requestAllRequiredPermissions() {
        requestDNDPermissionOnly()
        requestBatteryOptimizationOnly()
    }
    
    private fun requestDNDPermissionOnly() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (!notificationManager.isNotificationPolicyAccessGranted) {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    android.util.Log.i(TAG, "📱 Opened DND permission settings")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to request DND permission", e)
        }
    }
    
    private fun requestBatteryOptimizationOnly() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    android.util.Log.i(TAG, "🔋 Opened battery optimization settings")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to request battery optimization", e)
        }
    }
    
    // ===== SETTINGS NAVIGATION METHODS =====
    
    private fun openDNDSettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            } else {
                Intent(Settings.ACTION_SOUND_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to open DND settings", e)
        }
    }
    
    private fun openAppSpecificDNDSettings() {
        try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.w(TAG, "Failed to open app-specific DND settings, falling back to general DND settings")
            openDNDSettings()
        }
    }
    
    private fun requestIgnoreBatteryOptimizations() {
        requestBatteryOptimizationOnly()
    }
    
    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to open battery optimization settings", e)
        }
    }
    
    private fun openNotificationSettings() {
        try {
            val intent = Intent().apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                } else {
                    action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                    data = Uri.parse("package:$packageName")
                }
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to open notification settings", e)
        }
    }
    
    private fun openAutoStartSettings() {
        try {
            val manufacturer = Build.MANUFACTURER?.lowercase() ?: "unknown"
            val intent = when {
                manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> {
                    try {
                        Intent().setClassName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                    } catch (e: Exception) {
                        Intent().setClassName("com.miui.securitycenter", "com.miui.permcenter.MainAcitivty")
                    }
                }
                manufacturer.contains("oppo") -> {
                    Intent().setClassName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.FakeActivity")
                }
                manufacturer.contains("vivo") -> {
                    Intent().setClassName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                }
                manufacturer.contains("huawei") -> {
                    Intent().setClassName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                }
                manufacturer.contains("samsung") -> {
                    Intent().setClassName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")
                }
                manufacturer.contains("oneplus") -> {
                    Intent().setClassName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")
                }
                else -> {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            android.util.Log.i(TAG, "📱 Opened auto-start settings for $manufacturer")
        } catch (e: Exception) {
            android.util.Log.w(TAG, "Failed to open manufacturer-specific auto-start settings, falling back to app settings")
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (e2: Exception) {
                android.util.Log.e(TAG, "❌ Fallback to app settings also failed", e2)
            }
        }
    }
    
    // ===== ALARM SCHEDULER METHODS (With reflection for safety) =====
    
    private fun isAlarmSchedulerAvailable(): Boolean {
        return try {
            Class.forName("com.example.auto_silent.AlarmScheduler")
            true
        } catch (e: ClassNotFoundException) {
            false
        }
    }
    
    private fun schedulePrayerAlarmSafe(prayerName: String, startTimeMillis: Long, durationMinutes: Int): Boolean {
        return try {
            val schedulerClass = Class.forName("com.example.auto_silent.AlarmScheduler")
            val method = schedulerClass.getMethod("schedulePrayerAlarm", 
                Context::class.java, String::class.java, Long::class.java, Int::class.java)
            method.invoke(null, this, prayerName, startTimeMillis, durationMinutes)
            android.util.Log.i(TAG, "✅ Scheduled alarm for $prayerName at ${java.util.Date(startTimeMillis)}")
            true
        } catch (e: ClassNotFoundException) {
            android.util.Log.w(TAG, "⚠️ AlarmScheduler class not found - please create AlarmScheduler.kt")
            false
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to schedule prayer alarm for $prayerName", e)
            false
        }
    }
    
    private fun cancelPrayerAlarmSafe(prayerName: String): Boolean {
        return try {
            val schedulerClass = Class.forName("com.example.auto_silent.AlarmScheduler")
            val method = schedulerClass.getMethod("cancelPrayerAlarm", Context::class.java, String::class.java)
            method.invoke(null, this, prayerName)
            android.util.Log.i(TAG, "✅ Cancelled alarm for $prayerName")
            true
        } catch (e: ClassNotFoundException) {
            android.util.Log.w(TAG, "⚠️ AlarmScheduler class not found")
            false
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to cancel prayer alarm for $prayerName", e)
            false
        }
    }
    
    private fun cancelAllPrayerAlarmsSafe(): Boolean {
        return try {
            val schedulerClass = Class.forName("com.example.auto_silent.AlarmScheduler")
            val method = schedulerClass.getMethod("cancelAllAlarms", Context::class.java)
            method.invoke(null, this)
            android.util.Log.i(TAG, "✅ Cancelled all prayer alarms")
            true
        } catch (e: ClassNotFoundException) {
            android.util.Log.w(TAG, "⚠️ AlarmScheduler class not found")
            false
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to cancel all prayer alarms", e)
            false
        }
    }
    
    private fun scheduleAllPrayerAlarmsSafe(prayerData: List<Map<String, Any>>, durationMinutes: Int): Boolean {
        return try {
            // First cancel all existing alarms
            cancelAllPrayerAlarmsSafe()
            
            val schedulerClass = Class.forName("com.example.auto_silent.AlarmScheduler")
            val scheduleMethod = schedulerClass.getMethod("schedulePrayerAlarm", 
                Context::class.java, String::class.java, Long::class.java, Int::class.java)
            
            var successCount = 0
            prayerData.forEach { prayer ->
                val name = prayer["name"] as? String ?: ""
                val timeMillis = (prayer["time_millis"] as? Number)?.toLong() ?: 0L
                if (name.isNotEmpty() && timeMillis > 0) {
                    try {
                        scheduleMethod.invoke(null, this, name, timeMillis, durationMinutes)
                        successCount++
                    } catch (e: Exception) {
                        android.util.Log.e(TAG, "❌ Failed to schedule $name alarm", e)
                    }
                }
            }
            
            android.util.Log.i(TAG, "✅ Scheduled $successCount out of ${prayerData.size} prayer alarms")
            successCount == prayerData.size
        } catch (e: ClassNotFoundException) {
            android.util.Log.w(TAG, "⚠️ AlarmScheduler class not found")
            false
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Error scheduling prayer alarms", e)
            false
        }
    }
    
    private fun isAlarmScheduledSafe(prayerName: String): Boolean {
        return try {
            val schedulerClass = Class.forName("com.example.auto_silent.AlarmScheduler")
            val method = schedulerClass.getMethod("isAlarmScheduled", Context::class.java, String::class.java)
            method.invoke(null, this, prayerName) as Boolean
        } catch (e: ClassNotFoundException) {
            false
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ Failed to check if alarm is scheduled for $prayerName", e)
            false
        }
    }
}
