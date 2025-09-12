package com.example.auto_silent

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat  // ADD THIS IMPORT
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.salah_silence/silent_mode"
    private val NATIVE_DND_CHANNEL = "com.example.auto_silent/native_dnd"  // ADD THIS LINE
    
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
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", "Failed to start native DND service: ${e.message}", null)
                    }
                }
                "stopNativeDNDService" -> {
                    try {
                        val intent = Intent(this, PrayerDNDService::class.java)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", "Failed to stop native DND service: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // YOUR EXISTING FLUTTER METHOD CHANNEL (Keep all your existing methods)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ===== ALL YOUR EXISTING METHODS =====
                "checkAllPermissions" -> {
                    result.success(checkAllRequiredPermissions())
                }
                "isDNDPermissionGranted" -> {
                    result.success(isDNDPermissionGranted())
                }
                "enableSilentMode" -> {
                    val duration = call.argument<Int>("duration") ?: 20
                    result.success(enableSilentMode(duration))
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
                "requestDNDPermissionOnly" -> {
                    requestDNDPermissionOnly()
                    result.success(true)
                }
                "requestBatteryOptimizationOnly" -> {
                    requestBatteryOptimizationOnly()
                    result.success(true)
                }
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
                "getCurrentRingerMode" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    result.success(am.ringerMode)
                }
                "getCurrentInterruptionFilter" -> {
                    result.success(getCurrentInterruptionFilter())
                }
                "testDNDFunctionality" -> {
                    result.success(testDNDImplementation())
                }
                "canModifyAudioSettings" -> {
                    result.success(canModifyAudioSettings())
                }
                
                // ===== ALARM MANAGER METHODS (Comment these out if AlarmScheduler is missing) =====
                "schedulePrayerAlarm" -> {
                    val prayerName = call.argument<String>("prayer_name") ?: ""
                    val startTimeMillis = call.argument<Long>("start_time_millis") ?: 0L
                    val durationMinutes = call.argument<Int>("duration_minutes") ?: 20
                    
                    try {
                        AlarmScheduler.schedulePrayerAlarm(this, prayerName, startTimeMillis, durationMinutes)
                        result.success(true)
                    } catch (e: Exception) {
                        println("Failed to schedule prayer alarm: ${e.message}")
                        result.success(false)
                    }
                }
                "cancelPrayerAlarm" -> {
                    val prayerName = call.argument<String>("prayer_name") ?: ""
                    try {
                        AlarmScheduler.cancelPrayerAlarm(this, prayerName)
                        result.success(true)
                    } catch (e: Exception) {
                        println("Failed to cancel prayer alarm: ${e.message}")
                        result.success(false)
                    }
                }
                "cancelAllPrayerAlarms" -> {
                    try {
                        AlarmScheduler.cancelAllAlarms(this)
                        result.success(true)
                    } catch (e: Exception) {
                        println("Failed to cancel all alarms: ${e.message}")
                        result.success(false)
                    }
                }
                "scheduleAllTodaysPrayerAlarms" -> {
                    val prayerData = call.argument<List<Map<String, Any>>>("prayers") ?: emptyList()
                    val durationMinutes = call.argument<Int>("duration_minutes") ?: 20
                    
                    try {
                        AlarmScheduler.cancelAllAlarms(this)
                        
                        var successCount = 0
                        prayerData.forEach { prayer ->
                            val name = prayer["name"] as? String ?: ""
                            val timeMillis = prayer["time_millis"] as? Long ?: 0L
                            if (name.isNotEmpty() && timeMillis > 0) {
                                try {
                                    AlarmScheduler.schedulePrayerAlarm(this, name, timeMillis, durationMinutes)
                                    successCount++
                                } catch (e: Exception) {
                                    println("Failed to schedule $name alarm: ${e.message}")
                                }
                            }
                        }
                        
                        println("Scheduled $successCount out of ${prayerData.size} prayer alarms")
                        result.success(successCount == prayerData.size)
                    } catch (e: Exception) {
                        println("Error scheduling prayer alarms: ${e.message}")
                        result.success(false)
                    }
                }
                
                else -> result.notImplemented()
            }
        }
    }
    
    // ===== ALL YOUR EXISTING METHODS (Keep exactly as they are) =====
    private fun checkAllRequiredPermissions(): Map<String, Any> {
        val permissions = mutableMapOf<String, Any>()
        
        try {
            permissions["dnd"] = isDNDPermissionGranted()
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                permissions["battery_optimization"] = pm.isIgnoringBatteryOptimizations(packageName)
            } else {
                permissions["battery_optimization"] = true
            }
            
            permissions["audio_modification"] = canModifyAudioSettings()
            permissions["current_ringer_mode"] = getCurrentRingerMode()
            permissions["current_interruption_filter"] = getCurrentInterruptionFilter()
            permissions["is_in_silent_mode"] = isInSilentMode
            permissions["manufacturer"] = Build.MANUFACTURER ?: "unknown"
            permissions["model"] = Build.MODEL ?: "unknown"
            permissions["android_version"] = Build.VERSION.SDK_INT
            permissions["android_release"] = Build.VERSION.RELEASE ?: "unknown"
            
        } catch (e: Exception) {
            permissions["dnd"] = false
            permissions["battery_optimization"] = false
            permissions["audio_modification"] = false
            permissions["error"] = e.message ?: "Unknown error"
        }
        
        return permissions
    }

    private fun enableSilentMode(durationMinutes: Int): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            if (!isInSilentMode) {
                previousRingerMode = audioManager.ringerMode
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    previousInterruptionFilter = notificationManager.currentInterruptionFilter
                }
            }
            
            var success = false
            var method = "none"
            
            if (isDNDPermissionGranted() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                    method = "dnd_none"
                    success = true
                    println("DND None mode activated successfully")
                } catch (e: Exception) {
                    println("DND None failed: ${e.message}")
                }
            }
            
            if (!success) {
                try {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                    method = "vibrate"
                    success = true
                    println("Vibrate mode activated successfully")
                } catch (e: Exception) {
                    try {
                        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                        method = "silent"
                        success = true
                        println("Silent mode activated successfully")
                    } catch (e2: Exception) {
                        println("Silent mode also failed: ${e2.message}")
                        success = false
                    }
                }
            }
            
            if (success) {
                isInSilentMode = true
                println("Silent mode enabled using method: $method")
            }
            
            success
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun disableSilentMode(): Boolean {
        return try {
            if (!isInSilentMode) {
                return true
            }
            
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            var success = false
            
            if (isDNDPermissionGranted() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    notificationManager.setInterruptionFilter(previousInterruptionFilter)
                    success = true
                } catch (e: Exception) {
                    println("Failed to restore DND state: ${e.message}")
                }
            }
            
            try {
                audioManager.ringerMode = previousRingerMode
                success = true
            } catch (e: Exception) {
                try {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                    success = true
                } catch (e2: Exception) {
                    println("Failed to force normal mode: ${e2.message}")
                }
            }
            
            if (success) {
                isInSilentMode = false
            }
            
            success
        } catch (e: Exception) {
            e.printStackTrace()
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
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun resetToNormalMode(): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                } catch (e: Exception) {
                    println("Failed to reset DND: ${e.message}")
                }
            }
            
            audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
            isInSilentMode = false
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isDNDPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.isNotificationPolicyAccessGranted
            } catch (e: Exception) {
                false
            }
        } else {
            true
        }
    }

    private fun requestDNDPermissionOnly() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (!notificationManager.isNotificationPolicyAccessGranted) {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
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
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun canModifyAudioSettings(): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.ringerMode
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun getCurrentRingerMode(): Int {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.ringerMode
        } catch (e: Exception) {
            AudioManager.RINGER_MODE_NORMAL
        }
    }

    private fun getCurrentInterruptionFilter(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.currentInterruptionFilter
            } catch (e: Exception) {
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
            testResults["manufacturer"] = Build.MANUFACTURER ?: "unknown"
            testResults["model"] = Build.MODEL ?: "unknown"
            testResults["android_version"] = Build.VERSION.SDK_INT
            testResults["test_timestamp"] = System.currentTimeMillis()
            
        } catch (e: Exception) {
            testResults["error"] = e.message ?: "Test failed"
        }
        
        return testResults
    }

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
            e.printStackTrace()
        }
    }

    private fun openAppSpecificDNDSettings() {
        try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            openDNDSettings()
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
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
                else -> {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (e2: Exception) {
                println("Fallback to app settings also failed: ${e2.message}")
            }
        }
    }
}
