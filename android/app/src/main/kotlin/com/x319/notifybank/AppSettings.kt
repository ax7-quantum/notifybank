package com.x319.notifybank

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.core.content.edit

/**
 * Lớp quản lý cài đặt ứng dụng, bao gồm cài đặt luồng xử lý thông báo
 */
class AppSettings private constructor(context: Context) {
    private val TAG = "AppSettings"
    private val PREFS_NAME = "app_settings"
    private val KEY_NOTIFICATION_THREADS = "notification_threads"
    private val KEY_SAVE_NOTIFICATIONS = "save_notifications"
    private val DEFAULT_THREADS = 8
    private val MAX_THREADS = 32
    private val MIN_THREADS = 1
    private val DEFAULT_SAVE_NOTIFICATIONS = true

    private val sharedPreferences: SharedPreferences = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        @Volatile
        private var instance: AppSettings? = null

        fun getInstance(context: Context): AppSettings {
            return instance ?: synchronized(this) {
                instance ?: AppSettings(context).also { instance = it }
            }
        }
    }

    /**
     * Khởi tạo cài đặt mặc định nếu chưa tồn tại
     */
    fun initializeDefaultSettings() {
        if (!sharedPreferences.contains(KEY_NOTIFICATION_THREADS)) {
            setNotificationThreads(DEFAULT_THREADS)
            Log.d(TAG, "Initialized default settings: $DEFAULT_THREADS threads")
        }
        
        if (!sharedPreferences.contains(KEY_SAVE_NOTIFICATIONS)) {
            setSaveNotifications(DEFAULT_SAVE_NOTIFICATIONS)
            Log.d(TAG, "Initialized save notifications setting: $DEFAULT_SAVE_NOTIFICATIONS")
        }
    }

    /**
     * Lấy số luồng xử lý thông báo
     * @return Số luồng xử lý thông báo hiện tại
     */
    fun getNotificationThreads(): Int {
        return sharedPreferences.getInt(KEY_NOTIFICATION_THREADS, DEFAULT_THREADS)
    }

    /**
     * Đặt số luồng xử lý thông báo
     * @param threads Số luồng mới (sẽ được giới hạn trong khoảng MIN_THREADS đến MAX_THREADS)
     * @return Số luồng thực tế được đặt sau khi kiểm tra giới hạn
     */
    fun setNotificationThreads(threads: Int): Int {
        val validThreads = when {
            threads < MIN_THREADS -> MIN_THREADS
            threads > MAX_THREADS -> MAX_THREADS
            else -> threads
        }
        
        sharedPreferences.edit {
            putInt(KEY_NOTIFICATION_THREADS, validThreads)
        }
        
        Log.d(TAG, "Set notification threads to: $validThreads")
        return validThreads
    }

    /**
     * Tăng số luồng xử lý thông báo
     * @return Số luồng mới sau khi tăng
     */
    fun increaseThreads(): Int {
        val currentThreads = getNotificationThreads()
        return if (currentThreads < MAX_THREADS) {
            setNotificationThreads(currentThreads + 1)
        } else {
            currentThreads
        }
    }

    /**
     * Giảm số luồng xử lý thông báo
     * @return Số luồng mới sau khi giảm
     */
    fun decreaseThreads(): Int {
        val currentThreads = getNotificationThreads()
        return if (currentThreads > MIN_THREADS) {
            setNotificationThreads(currentThreads - 1)
        } else {
            currentThreads
        }
    }

    /**
     * Kiểm tra xem có lưu thông báo hay không
     * @return true nếu lưu thông báo, false nếu không
     */
    fun isSaveNotificationsEnabled(): Boolean {
        return sharedPreferences.getBoolean(KEY_SAVE_NOTIFICATIONS, DEFAULT_SAVE_NOTIFICATIONS)
    }

    /**
     * Đặt cài đặt lưu thông báo
     * @param enabled true để bật lưu thông báo, false để tắt
     */
    fun setSaveNotifications(enabled: Boolean) {
        sharedPreferences.edit {
            putBoolean(KEY_SAVE_NOTIFICATIONS, enabled)
        }
        Log.d(TAG, "Set save notifications to: $enabled")
    }

    /**
     * Bật lưu thông báo
     */
    fun enableSaveNotifications() {
        setSaveNotifications(true)
    }

    /**
     * Tắt lưu thông báo
     */
    fun disableSaveNotifications() {
        setSaveNotifications(false)
    }

    /**
     * Toggle cài đặt lưu thông báo
     * @return Trạng thái mới sau khi toggle
     */
    fun toggleSaveNotifications(): Boolean {
        val newState = !isSaveNotificationsEnabled()
        setSaveNotifications(newState)
        return newState
    }

    /**
     * Reset về cài đặt mặc định
     */
    fun resetToDefaults() {
        setNotificationThreads(DEFAULT_THREADS)
        setSaveNotifications(DEFAULT_SAVE_NOTIFICATIONS)
        Log.d(TAG, "Reset to default settings")
    }

    /**
     * Lấy giới hạn tối đa cho số luồng
     */
    fun getMaxThreads(): Int {
        return MAX_THREADS
    }

    /**
     * Lấy giới hạn tối thiểu cho số luồng
     */
    fun getMinThreads(): Int {
        return MIN_THREADS
    }
}
