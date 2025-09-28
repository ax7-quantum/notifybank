package com.x319.notifybank.channels

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.x319.notifybank.Constants
import com.x319.notifybank.MainActivity
import com.x319.notifybank.SmsManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class SmsChannel(
    private val flutterEngine: FlutterEngine,
    private val activity: MainActivity,
    private val smsManager: SmsManager
) {
    private val TAG = "SmsChannel"

    fun setup() {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.SMS_CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "SMS method call received: ${call.method}")
            try {
                when (call.method) {
                    "checkSmsPermission" -> {
                        val isGranted = checkSmsPermission()
                        result.success(isGranted)
                        Log.d(TAG, "SMS permission status: $isGranted")
                    }
                    "requestSmsPermission" -> {
                        requestSmsPermission()
                        result.success(true)
                        Log.d(TAG, "SMS permission requested")
                    }
                    // Thêm các phương thức xử lý quyền Phone State
                    "checkPhoneStatePermission" -> {
                        val isGranted = checkPhoneStatePermission()
                        result.success(isGranted)
                        Log.d(TAG, "Phone state permission status: $isGranted")
                    }
                    "requestPhoneStatePermission" -> {
                        requestPhoneStatePermission()
                        result.success(true)
                        Log.d(TAG, "Phone state permission requested")
                    }
                    "sendSms" -> {
                        val phoneNumber = call.argument<String>("phoneNumber") ?: throw Exception("Phone number is required")
                        val message = call.argument<String>("message") ?: throw Exception("Message is required")
                        
                        if (checkSmsPermission()) {
                            smsManager.sendSms(phoneNumber, message)
                            result.success(true)
                            Log.d(TAG, "SMS sent to: $phoneNumber")
                        } else {
                            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                            Log.e(TAG, "Cannot send SMS: permission denied")
                        }
                    }
                    // Thêm các phương thức mới
                    "getAvailableSims" -> {
                        if (checkPhoneStatePermission()) {
                            val sims = smsManager.getAvailableSims()
                            val jsonArray = JSONArray()
                            for (sim in sims) {
                                val jsonObject = JSONObject()
                                for ((key, value) in sim) {
                                    jsonObject.put(key, value)
                                }
                                jsonArray.put(jsonObject)
                            }
                            result.success(jsonArray.toString())
                            Log.d(TAG, "Available SIMs retrieved: ${sims.size}")
                        } else {
                            requestPhoneStatePermission()
                            result.error("PERMISSION_DENIED", "Phone state permission not granted", null)
                            Log.e(TAG, "Cannot get SIMs: phone state permission denied")
                        }
                    }
                    "sendSmsWithSim" -> {
                        val phoneNumber = call.argument<String>("phoneNumber") ?: throw Exception("Phone number is required")
                        val message = call.argument<String>("message") ?: throw Exception("Message is required")
                        val subscriptionId = call.argument<Int>("subscriptionId") ?: throw Exception("Subscription ID is required")
                        
                        if (checkSmsPermission()) {
                            val success = smsManager.sendSmsWithSim(phoneNumber, message, subscriptionId)
                            result.success(success)
                            Log.d(TAG, "SMS sent to: $phoneNumber using SIM $subscriptionId, success: $success")
                        } else {
                            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                            Log.e(TAG, "Cannot send SMS: permission denied")
                        }
                    }
                    "sendBulkSms" -> {
                        val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: throw Exception("Phone numbers are required")
                        val message = call.argument<String>("message") ?: throw Exception("Message is required")
                        
                        if (checkSmsPermission()) {
                            val results = smsManager.sendBulkSms(phoneNumbers, message)
                            val jsonObject = JSONObject()
                            for ((number, success) in results) {
                                jsonObject.put(number, success)
                            }
                            result.success(jsonObject.toString())
                            Log.d(TAG, "Bulk SMS sent to ${phoneNumbers.size} numbers")
                        } else {
                            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                            Log.e(TAG, "Cannot send bulk SMS: permission denied")
                        }
                    }
                    "sendBulkSmsWithSim" -> {
                        val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: throw Exception("Phone numbers are required")
                        val message = call.argument<String>("message") ?: throw Exception("Message is required")
                        val subscriptionId = call.argument<Int>("subscriptionId") ?: throw Exception("Subscription ID is required")
                        
                        if (checkSmsPermission()) {
                            val results = smsManager.sendBulkSmsWithSim(phoneNumbers, message, subscriptionId)
                            val jsonObject = JSONObject()
                            for ((number, success) in results) {
                                jsonObject.put(number, success)
                            }
                            result.success(jsonObject.toString())
                            Log.d(TAG, "Bulk SMS sent to ${phoneNumbers.size} numbers using SIM $subscriptionId")
                        } else {
                            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                            Log.e(TAG, "Cannot send bulk SMS: permission denied")
                        }
                    }
                    "getSmsHistory" -> {
                        val limit = call.argument<Int>("limit") ?: 50
                        val history = smsManager.getSmsHistory(limit)
                        result.success(history)
                        Log.d(TAG, "SMS history retrieved with limit: $limit")
                    }
                    "clearSmsHistory" -> {
                        val success = smsManager.clearSmsHistory()
                        result.success(success)
                        Log.d(TAG, "SMS history cleared: $success")
                    }
                    "getSmsCountToday" -> {
                        val count = smsManager.getSmsCountToday()
                        result.success(count)
                        Log.d(TAG, "SMS count today: $count")
                    }
                    "canSendMoreSms" -> {
                        val dailyLimit = call.argument<Int>("dailyLimit") ?: 100
                        val canSend = smsManager.canSendMoreSms(dailyLimit)
                        result.success(canSend)
                        Log.d(TAG, "Can send more SMS: $canSend (limit: $dailyLimit)")
                    }
                    "getReceivedSms" -> {
                        val limit = call.argument<Int>("limit") ?: 50
                        val receivedSms = smsManager.getReceivedSms(limit)
                        result.success(receivedSms)
                        Log.d(TAG, "Received SMS retrieved with limit: $limit")
                    }
                    "markSmsAsRead" -> {
                        val index = call.argument<Int>("index") ?: throw Exception("SMS index is required")
                        val success = smsManager.markSmsAsRead(index)
                        result.success(success)
                        Log.d(TAG, "SMS marked as read at index $index: $success")
                    }
                    "clearReceivedSms" -> {
                        val success = smsManager.clearReceivedSms()
                        result.success(success)
                        Log.d(TAG, "Received SMS cleared: $success")
                    }
                    // Thêm các phương thức mới cho tùy chọn SIM
                    "setUseSpecificSim" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: throw Exception("Enabled flag is required")
                        val success = smsManager.setUseSpecificSim(enabled)
                        result.success(success)
                        Log.d(TAG, "Use specific SIM set to: $enabled, success: $success")
                    }
                    "getUseSpecificSim" -> {
                        val useSpecificSim = smsManager.getUseSpecificSim()
                        result.success(useSpecificSim)
                        Log.d(TAG, "Use specific SIM retrieved: $useSpecificSim")
                    }
                    "setSelectedSim" -> {
                        val subscriptionId = call.argument<Int>("subscriptionId") ?: throw Exception("Subscription ID is required")
                        val success = smsManager.setSelectedSim(subscriptionId)
                        result.success(success)
                        Log.d(TAG, "Selected SIM set to: $subscriptionId, success: $success")
                    }
                    "getSelectedSim" -> {
                        val selectedSim = smsManager.getSelectedSim()
                        result.success(selectedSim)
                        Log.d(TAG, "Selected SIM retrieved: $selectedSim")
                    }
                    "sendSmartSms" -> {
                        val phoneNumber = call.argument<String>("phoneNumber") ?: throw Exception("Phone number is required")
                        val message = call.argument<String>("message") ?: throw Exception("Message is required")
                        
                        if (checkSmsPermission()) {
                            val success = smsManager.sendSmartSms(phoneNumber, message)
                            result.success(success)
                            Log.d(TAG, "Smart SMS sent to: $phoneNumber, success: $success")
                        } else {
                            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                            Log.e(TAG, "Cannot send SMS: permission denied")
                        }
                    }
                    "sendSmartBulkSms" -> {
                        val phoneNumbers = call.argument<List<String>>("phoneNumbers") ?: throw Exception("Phone numbers are required")
                        val message = call.argument<String>("message") ?: throw Exception("Message is required")
                        
                        if (checkSmsPermission()) {
                            val results = smsManager.sendSmartBulkSms(phoneNumbers, message)
                            val jsonObject = JSONObject()
                            for ((number, success) in results) {
                                jsonObject.put(number, success)
                            }
                            result.success(jsonObject.toString())
                            Log.d(TAG, "Smart bulk SMS sent to ${phoneNumbers.size} numbers")
                        } else {
                            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                            Log.e(TAG, "Cannot send bulk SMS: permission denied")
                        }
                    }
                    else -> {
                        result.notImplemented()
                        Log.d(TAG, "SMS method not implemented: ${call.method}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in SMS method call: ${call.method}", e)
                result.error("SMS_ERROR", e.message, e.stackTraceToString())
            }
        }
    }
    
    // Hàm kiểm tra quyền SMS
    private fun checkSmsPermission(): Boolean {
        val sendSmsPermission = ContextCompat.checkSelfPermission(activity, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
        Log.d(TAG, "SMS permission status: $sendSmsPermission")
        return sendSmsPermission
    }
    
    // Hàm yêu cầu quyền SMS
    private fun requestSmsPermission() {
        if (!checkSmsPermission()) {
            Log.d(TAG, "Requesting SMS permission")
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.SEND_SMS),
                Constants.SMS_PERMISSION_CODE
            )
        } else {
            Log.d(TAG, "SMS permission already granted")
        }
    }
    
    // Hàm kiểm tra quyền đọc trạng thái điện thoại (cần cho getAvailableSims)
    private fun checkPhoneStatePermission(): Boolean {
        val permission = ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
        Log.d(TAG, "Phone state permission status: $permission")
        return permission
    }
    
    // Hàm yêu cầu quyền đọc trạng thái điện thoại
    private fun requestPhoneStatePermission() {
        if (!checkPhoneStatePermission()) {
            Log.d(TAG, "Requesting phone state permission")
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.READ_PHONE_STATE),
                Constants.PHONE_STATE_PERMISSION_CODE
            )
        } else {
            Log.d(TAG, "Phone state permission already granted")
        }
    }
}
