
package com.x319.notifybank

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class MyNotificationListenerService : NotificationListenerService() {
    private lateinit var sharedPreferences: SharedPreferences
    private val FOREGROUND_NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "notification_listener_channel"
    private lateinit var wakeLock: PowerManager.WakeLock
    
    // Đăng ký xử lý thông báo ngân hàng
    private lateinit var bankNotificationRegistry: BankNotificationRegistry
    
    // Quản lý luồng xử lý
    private lateinit var appSettings: AppSettings
    private lateinit var executorService: ExecutorService
    private val activeProcesses = AtomicInteger(0)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cleanupRunnable = Runnable { cleanupOldNotifications() }
    
    override fun onCreate() {
        try {
            super.onCreate()
            sharedPreferences = applicationContext.getSharedPreferences("notification_prefs", Context.MODE_PRIVATE)
            
            // Khởi tạo AppSettings và lấy số luồng
            appSettings = AppSettings.getInstance(applicationContext)
            appSettings.initializeDefaultSettings()
            initializeThreadPool()
            
            // Khởi tạo đăng ký xử lý thông báo ngân hàng
            bankNotificationRegistry = BankNotificationRegistry(applicationContext)
            
            // Đánh dấu service đã được khởi tạo
            sharedPreferences.edit().putBoolean("service_started", true).apply()
            
            // Tạo WakeLock để giữ CPU hoạt động
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ThongBao:NotificationServiceWakeLock"
            )
            
            // Chỉ giữ WakeLock trong thời gian ngắn để khởi tạo service
            wakeLock.acquire(1*60*1000L /*1 phút*/)
            
            // Khởi tạo Foreground Service ngay lập tức
            startForegroundService()
            
            // Lên lịch xóa thông báo cũ định kỳ mỗi 1 giờ
            scheduleCleanup()
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    private fun initializeThreadPool() {
        try {
            val threadCount = appSettings.getNotificationThreads()
            
            // Nếu đã có executorService, kiểm tra trạng thái và tắt nếu cần
            if (::executorService.isInitialized && !executorService.isShutdown) {
                executorService.shutdown()
                try {
                    // Chờ tối đa 5 giây để các tác vụ hiện tại hoàn thành
                    if (!executorService.awaitTermination(5, TimeUnit.SECONDS)) {
                        executorService.shutdownNow()
                    }
                } catch (e: InterruptedException) {
                    executorService.shutdownNow()
                }
            }
            
            // Tạo ExecutorService mới với số luồng từ cài đặt
            executorService = Executors.newFixedThreadPool(threadCount)
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    private fun scheduleCleanup() {
        // Hủy bỏ lịch cũ nếu có
        mainHandler.removeCallbacks(cleanupRunnable)
        
        // Lên lịch mới để xóa thông báo cũ mỗi 1 giờ
        mainHandler.postDelayed(cleanupRunnable, 60 * 60 * 1000) // 1 giờ
    }
    
    private fun cleanupOldNotifications() {
        try {
            // Xóa toàn bộ thông báo đã lưu
            sharedPreferences.edit().putString("saved_notifications", "[]").apply()
            
            // Lên lịch cho lần xóa tiếp theo
            scheduleCleanup()
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            // Đảm bảo service vẫn chạy ở foreground
            startForegroundService()
            
            // Nếu service bị kill, hệ thống sẽ cố gắng khởi động lại nó
            return START_STICKY
        } catch (e: Exception) {
            return START_NOT_STICKY
        }
    }
    
    private fun startForegroundService() {
        try {
            createNotificationChannel()
            
            val notificationIntent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this, 0, notificationIntent, 
                PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Dịch vụ thông báo đang chạy")
                .setContentText("Đang theo dõi thông báo...")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
            
            startForeground(FOREGROUND_NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    private fun createNotificationChannel() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val serviceChannel = NotificationChannel(
                    CHANNEL_ID,
                    "Notification Listener Service Channel",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Kênh thông báo cho dịch vụ theo dõi thông báo"
                    setShowBadge(false)
                }
                
                val manager = getSystemService(NotificationManager::class.java)
                manager.createNotificationChannel(serviceChannel)
            }
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    override fun onListenerConnected() {
        try {
            super.onListenerConnected()
            
            // Đảm bảo service vẫn chạy ở foreground
            startForegroundService()
            
            // Kiểm tra và xử lý đặc biệt cho thiết bị Xiaomi
            if (Build.MANUFACTURER.lowercase().contains("xiaomi")) {
                // Đảm bảo service vẫn chạy ở foreground
                startForegroundService()
            }
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    override fun onListenerDisconnected() {
        try {
            super.onListenerDisconnected()
            // Khi bị ngắt kết nối, thử kết nối lại
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                requestRebind(ComponentName(this, MyNotificationListenerService::class.java))
            }
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        try {
            if (sbn == null) {
                return
            }
            
            // Bỏ qua các thông báo hệ thống
            if (sbn.packageName.startsWith("android") || 
                sbn.packageName == "com.android.systemui" ||
                sbn.packageName == applicationContext.packageName) {
                return
            }
            
            // Kiểm tra và khởi tạo lại thread pool nếu cần
            checkAndReinitializeThreadPoolIfNeeded()
            
            // Xử lý thông báo trong một luồng riêng
            executorService.submit {
                try {
                    // Tăng số tiến trình đang hoạt động
                    val currentProcesses = activeProcesses.incrementAndGet()
                    
                    // Xử lý thông báo từ các ngân hàng/ví điện tử
                    bankNotificationRegistry.handleBankNotification(sbn)
                    
                    // Kiểm tra xem có lưu thông báo hay không
                    if (appSettings.isSaveNotificationsEnabled()) {
                        // Tiếp tục xử lý thông báo thông thường
                        processGeneralNotification(sbn)
                    }
                    
                } catch (e: Exception) {
                    // Xử lý lỗi
                } finally {
                    // Giảm số tiến trình đang hoạt động
                    activeProcesses.decrementAndGet()
                }
            }
            
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    private fun checkAndReinitializeThreadPoolIfNeeded() {
        try {
            val configuredThreads = appSettings.getNotificationThreads()
            
            // Kiểm tra xem executorService có tồn tại và không bị shutdown
            val needsReinitialize = !::executorService.isInitialized || 
                                   executorService.isShutdown || 
                                   executorService.isTerminated
            
            if (needsReinitialize) {
                initializeThreadPool()
            }
            
            // Kiểm tra xem số tiến trình hiện tại có vượt quá giới hạn không
            val currentActive = activeProcesses.get()
            if (currentActive > configuredThreads) {
                // Không cần làm gì, chỉ để ý theo dõi
                // Các tiến trình đang chạy sẽ tự kết thúc
            }
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    // Xử lý thông báo thông thường
    private fun processGeneralNotification(sbn: StatusBarNotification) {
        try {
            // Kiểm tra xem có được phép lưu thông báo không
            if (!appSettings.isSaveNotificationsEnabled()) {
                return
            }
            
            val notification = sbn.notification ?: return
            val extras = notification.extras ?: return
            
            // Tạo đối tượng JSON chính cho thông báo
            val notificationJson = JSONObject().apply {
                // Thông tin cơ bản của StatusBarNotification
                put("id", sbn.id)
                put("packageName", sbn.packageName)
                put("postTime", sbn.postTime)
                put("formattedTime", SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(sbn.postTime)))
                put("key", sbn.key)
                put("tag", sbn.tag ?: JSONObject.NULL)
                put("isOngoing", sbn.isOngoing)
                put("isClearable", sbn.isClearable)
                
                // Thông tin từ đối tượng Notification
                put("flags", notification.flags)
                put("category", notification.category ?: JSONObject.NULL)
                put("priority", notification.priority)
                put("visibility", notification.visibility)
                put("when", notification.`when`)
                put("number", notification.number)
                put("color", notification.color)
                put("isGroupSummary", ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0))
                
                // Lưu trữ toàn bộ thông tin từ extras
                val extrasJson = bundleToJson(extras)
                put("extras", extrasJson)
                
                // Lưu trữ thông tin về các hành động
                if (notification.actions != null && notification.actions.isNotEmpty()) {
                    val actionsArray = JSONArray()
                    for (action in notification.actions) {
                        val actionJson = JSONObject()
                        actionJson.put("title", action.title?.toString() ?: JSONObject.NULL)
                        actionJson.put("actionIntent", action.actionIntent != null)
                        actionJson.put("remoteInputs", action.remoteInputs != null)
                        actionsArray.put(actionJson)
                    }
                    put("actions", actionsArray)
                } else {
                    put("actions", JSONObject.NULL)
                }
                
                // Lưu thông tin về người gửi (nếu có)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && notification.bubbleMetadata != null) {
                    put("hasBubbleMetadata", true)
                } else {
                    put("hasBubbleMetadata", false)
                }
                
                // Lưu thông tin về kiểu thông báo
                val style = getNotificationStyle(notification)
                if (style != null) {
                    put("style", style)
                }
                
                // Thêm thông tin về các trường phổ biến cho dễ truy cập
                put("title", extras.getString(Notification.EXTRA_TITLE) ?: "")
                put("text", extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: "")
                put("subText", extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: JSONObject.NULL)
                put("summaryText", extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString() ?: JSONObject.NULL)
                
                // Thêm thông tin về loại thông báo
                val notificationType = when {
                    ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) -> "group_summary"
                    extras.containsKey(Notification.EXTRA_MEDIA_SESSION) -> "media"
                    extras.containsKey(Notification.EXTRA_MESSAGES) -> "messaging"
                    extras.containsKey(Notification.EXTRA_BIG_TEXT) -> "big_text"
                    extras.containsKey(Notification.EXTRA_PICTURE) -> "big_picture"
                    else -> "standard"
                }
                put("notificationType", notificationType)
            }
            
            // Lấy mảng thông báo hiện có và thêm thông báo mới
            synchronized(this) {
                val savedNotificationsString = sharedPreferences.getString("saved_notifications", "[]") ?: "[]"
                val savedNotifications = JSONArray(savedNotificationsString)
                
                // Thêm thông báo mới vào đầu mảng
                val updatedNotifications = JSONArray()
                updatedNotifications.put(notificationJson)
                
                // Thêm các thông báo cũ (giới hạn số lượng lưu trữ là 100)
                val maxNotifications = 100
                for (i in 0 until minOf(savedNotifications.length(), maxNotifications - 1)) {
                    updatedNotifications.put(savedNotifications.get(i))
                }
                
                // Lưu mảng thông báo mới vào SharedPreferences
                sharedPreferences.edit().putString("saved_notifications", updatedNotifications.toString()).apply()
            }
            
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    // Hàm chuyển đổi Bundle thành JSON
    private fun bundleToJson(bundle: Bundle): JSONObject {
        val json = JSONObject()
        
        for (key in bundle.keySet()) {
            try {
                val value = bundle.get(key)
                when (value) {
                    null -> json.put(key, JSONObject.NULL)
                    is Bundle -> json.put(key, bundleToJson(value))
                    is CharSequence -> json.put(key, value.toString())
                    is Boolean, is Int, is Long, is Float, is Double -> json.put(key, value)
                    is Array<*> -> {
                        val jsonArray = JSONArray()
                        for (item in value) {
                            if (item is Bundle) {
                                jsonArray.put(bundleToJson(item))
                            } else if (item != null) {
                                jsonArray.put(item.toString())
                            } else {
                                jsonArray.put(JSONObject.NULL)
                            }
                        }
                        json.put(key, jsonArray)
                    }
                    else -> json.put(key, value.toString())
                }
            } catch (e: Exception) {
                json.put(key, "Error: ${e.message}")
            }
        }
        
        return json
    }
    
    // Hàm xác định kiểu thông báo
    private fun getNotificationStyle(notification: Notification): String? {
        val extras = notification.extras
        return when {
            extras.containsKey(Notification.EXTRA_BIG_TEXT) -> "BigTextStyle"
            extras.containsKey(Notification.EXTRA_PICTURE) -> "BigPictureStyle"
            extras.containsKey(Notification.EXTRA_MESSAGES) -> "MessagingStyle"
            extras.containsKey(Notification.EXTRA_MEDIA_SESSION) -> "MediaStyle"
            ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) -> "InboxStyle"
            else -> null
        }
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        try {
            if (sbn == null) {
                return
            }
            
            // Kiểm tra xem có được phép lưu thông báo không
            if (!appSettings.isSaveNotificationsEnabled()) {
                return
            }
            
            // Nếu bạn muốn lưu thông tin về thông báo bị xóa, có thể thêm code ở đây
            // Tương tự như onNotificationPosted nhưng thêm trường "removed": true
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    // Phương thức để cập nhật số luồng khi cài đặt thay đổi
    fun updateThreadPool() {
        try {
            initializeThreadPool()
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    override fun onDestroy() {
        try {
            super.onDestroy()
            
            // Hủy bỏ lịch xóa thông báo
            mainHandler.removeCallbacks(cleanupRunnable)
            
            // Giải phóng WakeLock nếu đang giữ
            if (::wakeLock.isInitialized && wakeLock.isHeld) {
                wakeLock.release()
            }
            
            // Tắt ExecutorService
            if (::executorService.isInitialized && !executorService.isShutdown) {
                executorService.shutdown()
                try {
                    // Chờ tối đa 5 giây để các tác vụ hiện tại hoàn thành
                    if (!executorService.awaitTermination(5, TimeUnit.SECONDS)) {
                        executorService.shutdownNow()
                    }
                } catch (e: InterruptedException) {
                    executorService.shutdownNow()
                }
            }
            
            // Thử khởi động lại service
            val intent = Intent(applicationContext, MyNotificationListenerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(intent)
            } else {
                applicationContext.startService(intent)
            }
        } catch (e: Exception) {
            // Xử lý lỗi
        }
    }
    
    // Phương thức để kiểm tra xem service có quyền lắng nghe thông báo không
    private fun isNotificationServiceEnabled(): Boolean {
        try {
            val cn = ComponentName(this, MyNotificationListenerService::class.java)
            val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            val isEnabled = flat != null && flat.contains(cn.flattenToString())
            return isEnabled
        } catch (e: Exception) {
            return false
        }
    }
}
