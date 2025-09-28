package com.x319.notifybank

import android.content.ContentProviderOperation
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date

class ContactsManager(private val context: Context) {
    private val TAG = "ContactsManager"
    private val sharedPreferences = context.getSharedPreferences("contacts_preferences", Context.MODE_PRIVATE)
    
    /**
     * Lấy tất cả danh bạ từ thiết bị với phân trang
     * @param offset Vị trí bắt đầu
     * @param limit Số lượng liên hệ tối đa muốn lấy
     * @return JSONArray Danh sách các liên hệ theo phân trang
     */
    fun getAllContacts(offset: Int = 0, limit: Int = 30): JSONArray {
        val result = JSONArray()
        val contentResolver = context.contentResolver
        
        try {
            // Truy vấn danh bạ với phân trang
            val cursor = contentResolver.query(
                ContactsContract.Contacts.CONTENT_URI,
                null,
                null,
                null,
                ContactsContract.Contacts.DISPLAY_NAME + " ASC LIMIT $limit OFFSET $offset"
            )
            
            cursor?.use {
                while (it.moveToNext()) {
                    val contact = getContactFromCursor(it, contentResolver)
                    result.put(contact)
                }
            }
            
            Log.d(TAG, "Retrieved ${result.length()} contacts (offset: $offset, limit: $limit)")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting contacts: ${e.message}", e)
        }
        
        return result
    }
    
    /**
     * Lấy tổng số liên hệ trong danh bạ
     * @return Int Tổng số liên hệ
     */
    fun getTotalContactsCount(): Int {
        var count = 0
        val contentResolver = context.contentResolver
        
        try {
            val cursor = contentResolver.query(
                ContactsContract.Contacts.CONTENT_URI,
                arrayOf(ContactsContract.Contacts._ID),
                null,
                null,
                null
            )
            
            cursor?.use {
                count = it.count
            }
            
            Log.d(TAG, "Total contacts count: $count")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting total contacts count: ${e.message}", e)
        }
        
        return count
    }
    
    /**
     * Tìm kiếm danh bạ theo tên hoặc số điện thoại với phân trang
     * @param query Chuỗi tìm kiếm
     * @param offset Vị trí bắt đầu
     * @param limit Số lượng liên hệ tối đa muốn lấy
     * @return JSONArray Danh sách các liên hệ phù hợp
     */
    fun searchContacts(query: String, offset: Int = 0, limit: Int = 30): JSONArray {
        val result = JSONArray()
        val contentResolver = context.contentResolver
        val contactIds = mutableSetOf<String>()
        
        try {
            // Tìm kiếm theo tên
            val selection = "${ContactsContract.Contacts.DISPLAY_NAME} LIKE ?"
            val selectionArgs = arrayOf("%$query%")
            
            val cursor = contentResolver.query(
                ContactsContract.Contacts.CONTENT_URI,
                null,
                selection,
                selectionArgs,
                ContactsContract.Contacts.DISPLAY_NAME + " ASC LIMIT $limit OFFSET $offset"
            )
            
            cursor?.use {
                while (it.moveToNext()) {
                    val contact = getContactFromCursor(it, contentResolver)
                    result.put(contact)
                    contactIds.add(contact.getString("id"))
                }
            }
            
            // Nếu kết quả tìm theo tên chưa đủ limit, tiếp tục tìm theo số điện thoại
            if (result.length() < limit) {
                val remainingLimit = limit - result.length()
                val phoneCursor = contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    null,
                    "${ContactsContract.CommonDataKinds.Phone.NUMBER} LIKE ?",
                    arrayOf("%$query%"),
                    null
                )
                
                phoneCursor?.use {
                    while (it.moveToNext() && result.length() < limit) {
                        val contactId = it.getString(it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID))
                        
                        // Chỉ thêm nếu chưa có trong kết quả
                        if (!contactIds.contains(contactId)) {
                            val contactCursor = contentResolver.query(
                                ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, contactId.toLong()),
                                null,
                                null,
                                null,
                                null
                            )
                            
                            contactCursor?.use { cc ->
                                if (cc.moveToFirst()) {
                                    val contact = getContactFromCursor(cc, contentResolver)
                                    result.put(contact)
                                    contactIds.add(contactId)
                                }
                            }
                        }
                    }
                }
            }
            
            Log.d(TAG, "Search for '$query' returned ${result.length()} contacts (offset: $offset, limit: $limit)")
        } catch (e: Exception) {
            Log.e(TAG, "Error searching contacts: ${e.message}", e)
        }
        
        return result
    }
    
    /**
     * Lấy thông tin liên hệ theo ID
     * @param contactId ID của liên hệ
     * @return String Thông tin liên hệ dạng JSON
     */
    fun getContactById(contactId: String): String {
        val contentResolver = context.contentResolver
        
        try {
            val uri = ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, contactId.toLong())
            val cursor = contentResolver.query(uri, null, null, null, null)
            
            cursor?.use {
                if (it.moveToFirst()) {
                    val contact = getContactFromCursor(it, contentResolver)
                    return contact.toString()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting contact by ID: ${e.message}", e)
        }
        
        return "{}"
    }
    
    /**
     * Lấy thông tin liên hệ theo số điện thoại
     * @param phoneNumber Số điện thoại cần tìm
     * @return String Thông tin liên hệ dạng JSON
     */
    fun getContactByPhoneNumber(phoneNumber: String): String {
        val contentResolver = context.contentResolver
        val normalizedNumber = normalizePhoneNumber(phoneNumber)
        
        try {
            val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
            val selection = "${ContactsContract.CommonDataKinds.Phone.NUMBER} LIKE ?"
            val selectionArgs = arrayOf("%$normalizedNumber%")
            
            val cursor = contentResolver.query(uri, null, selection, selectionArgs, null)
            
            cursor?.use {
                if (it.moveToFirst()) {
                    val contactId = it.getString(it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID))
                    return getContactById(contactId)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting contact by phone number: ${e.message}", e)
        }
        
        return "{}"
    }
    
    /**
     * Lưu một liên hệ mới vào danh bạ
     * @param contact Thông tin liên hệ dạng JSONObject
     * @return Boolean Trả về true nếu lưu thành công
     */
    fun saveContact(contact: JSONObject): Boolean {
        try {
            val operations = ArrayList<ContentProviderOperation>()
            
            // Tạo liên hệ mới
            operations.add(
                ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                    .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
                    .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null)
                    .build()
            )
            
            // Thêm tên
            operations.add(
                ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                    .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                    .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
                    .withValue(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, contact.getString("name"))
                    .build()
            )
            
            // Thêm số điện thoại
            if (contact.has("phoneNumbers") && contact.getJSONArray("phoneNumbers").length() > 0) {
                val phoneNumbers = contact.getJSONArray("phoneNumbers")
                for (i in 0 until phoneNumbers.length()) {
                    val phoneNumber = phoneNumbers.getJSONObject(i)
                    operations.add(
                        ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                            .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                            .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                            .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, phoneNumber.getString("number"))
                            .withValue(ContactsContract.CommonDataKinds.Phone.TYPE, getPhoneType(phoneNumber.optString("type", "mobile")))
                            .build()
                    )
                }
            }
            
            // Thêm email (nếu có)
            if (contact.has("emails") && contact.getJSONArray("emails").length() > 0) {
                val emails = contact.getJSONArray("emails")
                for (i in 0 until emails.length()) {
                    val email = emails.getJSONObject(i)
                    operations.add(
                        ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                            .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                            .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE)
                            .withValue(ContactsContract.CommonDataKinds.Email.ADDRESS, email.getString("address"))
                            .withValue(ContactsContract.CommonDataKinds.Email.TYPE, getEmailType(email.optString("type", "home")))
                            .build()
                    )
                }
            }
            
            // Thêm địa chỉ (nếu có)
            if (contact.has("address")) {
                val address = contact.getString("address")
                operations.add(
                    ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                        .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredPostal.CONTENT_ITEM_TYPE)
                        .withValue(ContactsContract.CommonDataKinds.StructuredPostal.FORMATTED_ADDRESS, address)
                        .withValue(ContactsContract.CommonDataKinds.StructuredPostal.TYPE, ContactsContract.CommonDataKinds.StructuredPostal.TYPE_HOME)
                        .build()
                )
            }
            
            // Thêm ghi chú (nếu có)
            if (contact.has("note")) {
                val note = contact.getString("note")
                operations.add(
                    ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                        .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Note.CONTENT_ITEM_TYPE)
                        .withValue(ContactsContract.CommonDataKinds.Note.NOTE, note)
                        .build()
                )
            }
            
            // Thực hiện các thao tác
            context.contentResolver.applyBatch(ContactsContract.AUTHORITY, operations)
            
            Log.d(TAG, "Contact saved successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error saving contact: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Cập nhật thông tin liên hệ
     * @param contactId ID của liên hệ cần cập nhật
     * @param contact Thông tin liên hệ mới dạng JSONObject
     * @return Boolean Trả về true nếu cập nhật thành công
     */
    fun updateContact(contactId: String, contact: JSONObject): Boolean {
        try {
            val operations = ArrayList<ContentProviderOperation>()
            val rawContactId = getRawContactId(contactId)
            
            // Cập nhật tên
            if (contact.has("name")) {
                val where = "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?"
                val whereArgs = arrayOf(rawContactId.toString(), ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
                
                operations.add(
                    ContentProviderOperation.newUpdate(ContactsContract.Data.CONTENT_URI)
                        .withSelection(where, whereArgs)
                        .withValue(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, contact.getString("name"))
                        .build()
                )
            }
            
            // Cập nhật số điện thoại
            if (contact.has("phoneNumbers")) {
                // Xóa tất cả số điện thoại hiện tại
                operations.add(
                    ContentProviderOperation.newDelete(ContactsContract.Data.CONTENT_URI)
                        .withSelection(
                            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
                            arrayOf(rawContactId.toString(), ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                        )
                        .build()
                )
                
                // Thêm các số điện thoại mới
                val phoneNumbers = contact.getJSONArray("phoneNumbers")
                for (i in 0 until phoneNumbers.length()) {
                    val phoneNumber = phoneNumbers.getJSONObject(i)
                    operations.add(
                        ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                            .withValue(ContactsContract.Data.RAW_CONTACT_ID, rawContactId)
                            .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                            .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, phoneNumber.getString("number"))
                            .withValue(ContactsContract.CommonDataKinds.Phone.TYPE, getPhoneType(phoneNumber.optString("type", "mobile")))
                            .build()
                    )
                }
            }
            
            // Cập nhật email (nếu có)
            if (contact.has("emails")) {
                // Xóa tất cả email hiện tại
                operations.add(
                    ContentProviderOperation.newDelete(ContactsContract.Data.CONTENT_URI)
                        .withSelection(
                            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
                            arrayOf(rawContactId.toString(), ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE)
                        )
                        .build()
                )
                
                // Thêm các email mới
                val emails = contact.getJSONArray("emails")
                for (i in 0 until emails.length()) {
                    val email = emails.getJSONObject(i)
                    operations.add(
                        ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                            .withValue(ContactsContract.Data.RAW_CONTACT_ID, rawContactId)
                            .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE)
                            .withValue(ContactsContract.CommonDataKinds.Email.ADDRESS, email.getString("address"))
                            .withValue(ContactsContract.CommonDataKinds.Email.TYPE, getEmailType(email.optString("type", "home")))
                            .build()
                    )
                }
            }
            
            // Cập nhật địa chỉ (nếu có)
            if (contact.has("address")) {
                // Xóa tất cả địa chỉ hiện tại
                operations.add(
                    ContentProviderOperation.newDelete(ContactsContract.Data.CONTENT_URI)
                        .withSelection(
                            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
                            arrayOf(rawContactId.toString(), ContactsContract.CommonDataKinds.StructuredPostal.CONTENT_ITEM_TYPE)
                        )
                        .build()
                )
                
                // Thêm địa chỉ mới
                val address = contact.getString("address")
                operations.add(
                    ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValue(ContactsContract.Data.RAW_CONTACT_ID, rawContactId)
                        .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredPostal.CONTENT_ITEM_TYPE)
                        .withValue(ContactsContract.CommonDataKinds.StructuredPostal.FORMATTED_ADDRESS, address)
                        .withValue(ContactsContract.CommonDataKinds.StructuredPostal.TYPE, ContactsContract.CommonDataKinds.StructuredPostal.TYPE_HOME)
                        .build()
                )
            }
            
            // Cập nhật ghi chú (nếu có)
            if (contact.has("note")) {
                // Xóa tất cả ghi chú hiện tại
                operations.add(
                    ContentProviderOperation.newDelete(ContactsContract.Data.CONTENT_URI)
                        .withSelection(
                            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
                            arrayOf(rawContactId.toString(), ContactsContract.CommonDataKinds.Note.CONTENT_ITEM_TYPE)
                        )
                        .build()
                )
                
                // Thêm ghi chú mới
                val note = contact.getString("note")
                operations.add(
                    ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValue(ContactsContract.Data.RAW_CONTACT_ID, rawContactId)
                        .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Note.CONTENT_ITEM_TYPE)
                        .withValue(ContactsContract.CommonDataKinds.Note.NOTE, note)
                        .build()
                )
            }
            
            // Thực hiện các thao tác
            context.contentResolver.applyBatch(ContactsContract.AUTHORITY, operations)
            
            Log.d(TAG, "Contact updated successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error updating contact: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Xóa một liên hệ
     * @param contactId ID của liên hệ cần xóa
     * @return Boolean Trả về true nếu xóa thành công
     */
    fun deleteContact(contactId: String): Boolean {
        try {
            val contentResolver = context.contentResolver
            val uri = ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, contactId.toLong())
            
            val deletedRows = contentResolver.delete(uri, null, null)
            
            // Xóa khỏi danh sách yêu thích và gần đây
            removeFromFavorites(contactId)
            removeFromRecent(contactId)
            
            Log.d(TAG, "Contact deleted: $deletedRows rows affected")
            return deletedRows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting contact: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Thêm liên hệ vào danh sách yêu thích
     * @param contactId ID của liên hệ
     * @return Boolean Trả về true nếu thêm thành công
     */
    fun addToFavorites(contactId: String): Boolean {
        try {
            val favoritesJson = sharedPreferences.getString("favorites", "[]") ?: "[]"
            val favoritesArray = JSONArray(favoritesJson)
            
            // Kiểm tra xem liên hệ đã có trong danh sách yêu thích chưa
            for (i in 0 until favoritesArray.length()) {
                if (favoritesArray.getString(i) == contactId) {
                    // Đã có trong danh sách
                    return true
                }
            }
            
            // Thêm vào danh sách yêu thích
            favoritesArray.put(contactId)
            sharedPreferences.edit().putString("favorites", favoritesArray.toString()).apply()
            
            Log.d(TAG, "Contact added to favorites: $contactId")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error adding contact to favorites: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Xóa liên hệ khỏi danh sách yêu thích
     * @param contactId ID của liên hệ
     * @return Boolean Trả về true nếu xóa thành công
     */
    fun removeFromFavorites(contactId: String): Boolean {
        try {
            val favoritesJson = sharedPreferences.getString("favorites", "[]") ?: "[]"
            val favoritesArray = JSONArray(favoritesJson)
            val newFavoritesArray = JSONArray()
            
            // Tạo danh sách mới không chứa contactId
            for (i in 0 until favoritesArray.length()) {
                val id = favoritesArray.getString(i)
                if (id != contactId) {
                    newFavoritesArray.put(id)
                }
            }
            
            // Lưu danh sách mới
            sharedPreferences.edit().putString("favorites", newFavoritesArray.toString()).apply()
            
            Log.d(TAG, "Contact removed from favorites: $contactId")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error removing contact from favorites: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Lấy danh sách liên hệ yêu thích với phân trang
     * @param offset Vị trí bắt đầu
     * @param limit Số lượng liên hệ tối đa muốn lấy
     * @return JSONArray Danh sách các liên hệ yêu thích
     */
    fun getFavorites(offset: Int = 0, limit: Int = 30): JSONArray {
        val result = JSONArray()
        
        try {
            val favoritesJson = sharedPreferences.getString("favorites", "[]") ?: "[]"
            val favoritesArray = JSONArray(favoritesJson)
            
            // Tính toán phạm vi liên hệ cần lấy
            val endIndex = Math.min(offset + limit, favoritesArray.length())
            val startIndex = Math.min(offset, endIndex)
            
            for (i in startIndex until endIndex) {
                val contactId = favoritesArray.getString(i)
                val contactJson = getContactById(contactId)
                
                if (contactJson != "{}") {
                    result.put(JSONObject(contactJson))
                } else {
                    // Nếu không tìm thấy liên hệ, có thể đã bị xóa, loại bỏ khỏi danh sách yêu thích
                    removeFromFavorites(contactId)
                }
            }
            
            Log.d(TAG, "Retrieved ${result.length()} favorite contacts (offset: $offset, limit: $limit)")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting favorites: ${e.message}", e)
        }
        
        return result
    }
    
    /**
     * Thêm liên hệ vào danh sách gần đây
     * @param contactId ID của liên hệ
     * @return Boolean Trả về true nếu thêm thành công
     */
    fun addToRecent(contactId: String): Boolean {
        try {
            val recentJson = sharedPreferences.getString("recent_contacts", "[]") ?: "[]"
            val recentArray = JSONArray(recentJson)
            val newRecentArray = JSONArray()
            
            // Thêm contactId vào đầu danh sách
            newRecentArray.put(contactId)
            
            // Thêm các ID khác, bỏ qua nếu trùng với contactId
            for (i in 0 until recentArray.length()) {
                val id = recentArray.getString(i)
                if (id != contactId) {
                    newRecentArray.put(id)
                }
            }
            
            // Giới hạn số lượng liên hệ gần đây
            val maxRecentSize = 20
            val finalArray = if (newRecentArray.length() > maxRecentSize) {
                val tempArray = JSONArray()
                for (i in 0 until maxRecentSize) {
                    tempArray.put(newRecentArray.getString(i))
                }
                tempArray
            } else {
                newRecentArray
            }
            
            // Lưu danh sách mới
            sharedPreferences.edit().putString("recent_contacts", finalArray.toString()).apply()
            
            Log.d(TAG, "Contact added to recent: $contactId")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error adding contact to recent: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Xóa liên hệ khỏi danh sách gần đây
     * @param contactId ID của liên hệ
     * @return Boolean Trả về true nếu xóa thành công
     */
    private fun removeFromRecent(contactId: String): Boolean {
        try {
            val recentJson = sharedPreferences.getString("recent_contacts", "[]") ?: "[]"
            val recentArray = JSONArray(recentJson)
            val newRecentArray = JSONArray()
            
            // Tạo danh sách mới không chứa contactId
            for (i in 0 until recentArray.length()) {
                val id = recentArray.getString(i)
                if (id != contactId) {
                    newRecentArray.put(id)
                }
            }
            
            // Lưu danh sách mới
            sharedPreferences.edit().putString("recent_contacts", newRecentArray.toString()).apply()
            
            Log.d(TAG, "Contact removed from recent: $contactId")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error removing contact from recent: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Lấy danh sách liên hệ gần đây với phân trang
     * @param offset Vị trí bắt đầu
     * @param limit Số lượng liên hệ tối đa muốn lấy
     * @return JSONArray Danh sách các liên hệ gần đây
     */
    fun getRecentContacts(offset: Int = 0, limit: Int = 10): JSONArray {
        val result = JSONArray()
        
        try {
            val recentJson = sharedPreferences.getString("recent_contacts", "[]") ?: "[]"
            val recentArray = JSONArray(recentJson)
            
            // Tính toán phạm vi liên hệ cần lấy
            val endIndex = Math.min(offset + limit, recentArray.length())
            val startIndex = Math.min(offset, endIndex)
            
            for (i in startIndex until endIndex) {
                val contactId = recentArray.getString(i)
                val contactJson = getContactById(contactId)
                
                if (contactJson != "{}") {
                    result.put(JSONObject(contactJson))
                } else {
                    // Nếu không tìm thấy liên hệ, có thể đã bị xóa, loại bỏ khỏi danh sách gần đây
                    removeFromRecent(contactId)
                }
            }
            
            Log.d(TAG, "Retrieved ${result.length()} recent contacts (offset: $offset, limit: $limit)")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting recent contacts: ${e.message}", e)
        }
        
        return result
    }
    
    /**
     * Xóa danh sách liên hệ gần đây
     * @return Boolean Trả về true nếu xóa thành công
     */
    fun clearRecent(): Boolean {
        return try {
            sharedPreferences.edit().putString("recent_contacts", "[]").apply()
            Log.d(TAG, "Recent contacts cleared")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing recent contacts: ${e.message}", e)
            false
        }
    }
    
    /**
     * Lấy thông tin liên hệ từ Cursor
     * @param cursor Cursor đang trỏ đến một liên hệ
     * @param contentResolver ContentResolver để truy vấn thêm thông tin
     * @return JSONObject Thông tin liên hệ dạng JSON
     */
    private fun getContactFromCursor(cursor: Cursor, contentResolver: ContentResolver): JSONObject {
        val contactObject = JSONObject()
        
        try {
            val idColumnIndex = cursor.getColumnIndex(ContactsContract.Contacts._ID)
            val nameColumnIndex = cursor.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME)
            val hasPhoneColumnIndex = cursor.getColumnIndex(ContactsContract.Contacts.HAS_PHONE_NUMBER)
            
            if (idColumnIndex != -1 && nameColumnIndex != -1 && hasPhoneColumnIndex != -1) {
                val contactId = cursor.getString(idColumnIndex)
                val contactName = cursor.getString(nameColumnIndex) ?: ""
                val hasPhone = cursor.getInt(hasPhoneColumnIndex) > 0
                
                contactObject.put("id", contactId)
                contactObject.put("name", contactName)
                
                // Lấy danh sách số điện thoại
                val phoneNumbers = JSONArray()
                if (hasPhone) {
                    val phoneCursor = contentResolver.query(
                        ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                        null,
                        ContactsContract.CommonDataKinds.Phone.CONTACT_ID + " = ?",
                        arrayOf(contactId),
                        null
                    )
                    
                    phoneCursor?.use {
                        while (it.moveToNext()) {
                            val phoneNumberColumnIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                            val phoneTypeColumnIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.TYPE)
                            
                            if (phoneNumberColumnIndex != -1 && phoneTypeColumnIndex != -1) {
                                val phoneNumber = it.getString(phoneNumberColumnIndex)
                                val phoneType = it.getInt(phoneTypeColumnIndex)
                                
                                val phoneObject = JSONObject()
                                phoneObject.put("number", phoneNumber)
                                phoneObject.put("type", getPhoneTypeString(phoneType))
                                phoneNumbers.put(phoneObject)
                            }
                        }
                    }
                }
                contactObject.put("phoneNumbers", phoneNumbers)
                
                // Lấy danh sách email
                val emails = JSONArray()
                val emailCursor = contentResolver.query(
                    ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                    null,
                    ContactsContract.CommonDataKinds.Email.CONTACT_ID + " = ?",
                    arrayOf(contactId),
                    null
                )
                
                emailCursor?.use {
                    while (it.moveToNext()) {
                        val emailColumnIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Email.ADDRESS)
                        val emailTypeColumnIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Email.TYPE)
                        
                        if (emailColumnIndex != -1 && emailTypeColumnIndex != -1) {
                            val email = it.getString(emailColumnIndex)
                            val emailType = it.getInt(emailTypeColumnIndex)
                            
                            val emailObject = JSONObject()
                            emailObject.put("address", email)
                            emailObject.put("type", getEmailTypeString(emailType))
                            emails.put(emailObject)
                        }
                    }
                }
                contactObject.put("emails", emails)
                
                // Lấy địa chỉ
                val addressCursor = contentResolver.query(
                    ContactsContract.CommonDataKinds.StructuredPostal.CONTENT_URI,
                    null,
                    ContactsContract.CommonDataKinds.StructuredPostal.CONTACT_ID + " = ?",
                    arrayOf(contactId),
                    null
                )
                
                addressCursor?.use {
                    if (it.moveToFirst()) {
                        val addressColumnIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.StructuredPostal.FORMATTED_ADDRESS)
                        if (addressColumnIndex != -1) {
                            val address = it.getString(addressColumnIndex)
                            contactObject.put("address", address)
                        }
                    }
                }
                
                // Lấy ghi chú
                val noteCursor = contentResolver.query(
                    ContactsContract.Data.CONTENT_URI,
                    null,
                    ContactsContract.Data.CONTACT_ID + " = ? AND " + ContactsContract.Data.MIMETYPE + " = ?",
                    arrayOf(contactId, ContactsContract.CommonDataKinds.Note.CONTENT_ITEM_TYPE),
                    null
                )
                
                noteCursor?.use {
                    if (it.moveToFirst()) {
                        val noteColumnIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Note.NOTE)
                        if (noteColumnIndex != -1) {
                            val note = it.getString(noteColumnIndex)
                            contactObject.put("note", note)
                        }
                    }
                }
                
                // Kiểm tra xem liên hệ có trong danh sách yêu thích không
                val favoritesJson = sharedPreferences.getString("favorites", "[]") ?: "[]"
                val favoritesArray = JSONArray(favoritesJson)
                var isFavorite = false
                
                for (i in 0 until favoritesArray.length()) {
                    if (favoritesArray.getString(i) == contactId) {
                        isFavorite = true
                        break
                    }
                }
                
                contactObject.put("isFavorite", isFavorite)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing contact from cursor: ${e.message}", e)
        }
        
        return contactObject
    }
    
    /**
     * Lấy RawContactId từ ContactId
     * @param contactId ID của liên hệ
     * @return Long RawContactId tương ứng
     */
    private fun getRawContactId(contactId: String): Long {
        val contentResolver = context.contentResolver
        var rawContactId: Long = -1
        
        val cursor = contentResolver.query(
            ContactsContract.RawContacts.CONTENT_URI,
            arrayOf(ContactsContract.RawContacts._ID),
            ContactsContract.RawContacts.CONTACT_ID + " = ?",
            arrayOf(contactId),
            null
        )
        
        cursor?.use {
            if (it.moveToFirst()) {
                rawContactId = it.getLong(0)
            }
        }
        
        return rawContactId
    }
    
    /**
     * Chuyển đổi kiểu số điện thoại từ chuỗi sang mã số
     * @param typeString Chuỗi kiểu số điện thoại ("mobile", "home", "work", "other")
     * @return Int Mã số kiểu số điện thoại
     */
    private fun getPhoneType(typeString: String): Int {
        return when (typeString.lowercase()) {
            "home" -> ContactsContract.CommonDataKinds.Phone.TYPE_HOME
            "work" -> ContactsContract.CommonDataKinds.Phone.TYPE_WORK
            "mobile" -> ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE
            "other" -> ContactsContract.CommonDataKinds.Phone.TYPE_OTHER
            else -> ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE
        }
    }
    
    /**
     * Chuyển đổi mã số kiểu số điện thoại sang chuỗi
     * @param type Mã số kiểu số điện thoại
     * @return String Chuỗi kiểu số điện thoại
     */
    private fun getPhoneTypeString(type: Int): String {
        return when (type) {
            ContactsContract.CommonDataKinds.Phone.TYPE_HOME -> "home"
            ContactsContract.CommonDataKinds.Phone.TYPE_WORK -> "work"
            ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE -> "mobile"
            ContactsContract.CommonDataKinds.Phone.TYPE_OTHER -> "other"
            else -> "mobile"
        }
    }
    
    /**
     * Chuyển đổi kiểu email từ chuỗi sang mã số
     * @param typeString Chuỗi kiểu email ("home", "work", "other")
     * @return Int Mã số kiểu email
     */
    private fun getEmailType(typeString: String): Int {
        return when (typeString.lowercase()) {
            "home" -> ContactsContract.CommonDataKinds.Email.TYPE_HOME
            "work" -> ContactsContract.CommonDataKinds.Email.TYPE_WORK
            "other" -> ContactsContract.CommonDataKinds.Email.TYPE_OTHER
            else -> ContactsContract.CommonDataKinds.Email.TYPE_HOME
        }
    }
    
    /**
     * Chuyển đổi mã số kiểu email sang chuỗi
     * @param type Mã số kiểu email
     * @return String Chuỗi kiểu email
     */
    private fun getEmailTypeString(type: Int): String {
        return when (type) {
            ContactsContract.CommonDataKinds.Email.TYPE_HOME -> "home"
            ContactsContract.CommonDataKinds.Email.TYPE_WORK -> "work"
            ContactsContract.CommonDataKinds.Email.TYPE_OTHER -> "other"
            else -> "home"
        }
    }
    
    /**
     * Chuẩn hóa số điện thoại để tìm kiếm
     * @param phoneNumber Số điện thoại cần chuẩn hóa
     * @return String Số điện thoại đã chuẩn hóa
     */
    private fun normalizePhoneNumber(phoneNumber: String): String {
        // Loại bỏ các ký tự không phải số
        return phoneNumber.replace(Regex("[^0-9]"), "")
    }
}
