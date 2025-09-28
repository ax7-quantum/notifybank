package com.x319.notifybank

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import com.x319.notifybank.channels.AppInfoChannel
import com.x319.notifybank.channels.AppSettingsChannel
import com.x319.notifybank.channels.BankApiChannel
import com.x319.notifybank.channels.ContactsChannel
import com.x319.notifybank.channels.NotificationChannel
import com.x319.notifybank.channels.SmsChannel
import com.x319.notifybank.channels.SmsReceiverChannel
import com.x319.notifybank.config.BankApiConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var sharedPreferences: SharedPreferences
    private lateinit var cakeSharedPreferences: SharedPreferences
    private lateinit var mbSharedPreferences: SharedPreferences
    private lateinit var appInfoPreferences: SharedPreferences
    private lateinit var bankApiConfig: BankApiConfig
    private lateinit var smsManager: SmsManager
    private lateinit var contactsManager: ContactsManager
    private lateinit var appSettings: AppSettings
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        sharedPreferences = getSharedPreferences("notification_prefs", Context.MODE_PRIVATE)
        cakeSharedPreferences = getSharedPreferences("cake_transactions", Context.MODE_PRIVATE)
        mbSharedPreferences = getSharedPreferences("mb_transactions", Context.MODE_PRIVATE)
        appInfoPreferences = getSharedPreferences("app_info_prefs", Context.MODE_PRIVATE)
        bankApiConfig = BankApiConfig(this)
        smsManager = SmsManager(this)
        contactsManager = ContactsManager(this)
        appSettings = AppSettings.getInstance(this)
        appSettings.initializeDefaultSettings()
        Log.d(TAG, "MainActivity initialized")
        
        // Khởi tạo các channel
        AppSettingsChannel(flutterEngine, appSettings).setup()
        NotificationChannel(flutterEngine, this, sharedPreferences, cakeSharedPreferences, mbSharedPreferences).setup()
        BankApiChannel(flutterEngine, bankApiConfig, this).setup()
        SmsChannel(flutterEngine, this, smsManager).setup()
        
        // Khởi tạo channel mới để quản lý việc nhận tin nhắn
        SmsReceiverChannel(flutterEngine, this).setup()
        
        // Khởi tạo channel mới để quản lý thông tin ứng dụng và kiểm tra lần đầu sử dụng
        AppInfoChannel(flutterEngine, this, appInfoPreferences).setup()
        
        // Khởi tạo channel mới để quản lý danh bạ
        ContactsChannel(flutterEngine, this, contactsManager).setup()
    }
    
    // Mở cài đặt thông tin ứng dụng
    fun openAppInfo() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
            Log.d(TAG, "Đã mở cài đặt thông tin ứng dụng")
        } catch (e: Exception) {
            Log.e(TAG, "Không thể mở cài đặt thông tin ứng dụng", e)
        }
    }
    
    // Kiểm tra xem ứng dụng có phải lần đầu mở không
    fun isFirstLaunch(): Boolean {
        val isFirstLaunch = appInfoPreferences.getBoolean("is_first_launch", true)
        if (isFirstLaunch) {
            // Đánh dấu là đã mở ứng dụng
            appInfoPreferences.edit().putBoolean("is_first_launch", false).apply()
            Log.d(TAG, "Đây là lần đầu mở ứng dụng")
        }
        return isFirstLaunch
    }
    
    // Kiểm tra xem có quyền nào được cấp chưa
    fun hasAnyPermission(): Boolean {
        val hasNotificationPermission = isNotificationServiceEnabled()
        val hasSmsPermission = checkSmsPermission()
        val hasContactsPermission = checkContactsPermission()
        return hasNotificationPermission || hasSmsPermission || hasContactsPermission
    }
    
    // Kiểm tra quyền SMS
    fun checkSmsPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val readSmsPermission = checkSelfPermission(android.Manifest.permission.READ_SMS)
            val receiveSmsPermission = checkSelfPermission(android.Manifest.permission.RECEIVE_SMS)
            return readSmsPermission == PackageManager.PERMISSION_GRANTED || 
                   receiveSmsPermission == PackageManager.PERMISSION_GRANTED
        }
        return true
    }
    
    // Kiểm tra quyền danh bạ
    fun checkContactsPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val readContactsPermission = checkSelfPermission(android.Manifest.permission.READ_CONTACTS)
            val writeContactsPermission = checkSelfPermission(android.Manifest.permission.WRITE_CONTACTS)
            return readContactsPermission == PackageManager.PERMISSION_GRANTED && 
                   writeContactsPermission == PackageManager.PERMISSION_GRANTED
        }
        return true
    }
    
    // Kiểm tra xem có nên hiển thị hộp thoại giới thiệu không
    fun shouldShowIntroDialog(): Boolean {
        val isFirstLaunch = isFirstLaunch()
        val hasPermissions = hasAnyPermission()
        val hasShownDialog = appInfoPreferences.getBoolean("has_shown_intro_dialog", false)
        
        val shouldShow = (isFirstLaunch || !hasPermissions) && !hasShownDialog
        
        if (shouldShow) {
            Log.d(TAG, "Nên hiển thị hộp thoại giới thiệu")
        } else {
            Log.d(TAG, "Không cần hiển thị hộp thoại giới thiệu")
        }
        
        return shouldShow
    }
    
    // Đánh dấu đã hiển thị hộp thoại giới thiệu
    fun markIntroDialogShown() {
        appInfoPreferences.edit().putBoolean("has_shown_intro_dialog", true).apply()
        Log.d(TAG, "Đã đánh dấu hộp thoại giới thiệu đã hiển thị")
    }
    
    // Kiểm tra trạng thái tối ưu hóa pin
    fun checkBatteryOptimizationStatus(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
            Log.d(TAG, "Battery optimization status: $isIgnoring")
            return isIgnoring
        }
        return true
    }
    
    // Yêu cầu tắt tối ưu hóa pin cho ứng dụng
    fun requestBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent().apply {
                action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                data = Uri.parse("package:$packageName")
            }
            
            try {
                Log.d(TAG, "Opening battery optimization settings")
                startActivityForResult(intent, Constants.BATTERY_OPTIMIZATION_CODE)
            } catch (e: Exception) {
                Log.e(TAG, "Không thể mở cài đặt tối ưu hóa pin", e)
            }
        }
    }
    
    // Kiểm tra nhà sản xuất thiết bị
    fun getDeviceManufacturer(): String {
        return Build.MANUFACTURER.lowercase()
    }

    // Kiểm tra xem thiết bị có cần cài đặt autostart không
    fun needsAutoStartPermission(): Boolean {
        val manufacturer = getDeviceManufacturer()
        return manufacturer.contains("xiaomi") || 
               manufacturer.contains("oppo") || 
               manufacturer.contains("vivo") || 
               manufacturer.contains("letv") || 
               manufacturer.contains("honor") ||
               manufacturer.contains("huawei")
    }

    // Mở cài đặt tự động khởi động dựa trên nhà sản xuất
    fun openAutoStartSettings() {
        try {
            val manufacturer = getDeviceManufacturer()
            val intent = Intent()
            
            when {
                manufacturer.contains("xiaomi") -> {
                    intent.component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                }
                manufacturer.contains("oppo") -> {
                    intent.component = ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                    )
                }
                manufacturer.contains("vivo") -> {
                    intent.component = ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                    )
                }
                manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                    intent.component = ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.optimize.process.ProtectActivity"
                    )
                }
                else -> {
                    Log.d(TAG, "Không có cài đặt autostart cụ thể cho nhà sản xuất: $manufacturer")
                    // Mở cài đặt ứng dụng thông thường
                    val appIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    appIntent.data = Uri.parse("package:$packageName")
                    startActivityForResult(appIntent, Constants.AUTOSTART_SETTINGS_CODE)
                    return
                }
            }
            
            Log.d(TAG, "Mở cài đặt autostart cho: $manufacturer")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivityForResult(intent, Constants.AUTOSTART_SETTINGS_CODE)
        } catch (e: Exception) {
            Log.e(TAG, "Không thể mở cài đặt autostart", e)
            // Nếu không mở được cài đặt cụ thể, thử mở cài đặt ứng dụng
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivityForResult(intent, Constants.AUTOSTART_SETTINGS_CODE)
            } catch (e2: Exception) {
                Log.e(TAG, "Không thể mở cài đặt ứng dụng", e2)
            }
        }
    }
    
    // Kiểm tra quyền thông báo
    fun isNotificationServiceEnabled(): Boolean {
        val cn = ComponentName(this, MyNotificationListenerService::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        val isEnabled = flat != null && flat.contains(cn.flattenToString())
        Log.d(TAG, "Notification service enabled: $isEnabled, enabled services: $flat")
        return isEnabled
    }
    
    // Yêu cầu quyền thông báo
    fun requestNotificationPermission() {
        if (!isNotificationServiceEnabled()) {
            Log.d(TAG, "Opening notification listener settings")
            startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
        } else {
            Log.d(TAG, "Notification permission already granted")
        }
    }
    
    // Phương thức khởi động lại service
    fun restartNotificationService() {
        if (isNotificationServiceEnabled()) {
            try {
                Log.d(TAG, "Attempting to restart notification service")
                
                // Tạo intent để khởi động lại service
                val intent = Intent(this, MyNotificationListenerService::class.java)
                stopService(intent)
                
                // Khởi động lại service
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                
                Log.d(TAG, "Service restart attempted")
            } catch (e: Exception) {
                Log.e(TAG, "Error restarting notification service", e)
                
                // Yêu cầu người dùng tắt và bật lại quyền thông báo
                val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                startActivity(intent)
            }
        } else {
            Log.d(TAG, "Cannot restart service, permission not granted")
            requestNotificationPermission()
        }
    }
    
    // Phương thức mới để kiểm tra xem dịch vụ đã được khởi động chưa
    fun isServiceRunning(): Boolean {
        // Kiểm tra quyền đã được cấp
        val isPermissionGranted = isNotificationServiceEnabled()
        
        // Nếu quyền chưa được cấp, dịch vụ chắc chắn không chạy
        if (!isPermissionGranted) {
            Log.d(TAG, "Service not running: permission not granted")
            return false
        }
        
        // Kiểm tra xem dịch vụ có dữ liệu trong SharedPreferences không
        // Đây là cách gián tiếp để kiểm tra dịch vụ đã hoạt động
        val hasData = sharedPreferences.contains("service_started")
        
        // Nếu dịch vụ đã khởi động, thử khởi động lại để đảm bảo nó hoạt động
        if (!hasData) {
            Log.d(TAG, "Service may not be running, attempting to start it")
            val intent = Intent(this, MyNotificationListenerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            // Đánh dấu dịch vụ đã được khởi động
            sharedPreferences.edit().putBoolean("service_started", true).apply()
        }
        
        Log.d(TAG, "Service running status: $hasData")
        return true
    }
    
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        when (requestCode) {
            Constants.SMS_PERMISSION_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d(TAG, "SMS permission granted")
                } else {
                    Log.d(TAG, "SMS permission denied")
                }
            }
            Constants.PHONE_STATE_PERMISSION_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d(TAG, "PHONE_STATE permission granted")
                } else {
                    Log.d(TAG, "PHONE_STATE permission denied")
                }
            }
            Constants.READ_SMS_PERMISSION_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d(TAG, "READ_SMS permission granted")
                } else {
                    Log.d(TAG, "READ_SMS permission denied")
                }
            }
            Constants.RECEIVE_SMS_PERMISSION_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d(TAG, "RECEIVE_SMS permission granted")
                } else {
                    Log.d(TAG, "RECEIVE_SMS permission denied")
                }
            }
            Constants.CONTACTS_PERMISSION_CODE -> {
                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    Log.d(TAG, "CONTACTS permissions granted")
                } else {
                    Log.d(TAG, "CONTACTS permissions denied")
                }
            }
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        when (requestCode) {
            Constants.BATTERY_OPTIMIZATION_CODE -> {
                val isIgnoring = checkBatteryOptimizationStatus()
                Log.d(TAG, if (isIgnoring) "Đã tắt tối ưu hóa pin" else "Tối ưu hóa pin vẫn bật")
            }
            Constants.AUTOSTART_SETTINGS_CODE -> {
                Log.d(TAG, "Đã quay lại từ cài đặt tự động khởi động")
                // Không có cách nào để kiểm tra trạng thái autostart vì nó phụ thuộc vào nhà sản xuất
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "MainActivity resumed")
        // Kiểm tra trạng thái service khi activity được resume
        val isEnabled = isNotificationServiceEnabled()
        Log.d(TAG, "Notification service status on resume: $isEnabled")
        
        // Thử khởi động service nếu quyền đã được cấp
        if (isEnabled) {
            isServiceRunning()
        }
    }
}
