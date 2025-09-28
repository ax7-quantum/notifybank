
package com.x319.notifybank

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date

class SmsReceiver : BroadcastReceiver() {
    private val TAG = "SmsReceiver"
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            
            for (message in messages) {
                val sender = message.originatingAddress ?: "Unknown"
                val messageBody = message.messageBody
                val timestamp = message.timestampMillis
                
                Log.d(TAG, "SMS received from: $sender")
                
                // Lưu tin nhắn vào SharedPreferences
                val smsStorage = SmsStorage(context)
                smsStorage.saveIncomingSms(sender, messageBody, timestamp)
                
                // Tùy chọn: Thông báo cho các thành phần khác của ứng dụng về tin nhắn mới
                val broadcastIntent = Intent("com.x319.notifybank.SMS_RECEIVED")
                broadcastIntent.putExtra("sender", sender)
                broadcastIntent.putExtra("message", messageBody)
                broadcastIntent.putExtra("timestamp", timestamp)
                context.sendBroadcast(broadcastIntent)
            }
        }
    }
}

/**
 * Lớp quản lý lưu trữ và truy xuất tin nhắn SMS
 */
class SmsStorage(private val context: Context) {
    private val TAG = "SmsStorage"
    private val sharedPreferences: SharedPreferences = context.getSharedPreferences("sms_storage", Context.MODE_PRIVATE)
    
    // Các khóa SharedPreferences
    private val KEY_INCOMING_SMS = "incoming_sms"
    private val KEY_OUTGOING_SMS = "outgoing_sms"
    
    /**
     * Lưu tin nhắn SMS đến
     */
    fun saveIncomingSms(sender: String, message: String, timestamp: Long = System.currentTimeMillis()) {
        try {
            // Lấy danh sách tin nhắn hiện tại
            val smsJson = sharedPreferences.getString(KEY_INCOMING_SMS, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            
            // Tạo đối tượng JSON mới cho tin nhắn
            val smsObject = JSONObject().apply {
                put("sender", sender)
                put("message", message)
                put("timestamp", timestamp)
                put("isRead", false)
                put("id", generateUniqueId())
            }
            
            // Thêm vào danh sách
            smsArray.put(smsObject)
            
            // Giới hạn số lượng tin nhắn lưu trữ
            val finalArray = limitArraySize(smsArray, 200)
            
            // Lưu lại vào SharedPreferences
            sharedPreferences.edit().putString(KEY_INCOMING_SMS, finalArray.toString()).apply()
            
            Log.d(TAG, "Saved incoming SMS from $sender")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving incoming SMS: ${e.message}", e)
        }
    }
    
    /**
     * Lưu tin nhắn SMS đi
     */
    fun saveOutgoingSms(recipient: String, message: String, timestamp: Long = System.currentTimeMillis(), 
                        success: Boolean = true, errorMessage: String? = null, simId: Int = -1) {
        try {
            // Lấy danh sách tin nhắn hiện tại
            val smsJson = sharedPreferences.getString(KEY_OUTGOING_SMS, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            
            // Tạo đối tượng JSON mới cho tin nhắn
            val smsObject = JSONObject().apply {
                put("recipient", recipient)
                put("message", message)
                put("timestamp", timestamp)
                put("success", success)
                put("id", generateUniqueId())
                if (errorMessage != null) {
                    put("errorMessage", errorMessage)
                }
                if (simId != -1) {
                    put("simId", simId)
                }
            }
            
            // Thêm vào danh sách
            smsArray.put(smsObject)
            
            // Giới hạn số lượng tin nhắn lưu trữ
            val finalArray = limitArraySize(smsArray, 200)
            
            // Lưu lại vào SharedPreferences
            sharedPreferences.edit().putString(KEY_OUTGOING_SMS, finalArray.toString()).apply()
            
            Log.d(TAG, "Saved outgoing SMS to $recipient")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving outgoing SMS: ${e.message}", e)
        }
    }
    
    /**
     * Lấy danh sách tin nhắn SMS đến
     */
    fun getIncomingSms(limit: Int = 50, onlyUnread: Boolean = false): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        
        try {
            val smsJson = sharedPreferences.getString(KEY_INCOMING_SMS, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            
            // Duyệt qua danh sách tin nhắn từ mới nhất đến cũ nhất
            val startIndex = Math.max(0, smsArray.length() - limit)
            var count = 0
            
            for (i in smsArray.length() - 1 downTo startIndex) {
                if (count >= limit) break
                
                val smsObject = smsArray.getJSONObject(i)
                val isRead = smsObject.optBoolean("isRead", false)
                
                // Nếu chỉ lấy tin nhắn chưa đọc và tin nhắn này đã đọc, bỏ qua
                if (onlyUnread && isRead) continue
                
                val smsMap = mutableMapOf<String, Any>()
                val keys = smsObject.keys()
                
                while (keys.hasNext()) {
                    val key = keys.next()
                    smsMap[key] = smsObject.get(key)
                }
                
                result.add(smsMap)
                count++
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting incoming SMS: ${e.message}", e)
        }
        
        return result
    }
    
    /**
     * Lấy danh sách tin nhắn SMS đi
     */
    fun getOutgoingSms(limit: Int = 50): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        
        try {
            val smsJson = sharedPreferences.getString(KEY_OUTGOING_SMS, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            
            // Duyệt qua danh sách tin nhắn từ mới nhất đến cũ nhất
            val startIndex = Math.max(0, smsArray.length() - limit)
            
            for (i in smsArray.length() - 1 downTo startIndex) {
                val smsObject = smsArray.getJSONObject(i)
                val smsMap = mutableMapOf<String, Any>()
                val keys = smsObject.keys()
                
                while (keys.hasNext()) {
                    val key = keys.next()
                    smsMap[key] = smsObject.get(key)
                }
                
                result.add(smsMap)
                
                if (result.size >= limit) break
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting outgoing SMS: ${e.message}", e)
        }
        
        return result
    }
    
    /**
     * Đánh dấu tin nhắn đã đọc theo ID
     */
    fun markSmsAsRead(id: String): Boolean {
        try {
            val smsJson = sharedPreferences.getString(KEY_INCOMING_SMS, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            var found = false
            
            for (i in 0 until smsArray.length()) {
                val smsObject = smsArray.getJSONObject(i)
                if (smsObject.optString("id") == id) {
                    smsObject.put("isRead", true)
                    found = true
                    break
                }
            }
            
            if (found) {
                // Lưu lại vào SharedPreferences
                sharedPreferences.edit().putString(KEY_INCOMING_SMS, smsArray.toString()).apply()
                Log.d(TAG, "Marked SMS with ID $id as read")
                return true
            }
            
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Error marking SMS as read: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Đánh dấu tất cả tin nhắn đã đọc
     */
    fun markAllSmsAsRead(): Int {
        try {
            val smsJson = sharedPreferences.getString(KEY_INCOMING_SMS, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            var count = 0
            
            for (i in 0 until smsArray.length()) {
                val smsObject = smsArray.getJSONObject(i)
                if (!smsObject.optBoolean("isRead", false)) {
                    smsObject.put("isRead", true)
                    count++
                }
            }
            
            // Lưu lại vào SharedPreferences
            sharedPreferences.edit().putString(KEY_INCOMING_SMS, smsArray.toString()).apply()
            Log.d(TAG, "Marked $count SMS as read")
            
            return count
        } catch (e: Exception) {
            Log.e(TAG, "Error marking all SMS as read: ${e.message}", e)
            return 0
        }
    }
    
    /**
     * Xóa tin nhắn theo ID
     */
    fun deleteSms(id: String, isIncoming: Boolean): Boolean {
        try {
            val key = if (isIncoming) KEY_INCOMING_SMS else KEY_OUTGOING_SMS
            val smsJson = sharedPreferences.getString(key, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            val newArray = JSONArray()
            var found = false
            
            for (i in 0 until smsArray.length()) {
                val smsObject = smsArray.getJSONObject(i)
                if (smsObject.optString("id") != id) {
                    newArray.put(smsObject)
                } else {
                    found = true
                }
            }
            
            if (found) {
                // Lưu lại vào SharedPreferences
                sharedPreferences.edit().putString(key, newArray.toString()).apply()
                Log.d(TAG, "Deleted SMS with ID $id")
                return true
            }
            
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting SMS: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Xóa tất cả tin nhắn
     */
    fun deleteAllSms(isIncoming: Boolean): Int {
        try {
            val key = if (isIncoming) KEY_INCOMING_SMS else KEY_OUTGOING_SMS
            val smsJson = sharedPreferences.getString(key, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            val count = smsArray.length()
            
            // Xóa tất cả tin nhắn
            sharedPreferences.edit().putString(key, "[]").apply()
            Log.d(TAG, "Deleted $count SMS")
            
            return count
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting all SMS: ${e.message}", e)
            return 0
        }
    }
    
    /**
     * Tìm kiếm tin nhắn
     */
    fun searchSms(query: String, isIncoming: Boolean, limit: Int = 50): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        
        try {
            val key = if (isIncoming) KEY_INCOMING_SMS else KEY_OUTGOING_SMS
            val smsJson = sharedPreferences.getString(key, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            
            val queryLower = query.lowercase()
            
            for (i in smsArray.length() - 1 downTo 0) {
                if (result.size >= limit) break
                
                val smsObject = smsArray.getJSONObject(i)
                val message = smsObject.optString("message", "").lowercase()
                val contact = if (isIncoming) 
                    smsObject.optString("sender", "").lowercase() 
                else 
                    smsObject.optString("recipient", "").lowercase()
                
                if (message.contains(queryLower) || contact.contains(queryLower)) {
                    val smsMap = mutableMapOf<String, Any>()
                    val keys = smsObject.keys()
                    
                    while (keys.hasNext()) {
                        val key = keys.next()
                        smsMap[key] = smsObject.get(key)
                    }
                    
                    result.add(smsMap)
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error searching SMS: ${e.message}", e)
        }
        
        return result
    }
    
    /**
     * Đếm số tin nhắn chưa đọc
     */
    fun getUnreadCount(): Int {
        try {
            val smsJson = sharedPreferences.getString(KEY_INCOMING_SMS, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            var count = 0
            
            for (i in 0 until smsArray.length()) {
                val smsObject = smsArray.getJSONObject(i)
                if (!smsObject.optBoolean("isRead", false)) {
                    count++
                }
            }
            
            return count
        } catch (e: Exception) {
            Log.e(TAG, "Error counting unread SMS: ${e.message}", e)
            return 0
        }
    }
    
    /**
     * Đếm số tin nhắn đã gửi trong ngày hôm nay
     */
    fun getSentCountToday(): Int {
        try {
            val smsJson = sharedPreferences.getString(KEY_OUTGOING_SMS, "[]") ?: "[]"
            val smsArray = JSONArray(smsJson)
            
            // Lấy thời gian bắt đầu của ngày hôm nay (00:00:00)
            val calendar = java.util.Calendar.getInstance()
            calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
            calendar.set(java.util.Calendar.MINUTE, 0)
            calendar.set(java.util.Calendar.SECOND, 0)
            calendar.set(java.util.Calendar.MILLISECOND, 0)
            val startOfDay = calendar.timeInMillis
            
            var count = 0
            
            for (i in 0 until smsArray.length()) {
                val smsObject = smsArray.getJSONObject(i)
                val timestamp = smsObject.optLong("timestamp", 0)
                
                if (timestamp >= startOfDay) {
                    count++
                }
            }
            
            return count
        } catch (e: Exception) {
            Log.e(TAG, "Error counting today's sent SMS: ${e.message}", e)
            return 0
        }
    }
    
    /**
     * Lấy thống kê tin nhắn
     */
    fun getSmsStats(): Map<String, Int> {
        val stats = mutableMapOf<String, Int>()
        
        try {
            // Thống kê tin nhắn đến
            val incomingJson = sharedPreferences.getString(KEY_INCOMING_SMS, "[]") ?: "[]"
            val incomingArray = JSONArray(incomingJson)
            stats["totalIncoming"] = incomingArray.length()
            
            // Thống kê tin nhắn đi
            val outgoingJson = sharedPreferences.getString(KEY_OUTGOING_SMS, "[]") ?: "[]"
            val outgoingArray = JSONArray(outgoingJson)
            stats["totalOutgoing"] = outgoingArray.length()
            
            // Tin nhắn chưa đọc
            var unreadCount = 0
            for (i in 0 until incomingArray.length()) {
                val smsObject = incomingArray.getJSONObject(i)
                if (!smsObject.optBoolean("isRead", false)) {
                    unreadCount++
                }
            }
            stats["unread"] = unreadCount
            
            // Tin nhắn gửi thành công và thất bại
            var successCount = 0
            var failCount = 0
            for (i in 0 until outgoingArray.length()) {
                val smsObject = outgoingArray.getJSONObject(i)
                if (smsObject.optBoolean("success", true)) {
                    successCount++
                } else {
                    failCount++
                }
            }
            stats["sentSuccess"] = successCount
            stats["sentFailed"] = failCount
            
            // Tin nhắn gửi và nhận trong ngày hôm nay
            val calendar = java.util.Calendar.getInstance()
            calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
            calendar.set(java.util.Calendar.MINUTE, 0)
            calendar.set(java.util.Calendar.SECOND, 0)
            calendar.set(java.util.Calendar.MILLISECOND, 0)
            val startOfDay = calendar.timeInMillis
            
            var todayIncoming = 0
            var todayOutgoing = 0
            
            for (i in 0 until incomingArray.length()) {
                val smsObject = incomingArray.getJSONObject(i)
                val timestamp = smsObject.optLong("timestamp", 0)
                if (timestamp >= startOfDay) {
                    todayIncoming++
                }
            }
            
            for (i in 0 until outgoingArray.length()) {
                val smsObject = outgoingArray.getJSONObject(i)
                val timestamp = smsObject.optLong("timestamp", 0)
                if (timestamp >= startOfDay) {
                    todayOutgoing++
                }
            }
            
            stats["todayIncoming"] = todayIncoming
            stats["todayOutgoing"] = todayOutgoing
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting SMS stats: ${e.message}", e)
        }
        
        return stats
    }
    
    /**
     * Giới hạn kích thước của mảng JSON
     */
    private fun limitArraySize(array: JSONArray, maxSize: Int): JSONArray {
        if (array.length() <= maxSize) {
            return array
        }
        
        val newArray = JSONArray()
        for (i in (array.length() - maxSize) until array.length()) {
            newArray.put(array.getJSONObject(i))
        }
        
        return newArray
    }
    
    /**
     * Tạo ID duy nhất cho tin nhắn
     */
    private fun generateUniqueId(): String {
        val timestamp = System.currentTimeMillis()
        val random = (Math.random() * 1000000).toInt()
        return "$timestamp-$random"
    }
}