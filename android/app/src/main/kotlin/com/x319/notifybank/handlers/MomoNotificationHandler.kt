package com.x319.notifybank.handlers

import android.content.Context
import android.content.SharedPreferences
import android.service.notification.StatusBarNotification
import android.util.Log
import com.x319.notifybank.config.BankApiConfig
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.regex.Pattern
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import java.io.IOException
import java.util.concurrent.TimeUnit

class MomoNotificationHandler(private val context: Context) {
    private val TAG = "MomoNotificationHandler"
    private lateinit var sharedPreferences: SharedPreferences
    private val bankApiConfig = BankApiConfig(context)
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    init {
        // Khởi tạo SharedPreferences riêng cho Momo
        sharedPreferences = context.getSharedPreferences("momo_transactions", Context.MODE_PRIVATE)
    }

    /**
     * Kiểm tra xem thông báo có phải từ Momo không và có phải là thông báo nhận tiền không
     */
    fun canHandle(sbn: StatusBarNotification): Boolean {
        return sbn.packageName == "com.mservice.momotransfer" && 
               sbn.notification?.extras?.getString("android.title")?.contains("Nhận tiền") == true
    }

    /**
     * Xử lý thông báo từ Momo
     */
    fun handleNotification(sbn: StatusBarNotification): Boolean {
        try {
            val notification = sbn.notification ?: return false
            val extras = notification.extras ?: return false
            
            // Lấy tiêu đề thông báo
            val title = extras.getCharSequence("android.title")?.toString() ?: return false
            
            // Lấy nội dung thông báo
            val content = extras.getCharSequence("android.bigText")?.toString() 
                ?: extras.getCharSequence("android.text")?.toString()
                ?: return false
            
            Log.d(TAG, "Xử lý thông báo Momo: $title - $content")
            
            // Trích xuất số tiền
            var amount: String? = null
            val amountPattern = Pattern.compile("Số tiền (\\d+[.,]\\d+\\s*₫)")
            val amountMatcher = amountPattern.matcher(content)
            if (amountMatcher.find()) {
                amount = amountMatcher.group(1)
            }
            
            // Trích xuất nội dung chuyển khoản sau "kèm lời nhắn:"
            var transferContent: String? = null
            val contentPattern = Pattern.compile("kèm lời nhắn:\\s*\"(.+?)\"")
            val contentMatcher = contentPattern.matcher(content)
            if (contentMatcher.find()) {
                transferContent = contentMatcher.group(1)
            }
            
            // Nếu trích xuất được các thông tin cần thiết
            if (amount != null && transferContent != null) {
                // Điều kiện 1: Trích xuất mã giao dịch và nội dung thực sự từ ShopeePay
                var transactionId: String? = null
                var actualContent: String? = null
                
                // Pattern cho định dạng "SHOPEEPAY CHUYEN TIEN [mã giao dịch] Scan QR [nội dung thực sự].CT tu..."
                val shopeepayPattern = Pattern.compile("SHOPEEPAY CHUYEN TIEN (\\d+) Scan QR (\\w+)\\.CT tu")
                val shopeepayMatcher = shopeepayPattern.matcher(transferContent)
                
                if (shopeepayMatcher.find()) {
                    // Điều kiện 1 thỏa mãn
                    transactionId = shopeepayMatcher.group(1)
                    actualContent = shopeepayMatcher.group(2)
                    Log.d(TAG, "Điều kiện 1: Mã giao dịch = $transactionId, Nội dung thực sự = $actualContent")
                } else {
                    // Không thỏa mãn điều kiện 1, sử dụng toàn bộ nội dung
                    transactionId = "${sbn.postTime}_${transferContent.hashCode()}"
                    actualContent = transferContent
                    Log.d(TAG, "Không thỏa mãn điều kiện 1, sử dụng nội dung đầy đủ")
                }
                
                // Tạo ID giao dịch duy nhất nếu không tìm thấy mã giao dịch
                val uniqueTransactionId = transactionId ?: "${sbn.postTime}_${transferContent.hashCode()}"
                
                var processed = false
                
                // Gọi API dựa trên cấu hình
                processed = callConfiguredApis(amount, actualContent ?: transferContent, uniqueTransactionId)
                
                // Lưu giao dịch vào SharedPreferences kèm trạng thái xử lý
                saveTransaction(
                    amount,
                    "receive", // Momo chỉ xử lý nhận tiền
                    actualContent ?: transferContent,
                    uniqueTransactionId,
                    sbn.postTime,
                    processed,
                    null,  // Mã phản hồi sẽ được cập nhật sau khi API trả về
                    transactionId // Lưu mã giao dịch gốc nếu có
                )
                
                return true
            }
            
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi xử lý thông báo Momo", e)
            return false
        }
    }

    /**
     * Lưu giao dịch vào SharedPreferences
     */
    private fun saveTransaction(
        amount: String,
        type: String,
        description: String,
        transactionId: String,
        timestamp: Long,
        processed: Boolean,
        responseCode: Int? = null,
        originalTransactionId: String? = null
    ) {
        try {
            // Lấy danh sách giao dịch hiện tại
            val transactionsString = sharedPreferences.getString("momo_transactions", "[]") ?: "[]"
            val transactions = org.json.JSONArray(transactionsString)
            
            // Tạo đối tượng giao dịch mới
            val transaction = JSONObject().apply {
                put("amount", amount)
                put("type", type)
                put("description", description)
                put("transactionId", transactionId)
                put("timestamp", timestamp)
                put("processed", processed) // Thêm trường đánh dấu đã xử lý API hay chưa
                put("formattedTime", SimpleDateFormat("yyyy-MM-dd HH:mm:ss", 
                    Locale.getDefault()).format(Date(timestamp)))
                if (responseCode != null) {
                    put("responseCode", responseCode) // Thêm mã phản hồi nếu có
                }
                if (originalTransactionId != null) {
                    put("originalTransactionId", originalTransactionId) // Thêm mã giao dịch gốc nếu có
                }
            }
            
            // Thêm giao dịch mới vào đầu danh sách
            val updatedTransactions = org.json.JSONArray()
            updatedTransactions.put(transaction)
            
            // Giới hạn số lượng giao dịch lưu trữ (ví dụ: 100)
            val maxTransactions = 100
            for (i in 0 until minOf(transactions.length(), maxTransactions - 1)) {
                updatedTransactions.put(transactions.get(i))
            }
            
            // Lưu danh sách giao dịch mới
            sharedPreferences.edit().putString("momo_transactions", updatedTransactions.toString()).apply()
            
            Log.d(TAG, "Đã lưu giao dịch Momo: $amount - $description - Đã xử lý: $processed")
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi lưu giao dịch Momo", e)
        }
    }

    /**
     * Cập nhật mã phản hồi cho giao dịch đã lưu
     */
    private fun updateTransactionResponseCode(transactionId: String, responseCode: Int) {
        try {
            // Lấy danh sách giao dịch hiện tại
            val transactionsString = sharedPreferences.getString("momo_transactions", "[]") ?: "[]"
            val transactions = org.json.JSONArray(transactionsString)
            
            // Tìm và cập nhật giao dịch với ID tương ứng
            for (i in 0 until transactions.length()) {
                val transaction = transactions.getJSONObject(i)
                if (transaction.has("transactionId") && transaction.getString("transactionId") == transactionId) {
                    transaction.put("responseCode", responseCode)
                    break
                }
            }
            
            // Lưu lại danh sách giao dịch đã cập nhật
            sharedPreferences.edit().putString("momo_transactions", transactions.toString()).apply()
            
            Log.d(TAG, "Đã cập nhật mã phản hồi $responseCode cho giao dịch $transactionId")
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi cập nhật mã phản hồi cho giao dịch", e)
        }
    }

    /**
     * Gọi các API được cấu hình và đang bật
     * @param amount Số tiền giao dịch
     * @param content Nội dung chuyển khoản
     * @param transactionId ID giao dịch để theo dõi
     * @return true nếu đã gọi API, false nếu không có API nào được gọi
     */
    private fun callConfiguredApis(
        amount: String, 
        content: String, 
        transactionId: String
    ): Boolean {
        try {
            // Lấy danh sách API được cấu hình cho Momo
            val apis = bankApiConfig.getAllApis(BankApiConfig.BankType.MOMO)
            
            // Lọc các API được bật và phù hợp với loại giao dịch (tiền vào)
            val filteredApis = apis.filter { api -> 
                api.enabled && 
                api.notifyOnMoneyIn && 
                bankApiConfig.checkConditions(BankApiConfig.BankType.MOMO, api.name, content)
            }
            
            if (filteredApis.isEmpty()) {
                Log.d(TAG, "Không có API nào được cấu hình phù hợp với giao dịch nhận tiền Momo")
                return false
            }
            
            // Xử lý số tiền để loại bỏ "₫" và dấu phẩy phân cách
            val cleanAmount = amount.replace("₫", "")
                                   .replace(",", "")
                                   .replace(".", "")
                                   .trim()
            val amountValue = cleanAmount.toLongOrNull() ?: 0
            
            // Chuẩn bị dữ liệu JSON để gửi
            val requestData = JSONObject().apply {
                put("gateway", "Momo")
                put("content", content)
                put("transferAmount", amountValue)
                put("transactionId", transactionId) // Thêm ID giao dịch để theo dõi
            }
            
            Log.d(TAG, "Chuẩn bị gọi ${filteredApis.size} API với dữ liệu: $requestData cho giao dịch nhận tiền Momo")
            
            // Gọi từng API đã được lọc
            for (api in filteredApis) {
                callApi(api, requestData, transactionId, 0) // Bắt đầu với số lần thử = 0
            }
            
            // Nếu có ít nhất một API được gọi, đánh dấu là đã xử lý
            return filteredApis.isNotEmpty()
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi gọi API đã cấu hình", e)
            return false
        }
    }
    
    /**
     * Gọi một API cụ thể
     * @param apiInfo Thông tin API cần gọi
     * @param requestData Dữ liệu gửi đi
     * @param transactionId ID giao dịch
     * @param retryCount Số lần đã thử lại (bắt đầu từ 0)
     */
    private fun callApi(
        apiInfo: BankApiConfig.ApiInfo, 
        requestData: JSONObject, 
        transactionId: String, 
        retryCount: Int
    ) {
        try {
            // Tạo request body
            val mediaType = "application/json; charset=utf-8".toMediaType()
            val requestBody = RequestBody.create(mediaType, requestData.toString())
            
            // Tạo request
            val request = Request.Builder()
                .url(apiInfo.url)
                .addHeader("Content-Type", "application/json")
                .addHeader("Authorization", "Apikey ${apiInfo.key}")
                .post(requestBody)
                .build()
            
            val retryInfo = if (retryCount > 0) " (lần thử lại thứ $retryCount)" else ""
            Log.d(TAG, "Đang gọi API ${apiInfo.name}$retryInfo tại ${apiInfo.url}")
            
            // Thực hiện gọi API bất đồng bộ
            client.newCall(request).enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    Log.e(TAG, "Lỗi khi gọi API ${apiInfo.name}$retryInfo: ${e.message}")
                    
                    // Kiểm tra cấu hình thử lại và số lần thử lại tối đa
                    val maxRetries = bankApiConfig.getMaxRetries(BankApiConfig.BankType.MOMO, apiInfo.name)
                    if (bankApiConfig.shouldRetryOnFailure(BankApiConfig.BankType.MOMO, apiInfo.name) && 
                        retryCount < maxRetries) {
                        
                        // Lấy thời gian chờ giữa các lần thử lại từ cấu hình
                        val retryDelayMs = bankApiConfig.getRetryDelayMs(BankApiConfig.BankType.MOMO, apiInfo.name)
                        
                        Log.d(TAG, "Thử lại gọi API ${apiInfo.name} sau lỗi kết nối (${retryCount + 1}/$maxRetries) sau ${retryDelayMs}ms")
                        
                        // Thử lại sau khoảng thời gian được cấu hình
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            callApi(apiInfo, requestData, transactionId, retryCount + 1)
                        }, retryDelayMs)
                    } else if (retryCount >= maxRetries) {
                        Log.d(TAG, "Đã đạt số lần thử lại tối đa ($maxRetries) cho API ${apiInfo.name}")
                    }
                }
                
                override fun onResponse(call: Call, response: Response) {
                    val responseCode = response.code
                    val responseBody = response.body?.string() ?: "Empty response"
                    
                    // Cập nhật mã phản hồi vào thông tin giao dịch
                    updateTransactionResponseCode(transactionId, responseCode)
                    
                    if (response.isSuccessful) {
                        Log.d(TAG, "API ${apiInfo.name}$retryInfo phản hồi thành công (${responseCode}): $responseBody")
                    } else {
                        Log.e(TAG, "API ${apiInfo.name}$retryInfo phản hồi lỗi (${responseCode}): $responseBody")
                        
                        // Kiểm tra mã lỗi và quyết định có thử lại không
                        val maxRetries = bankApiConfig.getMaxRetries(BankApiConfig.BankType.MOMO, apiInfo.name)
                        if (shouldRetryBasedOnResponseCode(responseCode) && 
                            bankApiConfig.shouldRetryOnFailure(BankApiConfig.BankType.MOMO, apiInfo.name) &&
                            retryCount < maxRetries) {
                            
                            // Lấy thời gian chờ giữa các lần thử lại từ cấu hình
                            val retryDelayMs = bankApiConfig.getRetryDelayMs(BankApiConfig.BankType.MOMO, apiInfo.name)
                            
                            Log.d(TAG, "Thử lại gọi API ${apiInfo.name} sau lỗi HTTP $responseCode (${retryCount + 1}/$maxRetries) sau ${retryDelayMs}ms")
                            
                            // Thử lại sau khoảng thời gian được cấu hình
                            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                callApi(apiInfo, requestData, transactionId, retryCount + 1)
                            }, retryDelayMs)
                        } else if (retryCount >= maxRetries) {
                            Log.d(TAG, "Đã đạt số lần thử lại tối đa ($maxRetries) cho API ${apiInfo.name}")
                        }
                    }
                    response.close()
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi gọi API ${apiInfo.name}: ${e.message}")
        }
    }
    
    /**
     * Kiểm tra xem có nên thử lại dựa trên mã phản hồi không
     * @param responseCode Mã phản hồi HTTP
     * @return true nếu nên thử lại, false nếu không
     */
    private fun shouldRetryBasedOnResponseCode(responseCode: Int): Boolean {
        // Không thử lại với mã 200 (thành công), 403 (cấm truy cập), 404 (không tìm thấy)
        return when (responseCode) {
            200, 403, 404 -> false
            // Thử lại với các mã lỗi máy chủ (5xx) và các lỗi khác
            else -> true
        }
    }

    /**
     * Lấy danh sách giao dịch đã lưu
     */
    fun getTransactions(): String {
        return sharedPreferences.getString("momo_transactions", "[]") ?: "[]"
    }
    
    /**
     * Xóa tất cả giao dịch đã lưu
     */
    fun clearTransactions() {
        sharedPreferences.edit().putString("momo_transactions", "[]").apply()
        Log.d(TAG, "Đã xóa tất cả giao dịch Momo")
    }
}
