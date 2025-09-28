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

class MBNotificationHandler(private val context: Context) {
    private val TAG = "MBNotificationHandler"
    private lateinit var sharedPreferences: SharedPreferences
    private val bankApiConfig = BankApiConfig(context)
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    init {
        // Khởi tạo SharedPreferences riêng cho MB Bank
        sharedPreferences = context.getSharedPreferences("mb_transactions", Context.MODE_PRIVATE)
    }

    /**
     * Kiểm tra xem thông báo có phải từ MB Bank không
     */
    fun canHandle(sbn: StatusBarNotification): Boolean {
        return sbn.packageName == "com.mbmobile" && 
               sbn.notification?.extras?.getString("android.title") == "Thông báo biến động số dư"
    }

    /**
     * Xử lý thông báo từ MB Bank
     */
    fun handleNotification(sbn: StatusBarNotification): Boolean {
        try {
            val notification = sbn.notification ?: return false
            val extras = notification.extras ?: return false
            
            // Lấy nội dung thông báo
            val content = extras.getCharSequence("android.bigText")?.toString() 
                ?: extras.getCharSequence("android.text")?.toString()
                ?: return false
            
            Log.d(TAG, "Xử lý thông báo MB Bank: $content")
            
            // Phân tích cú pháp thông báo MB Bank
            // Format giao dịch cộng: TK 03xxx492|GD: +20,000VND 25/09/25 17:47 |SD: 64,368VND|TU: HOANG NGOC DIEP - 0395347492|ND: HOANG NGOC DIEP chuyen tien   Ma giao dich  Trace779644 Trace 779644
            // Format giao dịch trừ: TK 03xxx492|GD: -35,000VND 26/09/25 09:15 |SD: 64,368VND|DEN: HOANG NGOC DIEP - 0395347492|ND: 0001 - Ma giao dich/Trace 723215
            // Format giao dịch MoMo: TK 03xxx492|GD: -50,000VND 27/09/25 18:22 |SD: 19,368VND|ND: MOMO-CASHIN-0395347492-OQCIjtZfWLMW-102134442618
            
            // Trích xuất thông tin tài khoản
            var accountNumber: String? = null
            val accountPattern = Pattern.compile("TK (\\S+)\\|")
            val accountMatcher = accountPattern.matcher(content)
            if (accountMatcher.find()) {
                accountNumber = accountMatcher.group(1)
            }
            
            // Trích xuất số tiền giao dịch
            var amount: String? = null
            var transactionType: String? = null
            val amountPattern = Pattern.compile("GD: ([+-]\\d+,?\\d*VND)")
            val amountMatcher = amountPattern.matcher(content)
            if (amountMatcher.find()) {
                amount = amountMatcher.group(1)
                transactionType = if (amount.startsWith("+")) "receive" else "send"
            }
            
            // Trích xuất thời gian giao dịch
            var transactionTime: String? = null
            val timePattern = Pattern.compile("GD: [+-]\\d+,?\\d*VND (\\d{2}/\\d{2}/\\d{2} \\d{2}:\\d{2})")
            val timeMatcher = timePattern.matcher(content)
            if (timeMatcher.find()) {
                transactionTime = timeMatcher.group(1)
            }
            
            // Trích xuất số dư hiện tại
            var balance: String? = null
            val balancePattern = Pattern.compile("SD: (\\d+,?\\d*VND)")
            val balanceMatcher = balancePattern.matcher(content)
            if (balanceMatcher.find()) {
                balance = balanceMatcher.group(1)
            }
            
            // ĐIỀU KIỆN 1: TIỀN VÀO - Trích xuất thông tin người gửi
            var partner: String? = null
            if (transactionType == "receive") {
                val tuPattern = Pattern.compile("TU:\\s*([^|]+)")
                val tuMatcher = tuPattern.matcher(content)
                if (tuMatcher.find()) {
                    partner = tuMatcher.group(1).trim()
                } else {
                    partner = "Unknown Sender"
                }
            } 
            // ĐIỀU KIỆN 2 & 3: TIỀN RA - Trích xuất thông tin người nhận hoặc đặt mặc định
            else if (transactionType == "send") {
                val denPattern = Pattern.compile("DEN:\\s*([^|]+)")
                val denMatcher = denPattern.matcher(content)
                if (denMatcher.find()) {
                    partner = denMatcher.group(1).trim()
                } else {
                    // Nếu không có trường DEN, thử trích xuất từ nội dung giao dịch
                    // Đối với giao dịch MoMo, thường có định dạng: MOMO-CASHIN-0395347492-...
                    if (content.contains("MOMO")) {
                        val momoPattern = Pattern.compile("MOMO-\\w+-([0-9]+)")
                        val momoMatcher = momoPattern.matcher(content)
                        if (momoMatcher.find()) {
                            partner = "MOMO - " + momoMatcher.group(1).trim()
                        } else {
                            partner = "MOMO Payment"
                        }
                    } else {
                        // Mặc định cho các trường hợp khác
                        partner = "External Recipient"
                    }
                }
            }
            
            // Trích xuất nội dung giao dịch và mã giao dịch
            var description: String? = null
            var transactionId: String? = null
            val descPattern = Pattern.compile("ND: ([^|]+)")
            val descMatcher = descPattern.matcher(content)
            
            if (descMatcher.find()) {
                val fullDescription = descMatcher.group(1).trim()
                
                // Xử lý các trường hợp đặc biệt trước
                if (fullDescription.contains("MOMO")) {
                    // Định dạng MOMO: MOMO-CASHIN-0395347492-OQCIjtZfWLMW-102134442618
                    val momoTransIdPattern = Pattern.compile("MOMO-\\w+-[0-9]+-([\\w-]+)")
                    val momoMatcher = momoTransIdPattern.matcher(fullDescription)
                    if (momoMatcher.find()) {
                        transactionId = momoMatcher.group(1).trim()
                        description = "Chuyển tiền đến ví MOMO"
                    } else {
                        description = fullDescription
                    }
                } else {
                    // Các mẫu khác nhau để tìm và trích xuất mã giao dịch thông thường
                    val transIdPatterns = listOf(
                        Pattern.compile("Ma giao dich[/\\s]+Trace\\s*(\\d+)"),
                        Pattern.compile("Ma giao dich[/\\s]+(\\d+)"),
                        Pattern.compile("Trace\\s*(\\d+)")
                    )
                    
                    var foundTransactionId = false
                    for (pattern in transIdPatterns) {
                        val matcher = pattern.matcher(fullDescription)
                        if (matcher.find()) {
                            // Lấy mã giao dịch thực tế từ kết quả tìm kiếm
                            transactionId = matcher.group(1).trim()
                            foundTransactionId = true
                            
                            // Loại bỏ phần "Ma giao dich/Trace 123456" và các biến thể khỏi nội dung
                            val cleanedDesc = fullDescription.replaceFirst("\\s*Ma giao dich[/\\s]+Trace\\s*\\d+.*$", "")
                                                           .replaceFirst("\\s*Ma giao dich[/\\s]+\\d+.*$", "")
                                                           .replaceFirst("\\s*Trace\\s*\\d+.*$", "")
                                                           .trim()
                            description = cleanedDesc
                            break
                        }
                    }
                    
                    if (!foundTransactionId) {
                        // Nếu không tìm thấy mã giao dịch, sử dụng toàn bộ nội dung
                        description = fullDescription
                    }
                }
            }
            
            // Nếu trích xuất được các thông tin cần thiết
            if (amount != null && balance != null) {
                var processed = false
                
                // Xác định loại giao dịch (tiền vào hay tiền ra)
                val isMoneyIn = transactionType == "receive"
                
                // Tạo ID giao dịch duy nhất nếu không có sẵn
                val uniqueTransactionId = transactionId ?: "${sbn.postTime}_${description?.hashCode() ?: 0}"
                
                // Gọi API dựa trên cấu hình và loại giao dịch
                if (description != null) {
                    processed = callConfiguredApis(amount, description, balance, isMoneyIn, uniqueTransactionId)
                }
                
                // Lưu giao dịch vào SharedPreferences kèm trạng thái xử lý
                saveTransaction(
                    accountNumber ?: "Unknown",
                    amount,
                    transactionType ?: "unknown",
                    balance,
                    partner ?: "Unknown",
                    description ?: "",
                    uniqueTransactionId,
                    transactionTime ?: "",
                    sbn.postTime,
                    processed,
                    null  // Mã phản hồi sẽ được cập nhật sau khi API trả về
                )
                
                return true
            }
            
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi xử lý thông báo MB Bank", e)
            return false
        }
    }

    /**
     * Lưu giao dịch vào SharedPreferences
     */
    private fun saveTransaction(
        account: String,
        amount: String,
        type: String,
        balance: String,
        partner: String,
        description: String,
        transactionId: String,
        transactionTime: String,
        timestamp: Long,
        processed: Boolean,
        responseCode: Int? = null
    ) {
        try {
            // Lấy danh sách giao dịch hiện tại
            val transactionsString = sharedPreferences.getString("mb_transactions", "[]") ?: "[]"
            val transactions = org.json.JSONArray(transactionsString)
            
            // Tạo đối tượng giao dịch mới
            val transaction = JSONObject().apply {
                put("account", account)
                put("amount", amount)
                put("type", type)
                put("balance", balance)
                put("partner", partner)
                put("description", description)
                put("transactionId", transactionId)
                put("transactionTime", transactionTime)
                put("timestamp", timestamp)
                put("processed", processed) // Thêm trường đánh dấu đã xử lý API hay chưa
                put("formattedTime", SimpleDateFormat("yyyy-MM-dd HH:mm:ss", 
                    Locale.getDefault()).format(Date(timestamp)))
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
            sharedPreferences.edit().putString("mb_transactions", updatedTransactions.toString()).apply()
            
            Log.d(TAG, "Đã lưu giao dịch MB Bank: $amount - $description - Đã xử lý: $processed")
        } catch (e: Exception) {
            Log.e(TAG, "Lỗi khi lưu giao dịch MB Bank", e)
        }
    }

    /**
     * Cập nhật mã phản hồi cho giao dịch đã lưu
     */
    private fun updateTransactionResponseCode(transactionId: String, responseCode: Int) {
        try {
            // Lấy danh sách giao dịch hiện tại
            val transactionsString = sharedPreferences.getString("mb_transactions", "[]") ?: "[]"
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
            sharedPreferences.edit().putString("mb_transactions", transactions.toString()).apply()
            
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
            // Lấy danh sách API được cấu hình cho MB Bank
            val apis = bankApiConfig.getAllApis(BankApiConfig.BankType.MB_BANK)
            
            // Lọc các API được bật và phù hợp với loại giao dịch (tiền vào/tiền ra)
            val filteredApis = apis.filter { api -> 
                api.enabled && 
                ((isMoneyIn && api.notifyOnMoneyIn) || (!isMoneyIn && api.notifyOnMoneyOut)) &&
                bankApiConfig.checkConditions(BankApiConfig.BankType.MB_BANK, api.name, content)
            }
            
            if (filteredApis.isEmpty()) {
                Log.d(TAG, "Không có API nào được cấu hình phù hợp với loại giao dịch ${if(isMoneyIn) "tiền vào" else "tiền ra"}")
                return false
            }
            
            // Xử lý số tiền để loại bỏ "VND" và dấu phẩy phân cách
            // Format: +20,000VND hoặc -20,000VND
            val cleanAmount = amount.replace("VND", "")
                                   .replace(",", "")
                                   .replace("+", "")
                                   .replace("-", "")
                                   .trim()
            val amountValue = cleanAmount.toLongOrNull() ?: 0
            
            // Chuẩn bị dữ liệu JSON để gửi
            val requestData = JSONObject().apply {
                put("gateway", "MBBank")
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
                    val maxRetries = bankApiConfig.getMaxRetries(BankApiConfig.BankType.MB_BANK, apiInfo.name)
                    if (bankApiConfig.shouldRetryOnFailure(BankApiConfig.BankType.MB_BANK, apiInfo.name) && 
                        retryCount < maxRetries) {
                        
                        // Lấy thời gian chờ giữa các lần thử lại từ cấu hình
                        val retryDelayMs = bankApiConfig.getRetryDelayMs(BankApiConfig.BankType.MB_BANK, apiInfo.name)
                        
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
                        val maxRetries = bankApiConfig.getMaxRetries(BankApiConfig.BankType.MB_BANK, apiInfo.name)
                        if (shouldRetryBasedOnResponseCode(responseCode) && 
                            bankApiConfig.shouldRetryOnFailure(BankApiConfig.BankType.MB_BANK, apiInfo.name) &&
                            retryCount < maxRetries) {
                            
                            // Lấy thời gian chờ giữa các lần thử lại từ cấu hình
                            val retryDelayMs = bankApiConfig.getRetryDelayMs(BankApiConfig.BankType.MB_BANK, apiInfo.name)
                            
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
        return sharedPreferences.getString("mb_transactions", "[]") ?: "[]"
    }
    
    /**
     * Xóa tất cả giao dịch đã lưu
     */
    fun clearTransactions() {
        sharedPreferences.edit().putString("mb_transactions", "[]").apply()
        Log.d(TAG, "Đã xóa tất cả giao dịch MB Bank")
    }
}