package com.x319.notifybank.channels

import android.util.Log
import com.x319.notifybank.AppSettings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class AppSettingsChannel(
    private val flutterEngine: FlutterEngine,
    private val appSettings: AppSettings
) {
    private val APP_SETTINGS_CHANNEL = "com.x319.notifybank/appsettings"
    private val TAG = "AppSettingsChannel"

    fun setup() {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "AppSettings method call received: ${call.method}")
            try {
                when (call.method) {
                    "getNotificationThreads" -> {
                        val threads = appSettings.getNotificationThreads()
                        result.success(threads)
                        Log.d(TAG, "Current notification threads: $threads")
                    }
                    "setNotificationThreads" -> {
                        val threads = call.argument<Int>("threads") ?: throw Exception("Threads count is required")
                        val actualThreads = appSettings.setNotificationThreads(threads)
                        result.success(actualThreads)
                        Log.d(TAG, "Notification threads set to: $actualThreads")
                    }
                    "increaseThreads" -> {
                        val newThreads = appSettings.increaseThreads()
                        result.success(newThreads)
                        Log.d(TAG, "Notification threads increased to: $newThreads")
                    }
                    "decreaseThreads" -> {
                        val newThreads = appSettings.decreaseThreads()
                        result.success(newThreads)
                        Log.d(TAG, "Notification threads decreased to: $newThreads")
                    }
                    "isSaveNotificationsEnabled" -> {
                        val enabled = appSettings.isSaveNotificationsEnabled()
                        result.success(enabled)
                        Log.d(TAG, "Save notifications enabled: $enabled")
                    }
                    "setSaveNotifications" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: throw Exception("Enabled status is required")
                        appSettings.setSaveNotifications(enabled)
                        result.success(true)
                        Log.d(TAG, "Save notifications set to: $enabled")
                    }
                    "enableSaveNotifications" -> {
                        appSettings.enableSaveNotifications()
                        result.success(true)
                        Log.d(TAG, "Save notifications enabled")
                    }
                    "disableSaveNotifications" -> {
                        appSettings.disableSaveNotifications()
                        result.success(true)
                        Log.d(TAG, "Save notifications disabled")
                    }
                    "toggleSaveNotifications" -> {
                        val newState = appSettings.toggleSaveNotifications()
                        result.success(newState)
                        Log.d(TAG, "Save notifications toggled to: $newState")
                    }
                    "resetToDefaults" -> {
                        appSettings.resetToDefaults()
                        result.success(true)
                        Log.d(TAG, "App settings reset to defaults")
                    }
                    "getMaxThreads" -> {
                        val maxThreads = appSettings.getMaxThreads()
                        result.success(maxThreads)
                        Log.d(TAG, "Max notification threads: $maxThreads")
                    }
                    "getMinThreads" -> {
                        val minThreads = appSettings.getMinThreads()
                        result.success(minThreads)
                        Log.d(TAG, "Min notification threads: $minThreads")
                    }
                    "getAppSettings" -> {
                        val settings = JSONObject().apply {
                            put("notificationThreads", appSettings.getNotificationThreads())
                            put("saveNotifications", appSettings.isSaveNotificationsEnabled())
                            put("maxThreads", appSettings.getMaxThreads())
                            put("minThreads", appSettings.getMinThreads())
                        }
                        result.success(settings.toString())
                        Log.d(TAG, "App settings retrieved: ${settings.toString()}")
                    }
                    else -> {
                        result.notImplemented()
                        Log.d(TAG, "AppSettings method not implemented: ${call.method}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in AppSettings method call: ${call.method}", e)
                result.error("SETTINGS_ERROR", e.message, e.stackTraceToString())
            }
        }
    }
}
