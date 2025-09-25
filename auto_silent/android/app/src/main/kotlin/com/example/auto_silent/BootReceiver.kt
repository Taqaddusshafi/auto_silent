package com.example.auto_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
    }
    
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) {
            Log.w(TAG, "❌ Received null context or intent")
            return
        }
        
        Log.d(TAG, "🔄 Boot event received: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.i(TAG, "📱 Device boot completed - rescheduling prayer services")
                handleBootCompleted(context)
            }
            
            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                Log.i(TAG, "🔐 Device boot completed (locked) - starting essential services")
                handleLockedBootCompleted(context)
            }
            
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.i(TAG, "📦 App updated - reinitializing services")
                handleAppUpdated(context, intent)
            }
            
            Intent.ACTION_PACKAGE_REPLACED -> {
                // Only handle if it's our own package
                val packageName = intent.data?.schemeSpecificPart
                if (packageName == context.packageName) {
                    Log.i(TAG, "📦 Our app was updated - reinitializing services")
                    handleAppUpdated(context, intent)
                }
            }
            
            "android.intent.action.QUICKBOOT_POWERON" -> {
                // Handle HTC and some other manufacturer's quick boot
                Log.i(TAG, "⚡ Quick boot detected - rescheduling services")
                handleBootCompleted(context)
            }
            
            else -> {
                Log.w(TAG, "🤷 Unhandled action: ${intent.action}")
            }
        }
    }
    
    private fun handleBootCompleted(context: Context) {
        // Use coroutine to avoid blocking the main thread
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "🔄 Starting boot completion tasks...")
                
                // 1. Check if user has enabled the prayer service
                val isServiceEnabled = isAppEnabled(context)
                if (!isServiceEnabled) {
                    Log.d(TAG, "ℹ️ Prayer service disabled by user - skipping initialization")
                    return@launch
                }
                
                // 2. Reschedule AlarmManager alarms (highest priority)
                rescheduleAlarms(context)
                
                // 3. Start native DND service if needed
                startNativeServices(context)
                
                // 4. Send notification about successful recovery
                notifyServiceRecovery(context, "boot")
                
                Log.i(TAG, "✅ Boot completion tasks finished successfully")
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error during boot completion tasks", e)
                notifyServiceError(context, "Boot recovery failed: ${e.message}")
            }
        }
    }
    
    private fun handleLockedBootCompleted(context: Context) {
        // Handle Direct Boot mode - only start essential services
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "🔐 Starting locked boot tasks...")
                
                // Use device protected storage context for Direct Boot
                val directBootContext = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    context.createDeviceProtectedStorageContext()
                } else {
                    context
                }
                
                // Only start the most essential services in locked mode
                val isServiceEnabled = isAppEnabled(directBootContext)
                if (isServiceEnabled) {
                    startEssentialServices(directBootContext)
                    Log.i(TAG, "✅ Essential services started in locked boot mode")
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error during locked boot tasks", e)
            }
        }
    }
    
    private fun handleAppUpdated(context: Context, intent: Intent) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "📦 Starting app update recovery tasks...")
                
                // App was updated - need to reinitialize everything
                val isServiceEnabled = isAppEnabled(context)
                if (!isServiceEnabled) {
                    Log.d(TAG, "ℹ️ Prayer service disabled - skipping update tasks")
                    return@launch
                }
                
                // Clear old alarms and reschedule
                cancelAllAlarms(context)
                rescheduleAlarms(context)
                
                // Restart services
                startNativeServices(context)
                
                // Notify user about successful update recovery
                notifyServiceRecovery(context, "update")
                
                Log.i(TAG, "✅ App update recovery completed successfully")
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error during app update recovery", e)
                notifyServiceError(context, "Update recovery failed: ${e.message}")
            }
        }
    }
    
    private fun rescheduleAlarms(context: Context) {
        try {
            // Try to use AlarmScheduler with reflection for safety
            val schedulerClass = Class.forName("com.example.auto_silent.AlarmScheduler")
            val method = schedulerClass.getMethod("rescheduleAllAlarms", Context::class.java)
            method.invoke(null, context)
            Log.i(TAG, "✅ Prayer alarms rescheduled successfully")
        } catch (e: ClassNotFoundException) {
            Log.w(TAG, "⚠️ AlarmScheduler class not found - please implement AlarmScheduler.kt")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to reschedule alarms", e)
            throw e
        }
    }
    
    private fun cancelAllAlarms(context: Context) {
        try {
            val schedulerClass = Class.forName("com.example.auto_silent.AlarmScheduler")
            val method = schedulerClass.getMethod("cancelAllAlarms", Context::class.java)
            method.invoke(null, context)
            Log.d(TAG, "✅ All existing alarms cancelled")
        } catch (e: ClassNotFoundException) {
            Log.w(TAG, "⚠️ AlarmScheduler not available for cleanup")
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Failed to cancel existing alarms", e)
        }
    }
    
    private fun startNativeServices(context: Context) {
        try {
            // Start the native DND service
            val serviceIntent = Intent(context, PrayerDNDService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.i(TAG, "✅ Native DND service started")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start native services", e)
            throw e
        }
    }
    
    private fun startEssentialServices(context: Context) {
        try {
            // Start only the most essential services for Direct Boot mode
            val serviceIntent = Intent(context, PrayerDNDService::class.java).apply {
                putExtra("DIRECT_BOOT_MODE", true)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.i(TAG, "✅ Essential services started for Direct Boot")
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Failed to start essential services", e)
        }
    }
    
    private fun isAppEnabled(context: Context): Boolean {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.isAppEnabled", false)
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Could not check if app is enabled, defaulting to false", e)
            false
        }
    }
    
    private fun notifyServiceRecovery(context: Context, recoveryType: String) {
        try {
            PrayerNotificationHelper.showServiceStatusNotification(
                context,
                "🔄 Prayer Service Recovered",
                "Prayer monitoring restored after $recoveryType",
                isError = false
            )
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Failed to show recovery notification", e)
        }
    }
    
    private fun notifyServiceError(context: Context, errorMessage: String) {
        try {
            PrayerNotificationHelper.showServiceStatusNotification(
                context,
                "❌ Prayer Service Error",
                errorMessage,
                isError = true
            )
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Failed to show error notification", e)
        }
    }
}
