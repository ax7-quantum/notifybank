package com.x319.notifybank.handlers

import android.content.Context
import android.content.SharedPreferences
import android.service.notification.StatusBarNotification
import android.util.Log
import com.x319.notifybank.config.BankApiConfig
import org.json.JSONObject
import java.util.regex.Pattern
import java.util.regex.Matcher
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import java.io.IOException
import java.util.concurrent.TimeUnit

class CakeNotificationHandler(private val context: Context) {
    private val TAG = "CakeNotificationHandler"
    private lateinit var sharedPreferences: SharedPreferences
    private val bankApiConfig = BankApiConfig(context)
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    init {
        // Khởi tạo SharedPreferences riêng cho Cake
        sharedPreferences = context.getSharedPreferences("cake_transactions", Context.MODE_PRIVATE)
    }

    /**
     * Kiểm tra xem thông báo có phải từ Cake by VPBank không
     */
    fun canHandle(sbn: StatusBarNotification): Boolean {
        return sbn.packageName == "xyz.be.cake" && 
               sbn.notification?.extras?.getString("android.title") == "Thông báo biến động số dư"
    }

    /**
     * Xử lý thông báo từ Cake by VPBank
     */
    fun handleNotification(sbn: StatusBarNotification): Boolean {
        try {
            val notification = sbn.notification ?: return false
            val extras = notification.extras ?: return false
            
            // Lấy nội dung thông báo
            val content = extras.getCharSequence("android.bigText")?.toString() 
                ?: extras.getCharSequence("android.text")?.toString()
                ?: return false
            
            Log.d(TAG, "Xử lý thông báo Cake: $content")
            
            // Xác định loại giao dịch (tăng hay giảm số dư)
            val isMoneyIn = content.contains("vừa tăng")
            val isMoneyOut = content.contains("vừa giảm")
            
            if (!isMoneyIn && !isMoneyOut) {
                Log.d(TAG, "Không phải thông báo biến động số dư: $content")
                return false
            }
            
            // Trích xuất số tiền biến động
            var amount: String? = null
            val amountPattern = if (isMoneyIn) {
                Pattern.compile("vừa tăng (\\d+\\.?\\d* đ)")
            } else {
                Pattern.compile("vừa giảm (\\d+\\.?\\d* đ)")
            }
            
            val amountMatcher = amountPattern.matcher(content)
            if (amountMatcher.find()) {
                amount = amountMatcher.group(1) // "10.000 đ"
            }
            
            // Trích xuất nội dung giao dịch
            var transactionContent: String? = null
            val contentPattern = Pattern.compile("Nội dung: (.*?)\\. Số dư")
            val contentMatcher = contentPattern.matcher(content)
            if (contentMatcher.find()) {
                transactionContent = contentMatcher.group(1) // "HOANG NGOC DIEP chuyen tien"
            }
            
            // Trích xuất số dư hiện tại
            var currentBalance: String? = null
            val balancePattern = Pattern.compile("Số dư hiện tại của tài khoản thanh toán là (\\d+\\.?\\d* đ)")
            val balanceMatcher = balancePattern.matcher(content)
            if (balanceMatcher.find()) {
                currentBalance = balanceMatcher.group(1) // "500.683 đ"
            }
            
            // Nếu trích xuất thành công tất cả thông tin
            if (amount != null && transactionContent != null && currentBalance != null) {
                // Tạo ID giao dịch dựa trên thời gian và nội dung để theo dõi việc gọi API
                val transactionId = "${sbn.postTime}_${transactionContent.hashCode()}"
                
                // Kiểm tra và gọi API nếu có cấu hình và được bật
                val apiProcessed = callConfiguredApis(amount, transactionContent, currentBalance, isMoneyIn, transactionId)
                
                // Lưu giao dịch vào SharedPreferences riêng kèm trạng thái xử lý
                saveTransaction(
                    amount, 
                    transactionContent, 
                    currentBalance, 
                    sbn.postTime, 
                    apiProcessed,
                    if (isMoneyIn) "receive" else "send",  // Đã sửa từ isMoneyIn ? "receive" : "send"
                    transactionId,
                    null  // Mã phản hồi sẽ được cập nhật sau khi API trả về
                )
                
                return true
            }
            
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi xử lý thông báo Cake", e)
            return false
        }
    }

    /**
     * Lưu giao dịch vào SharedPreferences
     */
    private fun saveTransaction(
        amount: String, 
        content: String, 
        balance: String, 
        timestamp: Long, 
        processed: Boolean,
        type: String,
        transactionId: String,
        responseCode: Int? = null
    ) {
        try {
            // Lấy danh sách giao dịch hiện tại
            val transactionsString = sharedPreferences.getString("cake_transactions", "[]") ?: "[]"
            val transactions = org.json.JSONArray(transactionsString)
            
            // Tạo đối tượng giao dịch mới
            val transaction = JSONObject().apply {
                put("amount", amount)
                put("content", content)
                put("balance", balance)
                put("timestamp", timestamp)
                put("processed", processed) // Thêm trường đánh dấu đã xử lý API hay chưa
                put("type", type) // Thêm trường loại giao dịch (nhận/gửi)
                put("formattedTime", java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", 
                    java.util.Locale.getDefault()).format(java.util.Date(timestamp)))
                put("transactionId", transactionId) // Thêm ID giao dịch để theo dõi
                if (responseCode != null) {
                    put("responseCode", responseCode) // Thêm mã phản hồi nếu có
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
            sharedPreferences.edit().putString("cake_transactions", updatedTransactions.toString()).apply()
            
            Log.d(TAG, "Đã lưu giao dịch Cake: $amount - $content - Loại: $type - Đã xử lý: $processed")
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi lưu giao dịch", e)
        }
    }

    /**
     * Cập nhật mã phản hồi cho giao dịch đã lưu
     */
    private fun updateTransactionResponseCode(transactionId: String, responseCode: Int) {
        try {
            // Lấy danh sách giao dịch hiện tại
            val transactionsString = sharedPreferences.getString("cake_transactions", "[]") ?: "[]"
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
            sharedPreferences.edit().putString("cake_transactions", transactions.toString()).apply()
            
            Log.d(TAG, "Đã cập nhật mã phản hồi $responseCode cho giao dịch $transactionId")
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi cập nhật mã phản hồi cho giao dịch", e)
        }
    }

    /**
     * Gọi các API được cấu hình và đang bật
     * @param amount Số tiền giao dịch
     * @param content Nội dung giao dịch
     * @param balance Số dư hiện tại
     * @param isMoneyIn true nếu là giao dịch tiền vào, false nếu là tiền ra
     * @param transactionId ID giao dịch để theo dõi
     * @return true nếu đã gọi API, false nếu không có API nào được gọi
     */
    private fun callConfiguredApis(
        amount: String, 
        content: String, 
        balance: String, 
        isMoneyIn: Boolean,
        transactionId: String
    ): Boolean {
        try {
            // Lấy danh sách API được cấu hình cho Cake
            val apis = bankApiConfig.getAllApis(BankApiConfig.BankType.CAKE)
            
            // Lọc các API được bật và phù hợp với loại giao dịch (tiền vào/tiền ra)
            val filteredApis = apis.filter { api -> 
                api.enabled && 
                ((isMoneyIn && api.notifyOnMoneyIn) || (!isMoneyIn && api.notifyOnMoneyOut)) &&
                bankApiConfig.checkConditions(BankApiConfig.BankType.CAKE, api.name, content)
            }
            
            if (filteredApis.isEmpty()) {
                Log.d(TAG, "Không có API nào được cấu hình phù hợp với loại giao dịch ${if(isMoneyIn) "tiền vào" else "tiền ra"}")
                return false
            }
            
            // Xử lý số tiền để loại bỏ "đ" và dấu chấm phân cách
            val cleanAmount = amount.replace("đ", "").trim().replace(".", "")
            val amountValue = cleanAmount.toLongOrNull() ?: 0
            
            // Chuẩn bị dữ liệu JSON để gửi
            val requestData = JSONObject().apply {
                put("gateway", "Cake")
                put("content", content)
                put("transferAmount", amountValue)
                put("transactionId", transactionId) // Thêm ID giao dịch để theo dõi
            }
            
            Log.d(TAG, "Chuẩn bị gọi ${filteredApis.size} API với dữ liệu: $requestData cho giao dịch ${if(isMoneyIn) "tiền vào" else "tiền ra"}")
            
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
                    val maxRetries = bankApiConfig.getMaxRetries(BankApiConfig.BankType.CAKE, apiInfo.name)
                    if (bankApiConfig.shouldRetryOnFailure(BankApiConfig.BankType.CAKE, apiInfo.name) && 
                        retryCount < maxRetries) {
                        
                        // Lấy thời gian chờ giữa các lần thử lại từ cấu hình
                        val retryDelayMs = bankApiConfig.getRetryDelayMs(BankApiConfig.BankType.CAKE, apiInfo.name)
                        
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
                        val maxRetries = bankApiConfig.getMaxRetries(BankApiConfig.BankType.CAKE, apiInfo.name)
                        if (shouldRetryBasedOnResponseCode(responseCode) && 
                            bankApiConfig.shouldRetryOnFailure(BankApiConfig.BankType.CAKE, apiInfo.name) &&
                            retryCount < maxRetries) {
                            
                            // Lấy thời gian chờ giữa các lần thử lại từ cấu hình
                            val retryDelayMs = bankApiConfig.getRetryDelayMs(BankApiConfig.BankType.CAKE, apiInfo.name)
                            
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
        return sharedPreferences.getString("cake_transactions", "[]") ?: "[]"
    }
    
    /**
     * Xóa tất cả giao dịch đã lưu
     */
    fun clearTransactions() {
        sharedPreferences.edit().putString("cake_transactions", "[]").apply()
        Log.d(TAG, "Đã xóa tất cả giao dịch Cake")
    }
}