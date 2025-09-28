
package com.x319.notifybank.config

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONObject

/**
 * Lớp quản lý API cho các ngân hàng MB Bank, Cake và MoMo
 */
class BankApiConfig(private val context: Context) {
    private val TAG = "BankApiConfig"
    private val sharedPreferences: SharedPreferences

    // Hỗ trợ 3 ngân hàng/ví điện tử
    enum class BankType {
        MB_BANK,
        CAKE,
        MOMO
    }

    init {
        sharedPreferences = context.getSharedPreferences("bank_api_config", Context.MODE_PRIVATE)
        // Tạo cấu hình mặc định nếu chưa có
        if (!sharedPreferences.contains("config_initialized")) {
            initializeDefaultConfig()
        }
    }

    /**
     * Khởi tạo cấu hình mặc định
     */
    private fun initializeDefaultConfig() {
        val configJson = JSONObject()

        // Cấu hình mặc định cho MB Bank
        val mbBankApis = JSONObject()
        configJson.put(BankType.MB_BANK.name, mbBankApis)

        // Cấu hình mặc định cho Cake
        val cakeApis = JSONObject()
        configJson.put(BankType.CAKE.name, cakeApis)

        // Cấu hình mặc định cho MoMo
        val momoApis = JSONObject()
        configJson.put(BankType.MOMO.name, momoApis)

        // Lưu cấu hình mặc định
        sharedPreferences.edit()
            .putString("bank_config", configJson.toString())
            .putBoolean("config_initialized", true)
            .apply()

        Log.d(TAG, "Đã khởi tạo cấu hình mặc định cho MB Bank, Cake và MoMo")
    }

    /**
     * Lấy cấu hình của một ngân hàng/ví điện tử
     */
    private fun getBankConfig(bankType: BankType): JSONObject {
        val configString = sharedPreferences.getString("bank_config", "{}")
        return try {
            val fullConfig = JSONObject(configString ?: "{}")
            if (fullConfig.has(bankType.name)) {
                fullConfig.getJSONObject(bankType.name)
            } else {
                JSONObject()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi đọc cấu hình cho ${bankType.name}", e)
            JSONObject()
        }
    }

    /**
     * Lưu cấu hình của một ngân hàng/ví điện tử
     */
    private fun saveBankConfig(bankType: BankType, bankConfig: JSONObject) {
        try {
            val configString = sharedPreferences.getString("bank_config", "{}")
            val fullConfig = JSONObject(configString ?: "{}")
            fullConfig.put(bankType.name, bankConfig)
            
            sharedPreferences.edit()
                .putString("bank_config", fullConfig.toString())
                .apply()
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi lưu cấu hình cho ${bankType.name}", e)
        }
    }

    /**
     * Thêm API mới cho ngân hàng/ví điện tử
     */
    fun addApi(
        bankType: BankType, 
        name: String, 
        apiUrl: String, 
        apiKey: String, 
        enabled: Boolean,
        notifyOnMoneyIn: Boolean = true,
        notifyOnMoneyOut: Boolean = false,
        retryOnFailure: Boolean = true,
        maxRetries: Int = 3,
        retryDelayMs: Long = 3000,
        conditions: String = "" // Thêm trường điều kiện mới
    ) {
        try {
            val bankConfig = getBankConfig(bankType)
            
            // Tạo thông tin API mới
            val apiInfo = JSONObject().apply {
                put("name", name)
                put("url", apiUrl)
                put("key", apiKey)
                put("enabled", enabled)
                put("notifyOnMoneyIn", notifyOnMoneyIn)
                put("notifyOnMoneyOut", notifyOnMoneyOut)
                put("retryOnFailure", retryOnFailure)
                put("maxRetries", maxRetries)
                put("retryDelayMs", retryDelayMs)
                put("conditions", conditions) // Thêm trường điều kiện mới
            }
            
            // Thêm vào cấu hình
            bankConfig.put(name, apiInfo)
            
            // Lưu cấu hình
            saveBankConfig(bankType, bankConfig)
            
            Log.d(TAG, "Đã thêm API '$name' cho ${bankType.name}")
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi thêm API cho ${bankType.name}", e)
        }
    }

    /**
     * Cập nhật thông tin API
     */
    fun updateApi(
        bankType: BankType, 
        name: String, 
        apiUrl: String, 
        apiKey: String, 
        enabled: Boolean,
        notifyOnMoneyIn: Boolean = true,
        notifyOnMoneyOut: Boolean = false,
        retryOnFailure: Boolean = true,
        maxRetries: Int = 3,
        retryDelayMs: Long = 3000,
        conditions: String = "" // Thêm trường điều kiện mới
    ) {
        try {
            val bankConfig = getBankConfig(bankType)
            
            if (bankConfig.has(name)) {
                // Cập nhật thông tin API
                val apiInfo = bankConfig.getJSONObject(name)
                apiInfo.put("name", name)
                apiInfo.put("url", apiUrl)
                apiInfo.put("key", apiKey)
                apiInfo.put("enabled", enabled)
                apiInfo.put("notifyOnMoneyIn", notifyOnMoneyIn)
                apiInfo.put("notifyOnMoneyOut", notifyOnMoneyOut)
                apiInfo.put("retryOnFailure", retryOnFailure)
                apiInfo.put("maxRetries", maxRetries)
                apiInfo.put("retryDelayMs", retryDelayMs)
                apiInfo.put("conditions", conditions) // Thêm trường điều kiện mới
                
                // Lưu lại vào cấu hình
                bankConfig.put(name, apiInfo)
                saveBankConfig(bankType, bankConfig)
                
                Log.d(TAG, "Đã cập nhật API '$name' cho ${bankType.name}")
            } else {
                // Nếu không tồn tại thì thêm mới
                addApi(bankType, name, apiUrl, apiKey, enabled, notifyOnMoneyIn, notifyOnMoneyOut, retryOnFailure, maxRetries, retryDelayMs, conditions)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi cập nhật API cho ${bankType.name}", e)
        }
    }

    /**
     * Xóa API
     */
    fun removeApi(bankType: BankType, name: String) {
        try {
            val bankConfig = getBankConfig(bankType)
            
            if (bankConfig.has(name)) {
                bankConfig.remove(name)
                saveBankConfig(bankType, bankConfig)
                Log.d(TAG, "Đã xóa API '$name' cho ${bankType.name}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi xóa API cho ${bankType.name}", e)
        }
    }

    /**
     * Bật/tắt API
     */
    fun setApiEnabled(bankType: BankType, name: String, enabled: Boolean) {
        try {
            val bankConfig = getBankConfig(bankType)
            
            if (bankConfig.has(name)) {
                val apiInfo = bankConfig.getJSONObject(name)
                apiInfo.put("enabled", enabled)
                bankConfig.put(name, apiInfo)
                saveBankConfig(bankType, bankConfig)
                
                Log.d(TAG, "Đã ${if (enabled) "bật" else "tắt"} API '$name' cho ${bankType.name}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi thay đổi trạng thái API cho ${bankType.name}", e)
        }
    }

    /**
     * Cập nhật cấu hình thông báo tiền vào/tiền ra cho API
     */
    fun updateNotificationSettings(
        bankType: BankType, 
        name: String, 
        notifyOnMoneyIn: Boolean, 
        notifyOnMoneyOut: Boolean
    ) {
        try {
            val bankConfig = getBankConfig(bankType)
            
            if (bankConfig.has(name)) {
                val apiInfo = bankConfig.getJSONObject(name)
                apiInfo.put("notifyOnMoneyIn", notifyOnMoneyIn)
                apiInfo.put("notifyOnMoneyOut", notifyOnMoneyOut)
                bankConfig.put(name, apiInfo)
                saveBankConfig(bankType, bankConfig)
                
                Log.d(TAG, "Đã cập nhật cấu hình thông báo cho API '$name' của ${bankType.name}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi cập nhật cấu hình thông báo cho API của ${bankType.name}", e)
        }
    }

    /**
     * Cập nhật cấu hình thử lại khi gọi API thất bại
     */
    fun updateRetryOnFailureSetting(
        bankType: BankType,
        name: String,
        retryOnFailure: Boolean
    ) {
        try {
            val bankConfig = getBankConfig(bankType)
            
            if (bankConfig.has(name)) {
                val apiInfo = bankConfig.getJSONObject(name)
                apiInfo.put("retryOnFailure", retryOnFailure)
                bankConfig.put(name, apiInfo)
                saveBankConfig(bankType, bankConfig)
                
                Log.d(TAG, "Đã cập nhật cấu hình thử lại cho API '$name' của ${bankType.name}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi cập nhật cấu hình thử lại cho API của ${bankType.name}", e)
        }
    }

    /**
     * Cập nhật cấu hình thử lại chi tiết (số lần và thời gian)
     */
    fun updateRetryConfig(
        bankType: BankType,
        name: String,
        retryOnFailure: Boolean,
        maxRetries: Int,
        retryDelayMs: Long
    ) {
        try {
            val bankConfig = getBankConfig(bankType)
            
            if (bankConfig.has(name)) {
                val apiInfo = bankConfig.getJSONObject(name)
                apiInfo.put("retryOnFailure", retryOnFailure)
                apiInfo.put("maxRetries", maxRetries)
                apiInfo.put("retryDelayMs", retryDelayMs)
                bankConfig.put(name, apiInfo)
                saveBankConfig(bankType, bankConfig)
                
                Log.d(TAG, "Đã cập nhật cấu hình thử lại chi tiết cho API '$name' của ${bankType.name}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi cập nhật cấu hình thử lại chi tiết cho API của ${bankType.name}", e)
        }
    }

    /**
     * Cập nhật điều kiện cho API
     */
    fun updateConditions(
        bankType: BankType,
        name: String,
        conditions: String
    ) {
        try {
            val bankConfig = getBankConfig(bankType)
            
            if (bankConfig.has(name)) {
                val apiInfo = bankConfig.getJSONObject(name)
                apiInfo.put("conditions", conditions)
                bankConfig.put(name, apiInfo)
                saveBankConfig(bankType, bankConfig)
                
                Log.d(TAG, "Đã cập nhật điều kiện cho API '$name' của ${bankType.name}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi cập nhật điều kiện cho API của ${bankType.name}", e)
        }
    }

    /**
     * Lấy danh sách tất cả API của một ngân hàng/ví điện tử
     */
    fun getAllApis(bankType: BankType): List<ApiInfo> {
        val result = mutableListOf<ApiInfo>()
        try {
            val bankConfig = getBankConfig(bankType)
            val apiNames = bankConfig.keys()
            
            while (apiNames.hasNext()) {
                val name = apiNames.next()
                val apiInfo = bankConfig.getJSONObject(name)
                
                result.add(
                    ApiInfo(
                        name = apiInfo.getString("name"),
                        url = apiInfo.getString("url"),
                        key = apiInfo.getString("key"),
                        enabled = apiInfo.getBoolean("enabled"),
                        notifyOnMoneyIn = apiInfo.optBoolean("notifyOnMoneyIn", true),
                        notifyOnMoneyOut = apiInfo.optBoolean("notifyOnMoneyOut", false),
                        retryOnFailure = apiInfo.optBoolean("retryOnFailure", true),
                        maxRetries = apiInfo.optInt("maxRetries", 3),
                        retryDelayMs = apiInfo.optLong("retryDelayMs", 3000),
                        conditions = apiInfo.optString("conditions", "")
                    )
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi lấy danh sách API cho ${bankType.name}", e)
        }
        return result
    }

    /**
     * Lấy thông tin một API cụ thể
     */
    fun getApi(bankType: BankType, name: String): ApiInfo? {
        try {
            val bankConfig = getBankConfig(bankType)
            if (bankConfig.has(name)) {
                val apiInfo = bankConfig.getJSONObject(name)
                return ApiInfo(
                    name = apiInfo.getString("name"),
                    url = apiInfo.getString("url"),
                    key = apiInfo.getString("key"),
                    enabled = apiInfo.getBoolean("enabled"),
                    notifyOnMoneyIn = apiInfo.optBoolean("notifyOnMoneyIn", true),
                    notifyOnMoneyOut = apiInfo.optBoolean("notifyOnMoneyOut", false),
                    retryOnFailure = apiInfo.optBoolean("retryOnFailure", true),
                    maxRetries = apiInfo.optInt("maxRetries", 3),
                    retryDelayMs = apiInfo.optLong("retryDelayMs", 3000),
                    conditions = apiInfo.optString("conditions", "")
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi lấy thông tin API '$name' cho ${bankType.name}", e)
        }
        return null
    }

    /**
     * Kiểm tra xem một API có nên được thông báo cho loại giao dịch cụ thể không
     * @param bankType Loại ngân hàng/ví điện tử
     * @param name Tên API
     * @param isMoneyIn true nếu là giao dịch tiền vào, false nếu là tiền ra
     * @return true nếu API được cấu hình để thông báo cho loại giao dịch này
     */
    fun shouldNotify(bankType: BankType, name: String, isMoneyIn: Boolean): Boolean {
        val api = getApi(bankType, name) ?: return false
        if (!api.enabled) return false
        
        return if (isMoneyIn) api.notifyOnMoneyIn else api.notifyOnMoneyOut
    }

    /**
     * Kiểm tra xem một API có nên thử lại khi gọi thất bại không
     * @param bankType Loại ngân hàng/ví điện tử
     * @param name Tên API
     * @return true nếu API được cấu hình để thử lại khi gọi thất bại
     */
    fun shouldRetryOnFailure(bankType: BankType, name: String): Boolean {
        val api = getApi(bankType, name) ?: return false
        if (!api.enabled) return false
        
        return api.retryOnFailure
    }

    /**
     * Lấy số lần thử lại tối đa cho API
     * @param bankType Loại ngân hàng/ví điện tử
     * @param name Tên API
     * @return Số lần thử lại tối đa, mặc định là 3
     */
    fun getMaxRetries(bankType: BankType, name: String): Int {
        val api = getApi(bankType, name) ?: return 3
        if (!api.enabled || !api.retryOnFailure) return 0
        
        return api.maxRetries
    }

    /**
     * Lấy thời gian giữa các lần thử lại cho API (ms)
     * @param bankType Loại ngân hàng/ví điện tử
     * @param name Tên API
     * @return Thời gian giữa các lần thử lại (ms), mặc định là 3000
     */
    fun getRetryDelayMs(bankType: BankType, name: String): Long {
        val api = getApi(bankType, name) ?: return 3000
        if (!api.enabled || !api.retryOnFailure) return 0
        
        return api.retryDelayMs
    }

    /**
     * Kiểm tra xem nội dung chuyển khoản có thỏa mãn điều kiện của API không
     * @param bankType Loại ngân hàng/ví điện tử
     * @param name Tên API
     * @param transactionContent Nội dung chuyển khoản cần kiểm tra
     * @return true nếu nội dung thỏa mãn điều kiện hoặc không có điều kiện nào được đặt
     */
    fun checkConditions(bankType: BankType, name: String, transactionContent: String): Boolean {
        val api = getApi(bankType, name) ?: return false
        if (!api.enabled) return false
        
        // Nếu không có điều kiện nào được đặt, mặc định là thỏa mãn
        if (api.conditions.isBlank()) return true
        
        return parseAndCheckConditions(api.conditions, transactionContent)
    }

    /**
     * Phân tích và kiểm tra điều kiện từ chuỗi định nghĩa quy tắc
     * @param conditionString Chuỗi định nghĩa quy tắc, ví dụ: "*1#1=10000#*2#*vip1*vip2*vip3#*3#*ts*tt*gh#"
     * @param transactionContent Nội dung chuyển khoản cần kiểm tra
     * @return true nếu nội dung thỏa mãn tất cả các điều kiện
     */
    private fun parseAndCheckConditions(conditionString: String, transactionContent: String): Boolean {
        try {
            // Nếu không có điều kiện, mặc định là thỏa mãn
            if (conditionString.isBlank()) return true
            
            // Sử dụng regex để tách các phần điều kiện theo mẫu *X#...#
            val conditionPattern = "\\*(\\d+)#([^*]+)#".toRegex()
            val conditions = conditionPattern.findAll(conditionString)
            
            // Nếu không tìm thấy điều kiện nào khớp với mẫu, trả về true
            if (!conditions.iterator().hasNext()) return true
            
            // Duyệt qua từng điều kiện theo thứ tự
            for (match in conditions) {
                val conditionNumber = match.groupValues[1].toIntOrNull() ?: continue
                val conditionContent = match.groupValues[2]
                
                Log.d(TAG, "Kiểm tra điều kiện $conditionNumber: $conditionContent")
                
                // Kiểm tra điều kiện dựa trên loại
                val conditionMet = when {
                    // Điều kiện số tiền: 1=10000
                    conditionContent.contains("=") -> {
                        val range = conditionContent.split("=")
                        if (range.size == 2) {
                            val min = range[0].toLongOrNull() ?: 0
                            val max = range[1].toLongOrNull() ?: Long.MAX_VALUE
                            
                            // Tìm số tiền trong nội dung giao dịch
                            val amountRegex = "\\d+".toRegex()
                            val amounts = amountRegex.findAll(transactionContent)
                                .map { it.value.toLongOrNull() ?: 0 }
                                .filter { it > 0 }
                                .toList()
                            
                            // Kiểm tra xem có số tiền nào thỏa mãn điều kiện không
                            val result = amounts.any { it in min..max }
                            Log.d(TAG, "Điều kiện số tiền ($min-$max): $result, tìm thấy: $amounts")
                            result
                        } else {
                            false
                        }
                    }
                    
                    // Điều kiện từ khóa: *vip1*vip2*vip3
                    conditionContent.startsWith("*") -> {
                        val keywords = conditionContent.split("*").filter { it.isNotEmpty() }
                        val result = keywords.any { transactionContent.contains(it, ignoreCase = true) }
                        Log.d(TAG, "Điều kiện từ khóa $keywords: $result")
                        result
                    }
                    
                    // Trường hợp khác, không thỏa mãn
                    else -> false
                }
                
                // Nếu điều kiện không thỏa mãn, trả về false ngay lập tức
                if (!conditionMet) {
                    Log.d(TAG, "Điều kiện $conditionNumber không thỏa mãn, kết thúc kiểm tra")
                    return false
                }
            }
            
            // Nếu tất cả điều kiện đều thỏa mãn, trả về true
            Log.d(TAG, "Tất cả điều kiện đều thỏa mãn")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi kiểm tra điều kiện: ${e.message}", e)
            return false
        }
    }

    /**
     * Lớp chứa thông tin về một API
     */
    data class ApiInfo(
        val name: String,
        val url: String,
        val key: String,
        val enabled: Boolean,
        val notifyOnMoneyIn: Boolean = true,    // Thông báo khi có tiền vào
        val notifyOnMoneyOut: Boolean = false,  // Thông báo khi có tiền ra
        val retryOnFailure: Boolean = true,     // Thử lại khi gọi API thất bại
        val maxRetries: Int = 3,                // Số lần thử lại tối đa (mặc định 3)
        val retryDelayMs: Long = 3000,          // Thời gian giữa các lần thử lại (ms) (mặc định 3 giây)
        val conditions: String = ""              // Điều kiện để gọi API
    )
}

