
package com.x319.notifybank.channels

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.x319.notifybank.Constants
import com.x319.notifybank.MainActivity
import com.x319.notifybank.SmsStorage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Channel để quản lý việc nhận tin nhắn SMS và gửi thông báo đến Flutter
 */
class SmsReceiverChannel(
    private val flutterEngine: FlutterEngine,
    private val activity: MainActivity
) {
    private val TAG = "SmsReceiverChannel"
    
    private lateinit var smsStorage: SmsStorage
    private var smsReceiver: BroadcastReceiver? = null
    
    fun setup() {
        smsStorage = SmsStorage(activity)
        
        // Thiết lập Method Channel để xử lý các lệnh từ Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.SMS_RECEIVER_CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "SMS Receiver method call received: ${call.method}")
            try {
                when (call.method) {
                    // Các phương thức kiểm tra quyền
                    "checkSmsReceiverPermission" -> {
                        val isGranted = checkSmsReceiverPermissions()
                        result.success(isGranted)
                        Log.d(TAG, "SMS receiver permission status: $isGranted")
                    }
                    "checkReadSmsPermission" -> {
                        val isGranted = checkReadSmsPermission()
                        result.success(isGranted)
                        Log.d(TAG, "READ_SMS permission status: $isGranted")
                    }
                    "checkReceiveSmsPermission" -> {
                        val isGranted = checkReceiveSmsPermission()
                        result.success(isGranted)
                        Log.d(TAG, "RECEIVE_SMS permission status: $isGranted")
                    }
                    
                    // Các phương thức yêu cầu quyền
                    "requestSmsReceiverPermission" -> {
                        requestSmsReceiverPermissions()
                        result.success(true)
                        Log.d(TAG, "SMS receiver permission requested")
                    }
                    "requestReadSmsPermission" -> {
                        requestReadSmsPermission()
                        result.success(true)
                        Log.d(TAG, "READ_SMS permission requested")
                    }
                    "requestReceiveSmsPermission" -> {
                        requestReceiveSmsPermission()
                        result.success(true)
                        Log.d(TAG, "RECEIVE_SMS permission requested")
                    }
                    
                    // Các phương thức xử lý SMS
                    "getReceivedSms" -> {
                        val limit = call.argument<Int>("limit") ?: 50
                        val onlyUnread = call.argument<Boolean>("onlyUnread") ?: false
                        val messages = smsStorage.getIncomingSms(limit, onlyUnread)
                        
                        val jsonArray = JSONArray()
                        for (message in messages) {
                            val jsonObject = JSONObject()
                            for ((key, value) in message) {
                                jsonObject.put(key, value)
                            }
                            jsonArray.put(jsonObject)
                        }
                        
                        result.success(jsonArray.toString())
                        Log.d(TAG, "Retrieved ${messages.size} received SMS messages")
                    }
                    "markSmsAsRead" -> {
                        val id = call.argument<String>("id") ?: throw Exception("SMS ID is required")
                        val success = smsStorage.markSmsAsRead(id)
                        result.success(success)
                        Log.d(TAG, "Marked SMS with ID $id as read: $success")
                    }
                    "markAllSmsAsRead" -> {
                        val count = smsStorage.markAllSmsAsRead()
                        result.success(count)
                        Log.d(TAG, "Marked $count SMS messages as read")
                    }
                    "deleteSms" -> {
                        val id = call.argument<String>("id") ?: throw Exception("SMS ID is required")
                        val success = smsStorage.deleteSms(id, true) // true for incoming SMS
                        result.success(success)
                        Log.d(TAG, "Deleted SMS with ID $id: $success")
                    }
                    "deleteAllSms" -> {
                        val count = smsStorage.deleteAllSms(true) // true for incoming SMS
                        result.success(count)
                        Log.d(TAG, "Deleted $count SMS messages")
                    }
                    "searchSms" -> {
                        val query = call.argument<String>("query") ?: ""
                        val limit = call.argument<Int>("limit") ?: 50
                        val messages = smsStorage.searchSms(query, true, limit) // true for incoming SMS
                        
                        val jsonArray = JSONArray()
                        for (message in messages) {
                            val jsonObject = JSONObject()
                            for ((key, value) in message) {
                                jsonObject.put(key, value)
                            }
                            jsonArray.put(jsonObject)
                        }
                        
                        result.success(jsonArray.toString())
                        Log.d(TAG, "Found ${messages.size} SMS messages matching query: $query")
                    }
                    "getUnreadCount" -> {
                        val count = smsStorage.getUnreadCount()
                        result.success(count)
                        Log.d(TAG, "Unread SMS count: $count")
                    }
                    "getSmsStats" -> {
                        val stats = smsStorage.getSmsStats()
                        val jsonObject = JSONObject()
                        for ((key, value) in stats) {
                            jsonObject.put(key, value)
                        }
                        result.success(jsonObject.toString())
                        Log.d(TAG, "Retrieved SMS stats")
                    }
                    "startListening" -> {
                        val success = startListeningForSms()
                        result.success(success)
                        Log.d(TAG, "Started listening for SMS: $success")
                    }
                    "stopListening" -> {
                        stopListeningForSms()
                        result.success(true)
                        Log.d(TAG, "Stopped listening for SMS")
                    }
                    else -> {
                        result.notImplemented()
                        Log.d(TAG, "SMS receiver method not implemented: ${call.method}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in SMS receiver method call: ${call.method}", e)
                result.error("SMS_RECEIVER_ERROR", e.message, e.stackTraceToString())
            }
        }
        
        // Thiết lập Event Channel để gửi sự kiện tin nhắn mới về Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.SMS_RECEIVER_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events != null) {
                        setupSmsReceiver(events)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    stopListeningForSms()
                }
            }
        )
    }
    
    // Thiết lập BroadcastReceiver để lắng nghe tin nhắn mới
    private fun setupSmsReceiver(events: EventChannel.EventSink) {
        if (smsReceiver != null) {
            stopListeningForSms()
        }
        
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == "com.x319.notifybank.SMS_RECEIVED") {
                    val sender = intent.getStringExtra("sender") ?: "Unknown"
                    val message = intent.getStringExtra("message") ?: ""
                    val timestamp = intent.getLongExtra("timestamp", System.currentTimeMillis())
                    
                    try {
                        val jsonObject = JSONObject().apply {
                            put("sender", sender)
                            put("message", message)
                            put("timestamp", timestamp)
                            put("isRead", false)
                        }
                        
                        events.success(jsonObject.toString())
                        Log.d(TAG, "SMS event sent to Flutter: $sender")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error sending SMS event to Flutter", e)
                        events.error("SMS_EVENT_ERROR", e.message, e.stackTraceToString())
                    }
                }
            }
        }
        
        activity.registerReceiver(smsReceiver, IntentFilter("com.x319.notifybank.SMS_RECEIVED"))
        Log.d(TAG, "SMS receiver registered")
    }
    
    // Bắt đầu lắng nghe tin nhắn SMS
    private fun startListeningForSms(): Boolean {
        if (checkSmsReceiverPermissions()) {
            // Đảm bảo service đang chạy
            activity.isServiceRunning()
            return true
        }
        requestSmsReceiverPermissions()
        return false
    }
    
    // Dừng lắng nghe tin nhắn SMS
    private fun stopListeningForSms() {
        if (smsReceiver != null) {
            try {
                activity.unregisterReceiver(smsReceiver)
                Log.d(TAG, "SMS receiver unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering SMS receiver", e)
            }
            smsReceiver = null
        }
    }
    
    // Kiểm tra quyền đọc SMS
    private fun checkReadSmsPermission(): Boolean {
        val readSmsPermission = ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        Log.d(TAG, "READ_SMS permission status: $readSmsPermission")
        return readSmsPermission
    }
    
    // Kiểm tra quyền nhận SMS
    private fun checkReceiveSmsPermission(): Boolean {
        val receiveSmsPermission = ContextCompat.checkSelfPermission(activity, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
        Log.d(TAG, "RECEIVE_SMS permission status: $receiveSmsPermission")
        return receiveSmsPermission
    }
    
    // Kiểm tra cả hai quyền đọc và nhận SMS
    private fun checkSmsReceiverPermissions(): Boolean {
        val readSmsPermission = checkReadSmsPermission()
        val receiveSmsPermission = checkReceiveSmsPermission()
        
        Log.d(TAG, "SMS permissions: READ_SMS=$readSmsPermission, RECEIVE_SMS=$receiveSmsPermission")
        return readSmsPermission && receiveSmsPermission
    }
    
    // Yêu cầu quyền đọc SMS
    private fun requestReadSmsPermission() {
        if (!checkReadSmsPermission()) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.READ_SMS),
                Constants.READ_SMS_PERMISSION_CODE
            )
            Log.d(TAG, "Requesting READ_SMS permission")
        } else {
            Log.d(TAG, "READ_SMS permission already granted")
        }
    }
    
    // Yêu cầu quyền nhận SMS
    private fun requestReceiveSmsPermission() {
        if (!checkReceiveSmsPermission()) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.RECEIVE_SMS),
                Constants.RECEIVE_SMS_PERMISSION_CODE
            )
            Log.d(TAG, "Requesting RECEIVE_SMS permission")
        } else {
            Log.d(TAG, "RECEIVE_SMS permission already granted")
        }
    }
    
    // Yêu cầu cả hai quyền đọc và nhận SMS
    private fun requestSmsReceiverPermissions() {
        val permissions = mutableListOf<String>()
        
        if (!checkReadSmsPermission()) {
            permissions.add(Manifest.permission.READ_SMS)
        }
        
        if (!checkReceiveSmsPermission()) {
            permissions.add(Manifest.permission.RECEIVE_SMS)
        }
        
        if (permissions.isNotEmpty()) {
            Log.d(TAG, "Requesting SMS permissions: ${permissions.joinToString()}")
            ActivityCompat.requestPermissions(
                activity,
                permissions.toTypedArray(),
                Constants.BOTH_SMS_PERMISSIONS_CODE
            )
        } else {
            Log.d(TAG, "All SMS permissions already granted")
        }
    }
}