
package com.x319.notifybank.channels

import android.content.SharedPreferences
import android.util.Log
import com.x319.notifybank.MainActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AppInfoChannel(
    flutterEngine: FlutterEngine,
    private val activity: MainActivity,
    private val preferences: SharedPreferences
) {
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.x319.notifybank/app_info")
    private val TAG = "AppInfoChannel"

    fun setup() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isFirstLaunch" -> {
                    val isFirstLaunch = activity.isFirstLaunch()
                    result.success(isFirstLaunch)
                }
                "hasAnyPermission" -> {
                    val hasPermission = activity.hasAnyPermission()
                    result.success(hasPermission)
                }
                "shouldShowIntroDialog" -> {
                    val shouldShow = activity.shouldShowIntroDialog()
                    result.success(shouldShow)
                }
                "markIntroDialogShown" -> {
                    activity.markIntroDialogShown()
                    result.success(true)
                }
                "openAppInfo" -> {
                    activity.openAppInfo()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        Log.d(TAG, "AppInfoChannel setup complete")
    }
}
