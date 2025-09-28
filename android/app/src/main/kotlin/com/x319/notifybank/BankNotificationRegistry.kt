
package com.x319.notifybank

import android.content.Context
import android.service.notification.StatusBarNotification
import android.util.Log
import com.x319.notifybank.handlers.CakeNotificationHandler
import com.x319.notifybank.handlers.MBNotificationHandler
import com.x319.notifybank.handlers.MomoNotificationHandler

/**
 * Lớp quản lý và đăng ký các handler xử lý thông báo ngân hàng
 */
class BankNotificationRegistry(private val context: Context) {
    private val TAG = "BankNotificationRegistry"
    
    // Danh sách các handler xử lý thông báo
    private val cakeHandler: CakeNotificationHandler by lazy { CakeNotificationHandler(context) }
    private val mbHandler: MBNotificationHandler by lazy { MBNotificationHandler(context) }
    private val momoHandler: MomoNotificationHandler by lazy { MomoNotificationHandler(context) }
    
    /**
     * Xử lý thông báo từ các ngân hàng/ví điện tử được hỗ trợ
     * @param sbn Thông báo cần xử lý
     * @return true nếu có ít nhất một handler xử lý thành công, false nếu không có handler nào xử lý
     */
    fun handleBankNotification(sbn: StatusBarNotification): Boolean {
        try {
            var handled = false
            
            // Xử lý thông báo từ Cake by VPBank
            if (cakeHandler.canHandle(sbn)) {
                handled = cakeHandler.handleNotification(sbn) || handled
                Log.d(TAG, "Cake handler processed notification: $handled")
            }
            
            // Xử lý thông báo từ MB Bank
            if (mbHandler.canHandle(sbn)) {
                handled = mbHandler.handleNotification(sbn) || handled
                Log.d(TAG, "MB Bank handler processed notification: $handled")
            }
            
            // Xử lý thông báo từ MoMo
            if (momoHandler.canHandle(sbn)) {
                handled = momoHandler.handleNotification(sbn) || handled
                Log.d(TAG, "MoMo handler processed notification: $handled")
            }
            
            return handled
        } catch (e: Exception) {
            Log.e(TAG, "Error handling bank notification", e)
            return false
        }
    }
    
    /**
     * Lấy danh sách giao dịch từ Cake
     */
    fun getCakeTransactions(): String {
        return cakeHandler.getTransactions()
    }
    
    /**
     * Lấy danh sách giao dịch từ MB Bank
     */
    fun getMBTransactions(): String {
        return mbHandler.getTransactions()
    }
    
    /**
     * Lấy danh sách giao dịch từ MoMo
     */
    fun getMomoTransactions(): String {
        return momoHandler.getTransactions()
    }
    
    /**
     * Xóa tất cả giao dịch đã lưu từ Cake
     */
    fun clearCakeTransactions() {
        cakeHandler.clearTransactions()
    }
    
    /**
     * Xóa tất cả giao dịch đã lưu từ MB Bank
     */
    fun clearMBTransactions() {
        mbHandler.clearTransactions()
    }
    
    /**
     * Xóa tất cả giao dịch đã lưu từ MoMo
     */
    fun clearMomoTransactions() {
        momoHandler.clearTransactions()
    }
}