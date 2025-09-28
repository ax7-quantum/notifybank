package com.x319.notifybank

object Constants {
    // Permission request codes
    const val BATTERY_OPTIMIZATION_CODE = 101
    const val AUTOSTART_SETTINGS_CODE = 102
    const val SMS_PERMISSION_CODE = 103
    const val PHONE_STATE_PERMISSION_CODE = 104
    const val READ_SMS_PERMISSION_CODE = 105
    const val RECEIVE_SMS_PERMISSION_CODE = 106
    const val BOTH_SMS_PERMISSIONS_CODE = 107
    const val CONTACTS_PERMISSION_CODE = 108  // Thêm mã yêu cầu quyền danh bạ
    
    // Channel names
    const val SMS_CHANNEL = "com.x319.notifybank/sms"
    const val SMS_RECEIVER_CHANNEL = "com.x319.notifybank/sms_receiver"
    const val SMS_RECEIVER_EVENT_CHANNEL = "com.x319.notifybank/sms_receiver_events"
    const val NOTIFICATION_CHANNEL = "com.x319.notifybank/notification"
    const val CONTACTS_CHANNEL = "com.x319.notifybank/contacts"  // Thêm kênh danh bạ
}