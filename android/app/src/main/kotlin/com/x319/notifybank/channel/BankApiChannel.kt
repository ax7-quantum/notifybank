package com.x319.notifybank.channels

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.x319.notifybank.config.BankApiConfig
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class BankApiChannel(
    private val flutterEngine: FlutterEngine,
    private val bankApiConfig: BankApiConfig,
    private val context: Context
) {
    private val BANK_API_CHANNEL = "com.x319.notifybank/bankapi"
    private val TAG = "BankApiChannel"
    
    // Khởi tạo OkHttpClient với các cấu hình timeout
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    fun setup() {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BANK_API_CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Bank API method call received: ${call.method}")
            try {
                when (call.method) {
                    "addApi" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        val apiUrl = call.argument<String>("apiUrl") ?: throw Exception("API URL is required")
                        val apiKey = call.argument<String>("apiKey") ?: throw Exception("API key is required")
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        val notifyOnMoneyIn = call.argument<Boolean>("notifyOnMoneyIn") ?: true
                        val notifyOnMoneyOut = call.argument<Boolean>("notifyOnMoneyOut") ?: false
                        val retryOnFailure = call.argument<Boolean>("retryOnFailure") ?: true
                        val maxRetries = call.argument<Int>("maxRetries") ?: 3
                        val retryDelayMs = call.argument<Int>("retryDelayMs")?.toLong() ?: 3000L
                        val conditions = call.argument<String>("conditions") ?: ""
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        bankApiConfig.addApi(bankTypeEnum, name, apiUrl, apiKey, enabled, 
                            notifyOnMoneyIn, notifyOnMoneyOut, retryOnFailure, maxRetries, retryDelayMs, conditions)
                        result.success(true)
                        Log.d(TAG, "API added: $name for $bankType with maxRetries=$maxRetries, retryDelayMs=$retryDelayMs")
                    }
                    "updateApi" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        val apiUrl = call.argument<String>("apiUrl") ?: throw Exception("API URL is required")
                        val apiKey = call.argument<String>("apiKey") ?: throw Exception("API key is required")
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        val notifyOnMoneyIn = call.argument<Boolean>("notifyOnMoneyIn") ?: true
                        val notifyOnMoneyOut = call.argument<Boolean>("notifyOnMoneyOut") ?: false
                        val retryOnFailure = call.argument<Boolean>("retryOnFailure") ?: true
                        val maxRetries = call.argument<Int>("maxRetries") ?: 3
                        val retryDelayMs = call.argument<Int>("retryDelayMs")?.toLong() ?: 3000L
                        val conditions = call.argument<String>("conditions") ?: ""
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        bankApiConfig.updateApi(bankTypeEnum, name, apiUrl, apiKey, enabled, 
                            notifyOnMoneyIn, notifyOnMoneyOut, retryOnFailure, maxRetries, retryDelayMs, conditions)
                        result.success(true)
                        Log.d(TAG, "API updated: $name for $bankType with maxRetries=$maxRetries, retryDelayMs=$retryDelayMs")
                    }
                    "removeApi" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        bankApiConfig.removeApi(bankTypeEnum, name)
                        result.success(true)
                        Log.d(TAG, "API removed: $name from $bankType")
                    }
                    "setApiEnabled" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        bankApiConfig.setApiEnabled(bankTypeEnum, name, enabled)
                        result.success(true)
                        Log.d(TAG, "API ${if (enabled) "enabled" else "disabled"}: $name for $bankType")
                    }
                    "updateNotificationSettings" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        val notifyOnMoneyIn = call.argument<Boolean>("notifyOnMoneyIn") ?: true
                        val notifyOnMoneyOut = call.argument<Boolean>("notifyOnMoneyOut") ?: false
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        bankApiConfig.updateNotificationSettings(bankTypeEnum, name, notifyOnMoneyIn, notifyOnMoneyOut)
                        result.success(true)
                        Log.d(TAG, "Notification settings updated for API: $name of $bankType")
                    }
                    "updateRetryOnFailureSetting" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        val retryOnFailure = call.argument<Boolean>("retryOnFailure") ?: true
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        bankApiConfig.updateRetryOnFailureSetting(bankTypeEnum, name, retryOnFailure)
                        result.success(true)
                        Log.d(TAG, "Retry on failure setting updated for API: $name of $bankType")
                    }
                    "updateRetryConfig" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        val retryOnFailure = call.argument<Boolean>("retryOnFailure") ?: true
                        val maxRetries = call.argument<Int>("maxRetries") ?: 3
                        val retryDelayMs = call.argument<Int>("retryDelayMs")?.toLong() ?: 3000L
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        bankApiConfig.updateRetryConfig(bankTypeEnum, name, retryOnFailure, maxRetries, retryDelayMs)
                        result.success(true)
                        Log.d(TAG, "Retry config updated for API: $name of $bankType with maxRetries=$maxRetries, retryDelayMs=$retryDelayMs")
                    }
                    "updateConditions" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        val conditions = call.argument<String>("conditions") ?: ""
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        bankApiConfig.updateConditions(bankTypeEnum, name, conditions)
                        result.success(true)
                        Log.d(TAG, "Conditions updated for API: $name of $bankType")
                    }
                    "checkConditions" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        val transactionContent = call.argument<String>("transactionContent") ?: ""
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        val conditionsMet = bankApiConfig.checkConditions(bankTypeEnum, name, transactionContent)
                        result.success(conditionsMet)
                        Log.d(TAG, "Conditions check for API: $name of $bankType, result: $conditionsMet")
                    }
                    "getAllApis" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        
                        val apiList = bankApiConfig.getAllApis(bankTypeEnum)
                        val jsonArray = JSONArray()
                        
                        for (api in apiList) {
                            val jsonObject = JSONObject()
                            jsonObject.put("name", api.name)
                            jsonObject.put("url", api.url)
                            jsonObject.put("key", api.key)
                            jsonObject.put("enabled", api.enabled)
                            jsonObject.put("notifyOnMoneyIn", api.notifyOnMoneyIn)
                            jsonObject.put("notifyOnMoneyOut", api.notifyOnMoneyOut)
                            jsonObject.put("retryOnFailure", api.retryOnFailure)
                            jsonObject.put("maxRetries", api.maxRetries)
                            jsonObject.put("retryDelayMs", api.retryDelayMs)
                            jsonObject.put("conditions", api.conditions)
                            jsonArray.put(jsonObject)
                        }
                        
                        result.success(jsonArray.toString())
                        Log.d(TAG, "All APIs retrieved for $bankType, count: ${apiList.size}")
                    }
                    "getApi" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        val api = bankApiConfig.getApi(bankTypeEnum, name)
                        
                        if (api != null) {
                            val jsonObject = JSONObject()
                            jsonObject.put("name", api.name)
                            jsonObject.put("url", api.url)
                            jsonObject.put("key", api.key)
                            jsonObject.put("enabled", api.enabled)
                            jsonObject.put("notifyOnMoneyIn", api.notifyOnMoneyIn)
                            jsonObject.put("notifyOnMoneyOut", api.notifyOnMoneyOut)
                            jsonObject.put("retryOnFailure", api.retryOnFailure)
                            jsonObject.put("maxRetries", api.maxRetries)
                            jsonObject.put("retryDelayMs", api.retryDelayMs)
                            jsonObject.put("conditions", api.conditions)
                            
                            result.success(jsonObject.toString())
                            Log.d(TAG, "API retrieved: $name for $bankType")
                        } else {
                            result.success(null)
                            Log.d(TAG, "API not found: $name for $bankType")
                        }
                    }
                    "getRetryConfig" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        val maxRetries = bankApiConfig.getMaxRetries(bankTypeEnum, name)
                        val retryDelayMs = bankApiConfig.getRetryDelayMs(bankTypeEnum, name)
                        val retryOnFailure = bankApiConfig.shouldRetryOnFailure(bankTypeEnum, name)
                        
                        val jsonObject = JSONObject()
                        jsonObject.put("retryOnFailure", retryOnFailure)
                        jsonObject.put("maxRetries", maxRetries)
                        jsonObject.put("retryDelayMs", retryDelayMs)
                        
                        result.success(jsonObject.toString())
                        Log.d(TAG, "Retry config retrieved for API: $name of $bankType")
                    }
                    "shouldNotify" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val name = call.argument<String>("name") ?: throw Exception("API name is required")
                        val isMoneyIn = call.argument<Boolean>("isMoneyIn") ?: true
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        val shouldNotify = bankApiConfig.shouldNotify(bankTypeEnum, name, isMoneyIn)
                        
                        result.success(shouldNotify)
                        Log.d(TAG, "Should notify check for API: $name of $bankType, isMoneyIn: $isMoneyIn, result: $shouldNotify")
                    }
                    "testApi" -> {
                        val apiUrl = call.argument<String>("apiUrl") ?: throw Exception("API URL is required")
                        val apiKey = call.argument<String>("apiKey") ?: throw Exception("API key is required")
                        val jsonBody = call.argument<String>("jsonBody") ?: throw Exception("JSON body is required")
                        
                        // Thực hiện request bất đồng bộ để không chặn UI thread
                        Thread {
                            try {
                                val mediaType = "application/json; charset=utf-8".toMediaType()
                                val requestBody = jsonBody.toRequestBody(mediaType)
                                
                                val request = Request.Builder()
                                    .url(apiUrl)
                                    .addHeader("Content-Type", "application/json")
                                    .addHeader("Authorization", "Apikey $apiKey")
                                    .post(requestBody)
                                    .build()
                                    
                                val response = client.newCall(request).execute()
                                val responseCode = response.code
                                val responseBody = response.body?.string() ?: ""
                                
                                // Gửi kết quả về Flutter
                                val resultMap = mapOf(
                                    "statusCode" to responseCode,
                                    "body" to responseBody
                                )
                                
                                // Chuyển sang main thread để gọi result.success
                                Handler(Looper.getMainLooper()).post {
                                    result.success(JSONObject(resultMap).toString())
                                    Log.d(TAG, "API test completed with status code: $responseCode")
                                }
                            } catch (e: Exception) {
                                // Chuyển sang main thread để gọi result.error
                                Handler(Looper.getMainLooper()).post {
                                    result.error("API_TEST_ERROR", e.message, e.stackTraceToString())
                                    Log.e(TAG, "Error in API test", e)
                                }
                            }
                        }.start()
                    }
                    "processTransaction" -> {
                        val bankType = call.argument<String>("bankType") ?: throw Exception("Bank type is required")
                        val transactionContent = call.argument<String>("transactionContent") ?: ""
                        val amount = call.argument<Long>("amount") ?: 0L
                        val isMoneyIn = call.argument<Boolean>("isMoneyIn") ?: true
                        val transactionData = call.argument<String>("transactionData") ?: "{}"
                        
                        val bankTypeEnum = BankApiConfig.BankType.valueOf(bankType)
                        val apiList = bankApiConfig.getAllApis(bankTypeEnum)
                        val results = JSONArray()
                        
                        // Xử lý giao dịch cho tất cả API được bật và thỏa mãn điều kiện
                        for (api in apiList) {
                            if (!api.enabled) continue
                            
                            // Kiểm tra điều kiện thông báo
                            val shouldNotify = if (isMoneyIn) api.notifyOnMoneyIn else api.notifyOnMoneyOut
                            if (!shouldNotify) continue
                            
                            // Kiểm tra điều kiện nội dung
                            if (!bankApiConfig.checkConditions(bankTypeEnum, api.name, transactionContent)) continue
                            
                            val apiResult = JSONObject()
                            apiResult.put("name", api.name)
                            apiResult.put("shouldProcess", true)
                            results.put(apiResult)
                        }
                        
                        result.success(results.toString())
                        Log.d(TAG, "Transaction processed for $bankType, matching APIs: ${results.length()}")
                    }
                    "getAllTransactions" -> {
                        // Tạo một thread riêng để không chặn UI thread khi truy vấn dữ liệu
                        Thread {
                            try {
                                // Lấy SharedPreferences để đọc dữ liệu giao dịch
                                val sharedPreferences = context.getSharedPreferences("transaction_data", Context.MODE_PRIVATE)
                                
                                // Tạo JSON response
                                val response = JSONObject()
                                
                                // Đọc số lượng giao dịch từ SharedPreferences
                                val mbBankCount = sharedPreferences.getInt("MB_BANK_COUNT", 0)
                                val cakeCount = sharedPreferences.getInt("CAKE_COUNT", 0)
                                val momoCount = sharedPreferences.getInt("MOMO_COUNT", 0)
                                val totalCount = mbBankCount + cakeCount + momoCount
                                
                                // Thêm thông tin tổng hợp số lượng giao dịch
                                val summary = JSONObject()
                                summary.put("MB_BANK", mbBankCount)
                                summary.put("CAKE", cakeCount)
                                summary.put("MOMO", momoCount)
                                summary.put("TOTAL", totalCount)
                                response.put("summary", summary)
                                
                                // CHỈ thêm thông tin giao dịch mới nhất nếu có ít nhất một giao dịch
                                if (totalCount > 0) {
                                    // Đọc thông tin về giao dịch mới nhất từ SharedPreferences
                                    val latestBankType = sharedPreferences.getString("LATEST_BANK_TYPE", "MB_BANK") ?: "MB_BANK"
                                    
                                    // Đọc thời gian giao dịch thực tế từ SharedPreferences
                                    // Nếu không có, sử dụng thời gian hiện tại
                                    val latestTimestamp = sharedPreferences.getLong("LATEST_TRANSACTION_TIME", System.currentTimeMillis())
                                    
                                    // Thêm thông tin giao dịch mới nhất
                                    val latestTransaction = JSONObject()
                                    latestTransaction.put("bankType", latestBankType)
                                    latestTransaction.put("timestamp", latestTimestamp) // Sử dụng thời gian thực tế từ SharedPreferences
                                    
                                    response.put("latestTransaction", latestTransaction)
                                }
                                // Nếu không có giao dịch nào, không thêm thông tin "latestTransaction" vào response
                                
                                // Chuyển về main thread để trả kết quả
                                Handler(Looper.getMainLooper()).post {
                                    result.success(response.toString())
                                    Log.d(TAG, "Đã lấy thông tin tổng số giao dịch" + (if (totalCount > 0) " và giao dịch mới nhất" else ""))
                                }
                            } catch (e: Exception) {
                                Handler(Looper.getMainLooper()).post {
                                    result.error("TRANSACTION_ERROR", e.message, e.stackTraceToString())
                                    Log.e(TAG, "Lỗi khi lấy thông tin giao dịch", e)
                                }
                            }
                        }.start()
                    }
                    else -> {
                        result.notImplemented()
                        Log.d(TAG, "Bank API method not implemented: ${call.method}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in Bank API method call: ${call.method}", e)
                result.error("API_ERROR", e.message, e.stackTraceToString())
            }
        }
    }
}
