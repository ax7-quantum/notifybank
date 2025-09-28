
package com.x319.notifybank

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import androidx.annotation.RequiresPermission
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date

class SmsManager(private val context: Context) {
    private val TAG = "SmsManager"
    private val sharedPreferences: SharedPreferences = context.getSharedPreferences("sms_history", Context.MODE_PRIVATE)
    
    /**
     * Lấy danh sách các SIM có sẵn trên thiết bị
     * @return List<Map<String, Any>> Danh sách thông tin về các SIM
     */
    @RequiresPermission(android.Manifest.permission.READ_PHONE_STATE)
    fun getAvailableSims(): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                val activeSubscriptions = subscriptionManager.activeSubscriptionInfoList ?: return emptyList()
                
                for (subscriptionInfo in activeSubscriptions) {
                    val simInfo = mapOf(
                        "subscriptionId" to subscriptionInfo.subscriptionId,
                        "displayName" to subscriptionInfo.displayName.toString(),
                        "carrierName" to subscriptionInfo.carrierName.toString(),
                        "slotIndex" to subscriptionInfo.simSlotIndex,
                        "number" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) subscriptionInfo.number else "")
                    )
                    result.add(simInfo)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting available SIMs: ${e.message}", e)
        }
        
        return result
    }
    
    /**
     * Thiết lập chế độ sử dụng SIM cụ thể (bật/tắt)
     * @param enabled true để bật sử dụng SIM cụ thể, false để sử dụng SIM mặc định của hệ thống
     * @return Boolean Trả về true nếu thiết lập thành công
     */
    fun setUseSpecificSim(enabled: Boolean): Boolean {
        return try {
            sharedPreferences.edit().putBoolean("use_specific_sim", enabled).apply()
            Log.d(TAG, "Use specific SIM setting: $enabled")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error setting use specific SIM: ${e.message}", e)
            false
        }
    }

    /**
     * Kiểm tra xem có sử dụng SIM cụ thể không
     * @return Boolean true nếu đang sử dụng SIM cụ thể, false nếu sử dụng SIM mặc định của hệ thống
     */
    fun getUseSpecificSim(): Boolean {
        return sharedPreferences.getBoolean("use_specific_sim", false)
    }

    /**
     * Thiết lập SIM được chọn để gửi tin nhắn
     * @param subscriptionId ID của SIM được chọn
     * @return Boolean Trả về true nếu thiết lập thành công
     */
    fun setSelectedSim(subscriptionId: Int): Boolean {
        return try {
            sharedPreferences.edit().putInt("selected_sim_id", subscriptionId).apply()
            Log.d(TAG, "Selected SIM set to $subscriptionId")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error setting selected SIM: ${e.message}", e)
            false
        }
    }

    /**
     * Lấy SIM đã được chọn
     * @return Int ID của SIM đã chọn, hoặc -1 nếu chưa chọn SIM nào
     */
    fun getSelectedSim(): Int {
        return sharedPreferences.getInt("selected_sim_id", -1)
    }
    
    /**
     * Gửi tin nhắn SMS đến số điện thoại được chỉ định sử dụng SIM cụ thể
     * @param phoneNumber Số điện thoại nhận tin nhắn
     * @param message Nội dung tin nhắn
     * @param subscriptionId ID của SIM dùng để gửi tin nhắn
     * @return Boolean Trả về true nếu gửi thành công
     */
    @RequiresPermission(android.Manifest.permission.SEND_SMS)
    fun sendSmsWithSim(phoneNumber: String, message: String, subscriptionId: Int): Boolean {
        return try {
            Log.d(TAG, "Sending SMS to $phoneNumber using subscriptionId: $subscriptionId")
            
            // Lấy instance của SmsManager cho SIM cụ thể
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                android.telephony.SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
            } else {
                @Suppress("DEPRECATION")
                android.telephony.SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
            }
            
            // Kiểm tra độ dài tin nhắn
            if (message.length > 160) {
                // Nếu tin nhắn dài hơn 160 ký tự, chia thành nhiều phần
                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(
                    phoneNumber,
                    null,
                    parts,
                    null,
                    null
                )
                Log.d(TAG, "Sent multipart SMS (${parts.size} parts) to $phoneNumber using SIM $subscriptionId")
            } else {
                // Gửi tin nhắn đơn
                smsManager.sendTextMessage(
                    phoneNumber,
                    null,
                    message,
                    null,
                    null
                )
                Log.d(TAG, "Sent single SMS to $phoneNumber using SIM $subscriptionId")
            }
            
            // Lưu lịch sử gửi tin nhắn
            saveSmsHistory(phoneNumber, message, true, simId = subscriptionId)
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error sending SMS with SIM $subscriptionId: ${e.message}", e)
            
            // Lưu lịch sử gửi tin nhắn thất bại
            saveSmsHistory(phoneNumber, message, false, e.message, subscriptionId)
            
            false
        }
    }

    /**
     * Gửi tin nhắn SMS đến số điện thoại được chỉ định
     * @param phoneNumber Số điện thoại nhận tin nhắn
     * @param message Nội dung tin nhắn
     * @return Boolean Trả về true nếu gửi thành công
     */
    @RequiresPermission(android.Manifest.permission.SEND_SMS)
    fun sendSms(phoneNumber: String, message: String): Boolean {
        return try {
            Log.d(TAG, "Sending SMS to $phoneNumber")
            
            // Lấy instance của SmsManager
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(android.telephony.SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                android.telephony.SmsManager.getDefault()
            }
            
            // Kiểm tra độ dài tin nhắn
            if (message.length > 160) {
                // Nếu tin nhắn dài hơn 160 ký tự, chia thành nhiều phần
                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(
                    phoneNumber,
                    null,
                    parts,
                    null,
                    null
                )
                Log.d(TAG, "Sent multipart SMS (${parts.size} parts) to $phoneNumber")
            } else {
                // Gửi tin nhắn đơn
                smsManager.sendTextMessage(
                    phoneNumber,
                    null,
                    message,
                    null,
                    null
                )
                Log.d(TAG, "Sent single SMS to $phoneNumber")
            }
            
            // Lưu lịch sử gửi tin nhắn
            saveSmsHistory(phoneNumber, message, true)
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error sending SMS: ${e.message}", e)
            
            // Lưu lịch sử gửi tin nhắn thất bại
            saveSmsHistory(phoneNumber, message, false, e.message)
            
            false
        }
    }
    
    /**
     * Gửi tin nhắn SMS thông minh - kiểm tra cài đặt SIM
     * @param phoneNumber Số điện thoại nhận tin nhắn
     * @param message Nội dung tin nhắn
     * @return Boolean Trả về true nếu gửi thành công
     */
    @RequiresPermission(android.Manifest.permission.SEND_SMS)
    fun sendSmartSms(phoneNumber: String, message: String): Boolean {
        // Kiểm tra xem có sử dụng SIM cụ thể không
        val useSpecificSim = getUseSpecificSim()
        
        return if (useSpecificSim) {
            // Nếu có, lấy SIM đã chọn
            val selectedSim = getSelectedSim()
            if (selectedSim != -1) {
                // Nếu đã chọn SIM, sử dụng SIM đó
                Log.d(TAG, "Using selected SIM: $selectedSim")
                sendSmsWithSim(phoneNumber, message, selectedSim)
            } else {
                // Nếu chưa chọn SIM, sử dụng SIM mặc định của hệ thống
                Log.d(TAG, "No SIM selected, using system default")
                sendSms(phoneNumber, message)
            }
        } else {
            // Nếu không sử dụng SIM cụ thể, sử dụng SIM mặc định của hệ thống
            Log.d(TAG, "Using system default SIM as per settings")
            sendSms(phoneNumber, message)
        }
    }
    
    /**
     * Gửi tin nhắn SMS đến nhiều số điện thoại
     * @param phoneNumbers Danh sách số điện thoại nhận tin nhắn
     * @param message Nội dung tin nhắn
     * @return Map<String, Boolean> Kết quả gửi tin nhắn cho từng số điện thoại
     */
    @RequiresPermission(android.Manifest.permission.SEND_SMS)
    fun sendBulkSms(phoneNumbers: List<String>, message: String): Map<String, Boolean> {
        val results = mutableMapOf<String, Boolean>()
        
        for (phoneNumber in phoneNumbers) {
            val result = sendSms(phoneNumber, message)
            results[phoneNumber] = result
        }
        
        return results
    }
    
    /**
     * Gửi tin nhắn SMS đến nhiều số điện thoại sử dụng SIM cụ thể
     * @param phoneNumbers Danh sách số điện thoại nhận tin nhắn
     * @param message Nội dung tin nhắn
     * @param subscriptionId ID của SIM dùng để gửi tin nhắn
     * @return Map<String, Boolean> Kết quả gửi tin nhắn cho từng số điện thoại
     */
    @RequiresPermission(android.Manifest.permission.SEND_SMS)
    fun sendBulkSmsWithSim(phoneNumbers: List<String>, message: String, subscriptionId: Int): Map<String, Boolean> {
        val results = mutableMapOf<String, Boolean>()
        
        for (phoneNumber in phoneNumbers) {
            val result = sendSmsWithSim(phoneNumber, message, subscriptionId)
            results[phoneNumber] = result
        }
        
        return results
    }
    
    /**
     * Gửi tin nhắn SMS hàng loạt thông minh - kiểm tra cài đặt SIM
     * @param phoneNumbers Danh sách số điện thoại nhận tin nhắn
     * @param message Nội dung tin nhắn
     * @return Map<String, Boolean> Kết quả gửi tin nhắn cho từng số điện thoại
     */
    @RequiresPermission(android.Manifest.permission.SEND_SMS)
    fun sendSmartBulkSms(phoneNumbers: List<String>, message: String): Map<String, Boolean> {
        val results = mutableMapOf<String, Boolean>()
        
        for (phoneNumber in phoneNumbers) {
            val result = sendSmartSms(phoneNumber, message)
            results[phoneNumber] = result
        }
        
        return results
    }
    
    /**
     * Lưu lịch sử gửi tin nhắn vào SharedPreferences
     */
    private fun saveSmsHistory(phoneNumber: String, message: String, success: Boolean, errorMessage: String? = null, simId: Int = -1) {
        try {
            // Lấy lịch sử hiện tại
            val historyJson = sharedPreferences.getString("sms_history", "[]") ?: "[]"
            val historyArray = JSONArray(historyJson)
            
            // Tạo đối tượng JSON mới cho tin nhắn này
            val smsObject = JSONObject().apply {
                put("phoneNumber", phoneNumber)
                put("message", message)
                put("timestamp", Date().time)
                put("success", success)
                if (errorMessage != null) {
                    put("errorMessage", errorMessage)
                }
                if (simId != -1) {
                    put("simId", simId)
                }
            }
            
            // Thêm vào lịch sử
            historyArray.put(smsObject)
            
            // Giới hạn lịch sử chỉ lưu 100 tin nhắn gần nhất
            val maxHistorySize = 100
            val historySize = historyArray.length()
            val finalArray = if (historySize > maxHistorySize) {
                // Nếu lịch sử quá dài, chỉ giữ lại 100 tin nhắn gần nhất
                val newArray = JSONArray()
                for (i in (historySize - maxHistorySize) until historySize) {
                    newArray.put(historyArray.getJSONObject(i))
                }
                newArray
            } else {
                historyArray
            }
            
            // Lưu lại vào SharedPreferences
            sharedPreferences.edit().putString("sms_history", finalArray.toString()).apply()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error saving SMS history: ${e.message}", e)
        }
    }
    
    /**
     * Lấy lịch sử gửi tin nhắn SMS
     * @param limit Số lượng tin nhắn tối đa muốn lấy (mặc định là 50)
     * @return String Chuỗi JSON chứa lịch sử tin nhắn
     */
    fun getSmsHistory(limit: Int = 50): String {
        try {
            val historyJson = sharedPreferences.getString("sms_history", "[]") ?: "[]"
            val historyArray = JSONArray(historyJson)
            
            // Giới hạn số lượng tin nhắn trả về
            val resultArray = JSONArray()
            val startIndex = Math.max(0, historyArray.length() - limit)
            
            for (i in startIndex until historyArray.length()) {
                resultArray.put(historyArray.getJSONObject(i))
            }
            
            return resultArray.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting SMS history: ${e.message}", e)
            return "[]"
        }
    }
    
    /**
     * Xóa lịch sử gửi tin nhắn SMS
     * @return Boolean Trả về true nếu xóa thành công
     */
    fun clearSmsHistory(): Boolean {
        return try {
            sharedPreferences.edit().putString("sms_history", "[]").apply()
            Log.d(TAG, "SMS history cleared")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing SMS history: ${e.message}", e)
            false
        }
    }
    
    /**
     * Lấy số lượng tin nhắn đã gửi trong ngày hôm nay
     * @return Int Số lượng tin nhắn đã gửi trong ngày
     */
    fun getSmsCountToday(): Int {
        try {
            val historyJson = sharedPreferences.getString("sms_history", "[]") ?: "[]"
            val historyArray = JSONArray(historyJson)
            
            // Lấy thời gian bắt đầu của ngày hôm nay (00:00:00)
            val calendar = java.util.Calendar.getInstance()
            calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
            calendar.set(java.util.Calendar.MINUTE, 0)
            calendar.set(java.util.Calendar.SECOND, 0)
            calendar.set(java.util.Calendar.MILLISECOND, 0)
            val startOfDay = calendar.timeInMillis
            
            // Đếm số tin nhắn gửi trong ngày
            var count = 0
            for (i in 0 until historyArray.length()) {
                val smsObject = historyArray.getJSONObject(i)
                val timestamp = smsObject.getLong("timestamp")
                if (timestamp >= startOfDay) {
                    count++
                }
            }
            
            return count
        } catch (e: Exception) {
            Log.e(TAG, "Error counting today's SMS: ${e.message}", e)
            return 0
        }
    }
    
    /**
     * Kiểm tra xem có thể gửi thêm tin nhắn không (giới hạn số lượng tin nhắn mỗi ngày)
     * @param dailyLimit Giới hạn số tin nhắn mỗi ngày (mặc định là 100)
     * @return Boolean Trả về true nếu có thể gửi thêm tin nhắn
     */
    fun canSendMoreSms(dailyLimit: Int = 100): Boolean {
        val todayCount = getSmsCountToday()
        return todayCount < dailyLimit
    }
    
    /**
     * Lưu tin nhắn SMS nhận được
     * @param sender Số điện thoại người gửi
     * @param message Nội dung tin nhắn
     * @param timestamp Thời gian nhận tin nhắn
     */
    fun saveReceivedSms(sender: String, message: String, timestamp: Long = System.currentTimeMillis()) {
        try {
            // Lấy danh sách tin nhắn đã nhận
            val receivedJson = sharedPreferences.getString("received_sms", "[]") ?: "[]"
            val receivedArray = JSONArray(receivedJson)
            
            // Tạo đối tượng JSON mới cho tin nhắn này
            val smsObject = JSONObject().apply {
                put("sender", sender)
                put("message", message)
                put("timestamp", timestamp)
                put("isRead", false)
            }
            
            // Thêm vào danh sách
            receivedArray.put(smsObject)
            
            // Giới hạn chỉ lưu 100 tin nhắn gần nhất
            val maxSize = 100
            val size = receivedArray.length()
            val finalArray = if (size > maxSize) {
                val newArray = JSONArray()
                for (i in (size - maxSize) until size) {
                    newArray.put(receivedArray.getJSONObject(i))
                }
                newArray
            } else {
                receivedArray
            }
            
            // Lưu lại vào SharedPreferences
            sharedPreferences.edit().putString("received_sms", finalArray.toString()).apply()
            
            Log.d(TAG, "Received SMS saved from $sender")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving received SMS: ${e.message}", e)
        }
    }
    
    /**
     * Lấy danh sách tin nhắn SMS đã nhận
     * @param limit Số lượng tin nhắn tối đa muốn lấy (mặc định là 50)
     * @return String Chuỗi JSON chứa danh sách tin nhắn đã nhận
     */
    fun getReceivedSms(limit: Int = 50): String {
        try {
            val receivedJson = sharedPreferences.getString("received_sms", "[]") ?: "[]"
            val receivedArray = JSONArray(receivedJson)
            
            // Giới hạn số lượng tin nhắn trả về
            val resultArray = JSONArray()
            val startIndex = Math.max(0, receivedArray.length() - limit)
            
            for (i in startIndex until receivedArray.length()) {
                resultArray.put(receivedArray.getJSONObject(i))
            }
            
            return resultArray.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting received SMS: ${e.message}", e)
            return "[]"
        }
    }
    
    /**
     * Đánh dấu tin nhắn đã đọc
     * @param index Vị trí của tin nhắn trong danh sách
     * @return Boolean Trả về true nếu đánh dấu thành công
     */
    fun markSmsAsRead(index: Int): Boolean {
        try {
            val receivedJson = sharedPreferences.getString("received_sms", "[]") ?: "[]"
            val receivedArray = JSONArray(receivedJson)
            
            if (index >= 0 && index < receivedArray.length()) {
                val smsObject = receivedArray.getJSONObject(index)
                smsObject.put("isRead", true)
                
                // Lưu lại vào SharedPreferences
                sharedPreferences.edit().putString("received_sms", receivedArray.toString()).apply()
                return true
            }
            
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Error marking SMS as read: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Xóa tin nhắn đã nhận
     * @return Boolean Trả về true nếu xóa thành công
     */
    fun clearReceivedSms(): Boolean {
        return try {
            sharedPreferences.edit().putString("received_sms", "[]").apply()
            Log.d(TAG, "Received SMS history cleared")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing received SMS history: ${e.message}", e)
            false
        }
    }
}
