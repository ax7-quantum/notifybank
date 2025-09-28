package com.x319.notifybank.channels

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import com.x319.notifybank.Constants
import com.x319.notifybank.MainActivity
import com.x319.notifybank.MyNotificationListenerService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class NotificationChannel(
    private val flutterEngine: FlutterEngine,
    private val activity: MainActivity,
    private val sharedPreferences: SharedPreferences,
    private val cakeSharedPreferences: SharedPreferences,
    private val mbSharedPreferences: SharedPreferences
) {
    private val TAG = "NotificationChannel"

    fun setup() {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Method call received: ${call.method}")
            when (call.method) {
                "requestNotificationPermission" -> {
                    activity.requestNotificationPermission()
                    result.success(true)
                    Log.d(TAG, "Notification permission requested")
                }
                "checkNotificationPermission" -> {
                    val isEnabled = activity.isNotificationServiceEnabled()
                    result.success(isEnabled)
                    Log.d(TAG, "Notification permission status: $isEnabled")
                }
                "getNotifications" -> {
                    val notifications = getNotificationsFromSharedPrefs()
                    result.success(notifications)
                    Log.d(TAG, "Notifications retrieved, length: ${JSONArray(notifications).length()}")
                }
                "clearNotifications" -> {
                    clearNotifications()
                    result.success(true)
                    Log.d(TAG, "Notifications cleared")
                }
                "checkBatteryOptimization" -> {
                    val isIgnoringBatteryOptimization = activity.checkBatteryOptimizationStatus()
                    result.success(isIgnoringBatteryOptimization)
                    Log.d(TAG, "Battery optimization status: $isIgnoringBatteryOptimization")
                }
                "requestBatteryOptimization" -> {
                    activity.requestBatteryOptimization()
                    result.success(null)
                    Log.d(TAG, "Battery optimization requested")
                }
                "checkAutoStartPermission" -> {
                    val needsAutoStart = activity.needsAutoStartPermission()
                    result.success(needsAutoStart)
                    Log.d(TAG, "Device needs autostart permission: $needsAutoStart")
                }
                "requestAutoStartPermission" -> {
                    activity.openAutoStartSettings()
                    result.success(null)
                    Log.d(TAG, "Autostart settings requested")
                }
                "restartNotificationService" -> {
                    activity.restartNotificationService()
                    result.success(true)
                    Log.d(TAG, "Notification service restart requested")
                }
                "isServiceRunning" -> {
                    val isRunning = activity.isServiceRunning()
                    result.success(isRunning)
                    Log.d(TAG, "Notification service running status: $isRunning")
                }
                "getCakeTransactions" -> {
                    val transactions = getCakeTransactionsFromSharedPrefs()
                    result.success(transactions)
                    Log.d(TAG, "Cake transactions retrieved, length: ${JSONArray(transactions).length()}")
                }
                "clearCakeTransactions" -> {
                    clearCakeTransactions()
                    result.success(true)
                    Log.d(TAG, "Cake transactions cleared")
                }
                "getMBTransactions" -> {
                    val transactions = getMBTransactionsFromSharedPrefs()
                    result.success(transactions)
                    Log.d(TAG, "MB Bank transactions retrieved, length: ${JSONArray(transactions).length()}")
                }
                "clearMBTransactions" -> {
                    clearMBTransactions()
                    result.success(true)
                    Log.d(TAG, "MB Bank transactions cleared")
                }
                "getMomoTransactions" -> {
                    val momoSharedPreferences = activity.getSharedPreferences("momo_transactions", Context.MODE_PRIVATE)
                    val transactions = momoSharedPreferences.getString("momo_transactions", "[]") ?: "[]"
                    result.success(transactions)
                    Log.d(TAG, "MoMo transactions retrieved, length: ${JSONArray(transactions).length()}")
                }
                "clearMomoTransactions" -> {
                    val momoSharedPreferences = activity.getSharedPreferences("momo_transactions", Context.MODE_PRIVATE)
                    momoSharedPreferences.edit().putString("momo_transactions", "[]").apply()
                    result.success(true)
                    Log.d(TAG, "MoMo transactions cleared")
                }
                else -> {
                    result.notImplemented()
                    Log.d(TAG, "Method not implemented: ${call.method}")
                }
            }
        }
    }
    
    private fun getNotificationsFromSharedPrefs(): String {
        val notifications = sharedPreferences.getString("saved_notifications", "[]") ?: "[]"
        Log.d(TAG, "Retrieved notifications from SharedPreferences: $notifications")
        return notifications
    }
    
    private fun clearNotifications() {
        sharedPreferences.edit().putString("saved_notifications", "[]").apply()
        Log.d(TAG, "Notifications cleared in SharedPreferences")
    }
    
    private fun getCakeTransactionsFromSharedPrefs(): String {
        val transactions = cakeSharedPreferences.getString("cake_transactions", "[]") ?: "[]"
        Log.d(TAG, "Retrieved Cake transactions from SharedPreferences: $transactions")
        return transactions
    }
    
    private fun clearCakeTransactions() {
        cakeSharedPreferences.edit().putString("cake_transactions", "[]").apply()
        Log.d(TAG, "Cake transactions cleared in SharedPreferences")
    }
    
    private fun getMBTransactionsFromSharedPrefs(): String {
        val transactions = mbSharedPreferences.getString("mb_transactions", "[]") ?: "[]"
        Log.d(TAG, "Retrieved MB Bank transactions from SharedPreferences: $transactions")
        return transactions
    }
    
    private fun clearMBTransactions() {
        mbSharedPreferences.edit().putString("mb_transactions", "[]").apply()
        Log.d(TAG, "MB Bank transactions cleared in SharedPreferences")
    }
}
