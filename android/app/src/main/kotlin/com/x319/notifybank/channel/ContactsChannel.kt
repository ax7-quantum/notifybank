package com.x319.notifybank.channels

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.x319.notifybank.Constants
import com.x319.notifybank.MainActivity
import com.x319.notifybank.ContactsManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class ContactsChannel(
    private val flutterEngine: FlutterEngine,
    private val activity: MainActivity,
    private val contactsManager: ContactsManager
) {
    private val TAG = "ContactsChannel"

    fun setup() {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.CONTACTS_CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Contacts method call received: ${call.method}")
            try {
                when (call.method) {
                    "checkContactsPermission" -> {
                        val isGranted = checkContactsPermission()
                        result.success(isGranted)
                        Log.d(TAG, "Contacts permission status: $isGranted")
                    }
                    "requestContactsPermission" -> {
                        requestContactsPermission()
                        result.success(true)
                        Log.d(TAG, "Contacts permission requested")
                    }
                    "getAllContacts" -> {
                        // Lấy tham số phân trang
                        val offset = call.argument<Int>("offset") ?: 0
                        val limit = call.argument<Int>("limit") ?: 30
                        
                        if (checkContactsPermission()) {
                            val contacts = contactsManager.getAllContacts(offset, limit)
                            result.success(contacts.toString())
                            Log.d(TAG, "Contacts retrieved: ${contacts.length()} contacts (offset: $offset, limit: $limit)")
                        } else {
                            requestContactsPermission()
                            result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
                            Log.e(TAG, "Cannot get contacts: permission denied")
                        }
                    }
                    "getTotalContactsCount" -> {
                        if (checkContactsPermission()) {
                            val count = contactsManager.getTotalContactsCount()
                            result.success(count)
                            Log.d(TAG, "Total contacts count: $count")
                        } else {
                            requestContactsPermission()
                            result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
                            Log.e(TAG, "Cannot get total contacts count: permission denied")
                        }
                    }
                    "searchContacts" -> {
                        val query = call.argument<String>("query") ?: ""
                        val offset = call.argument<Int>("offset") ?: 0
                        val limit = call.argument<Int>("limit") ?: 30
                        
                        if (checkContactsPermission()) {
                            val contacts = contactsManager.searchContacts(query, offset, limit)
                            result.success(contacts.toString())
                            Log.d(TAG, "Contacts search for '$query' returned ${contacts.length()} results (offset: $offset, limit: $limit)")
                        } else {
                            requestContactsPermission()
                            result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
                            Log.e(TAG, "Cannot search contacts: permission denied")
                        }
                    }
                    "getContactById" -> {
                        val contactId = call.argument<String>("contactId") ?: throw Exception("Contact ID is required")
                        if (checkContactsPermission()) {
                            val contact = contactsManager.getContactById(contactId)
                            result.success(contact)
                            Log.d(TAG, "Contact retrieved by ID: $contactId")
                        } else {
                            requestContactsPermission()
                            result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
                            Log.e(TAG, "Cannot get contact: permission denied")
                        }
                    }
                    "getContactByPhoneNumber" -> {
                        val phoneNumber = call.argument<String>("phoneNumber") ?: throw Exception("Phone number is required")
                        if (checkContactsPermission()) {
                            val contact = contactsManager.getContactByPhoneNumber(phoneNumber)
                            result.success(contact)
                            Log.d(TAG, "Contact retrieved by phone number: $phoneNumber")
                        } else {
                            requestContactsPermission()
                            result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
                            Log.e(TAG, "Cannot get contact: permission denied")
                        }
                    }
                    "saveContact" -> {
                        val contactJson = call.argument<String>("contact") ?: throw Exception("Contact data is required")
                        val contact = JSONObject(contactJson)
                        if (checkContactsPermission()) {
                            val success = contactsManager.saveContact(contact)
                            result.success(success)
                            Log.d(TAG, "Contact saved: $success")
                        } else {
                            requestContactsPermission()
                            result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
                            Log.e(TAG, "Cannot save contact: permission denied")
                        }
                    }
                    "updateContact" -> {
                        val contactId = call.argument<String>("contactId") ?: throw Exception("Contact ID is required")
                        val contactJson = call.argument<String>("contact") ?: throw Exception("Contact data is required")
                        val contact = JSONObject(contactJson)
                        if (checkContactsPermission()) {
                            val success = contactsManager.updateContact(contactId, contact)
                            result.success(success)
                            Log.d(TAG, "Contact updated: $success")
                        } else {
                            requestContactsPermission()
                            result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
                            Log.e(TAG, "Cannot update contact: permission denied")
                        }
                    }
                    "deleteContact" -> {
                        val contactId = call.argument<String>("contactId") ?: throw Exception("Contact ID is required")
                        if (checkContactsPermission()) {
                            val success = contactsManager.deleteContact(contactId)
                            result.success(success)
                            Log.d(TAG, "Contact deleted: $success")
                        } else {
                            requestContactsPermission()
                            result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
                            Log.e(TAG, "Cannot delete contact: permission denied")
                        }
                    }
                    "addToFavorites" -> {
                        val contactId = call.argument<String>("contactId") ?: throw Exception("Contact ID is required")
                        val success = contactsManager.addToFavorites(contactId)
                        result.success(success)
                        Log.d(TAG, "Contact added to favorites: $success")
                    }
                    "removeFromFavorites" -> {
                        val contactId = call.argument<String>("contactId") ?: throw Exception("Contact ID is required")
                        val success = contactsManager.removeFromFavorites(contactId)
                        result.success(success)
                        Log.d(TAG, "Contact removed from favorites: $success")
                    }
                    "getFavorites" -> {
                        val offset = call.argument<Int>("offset") ?: 0
                        val limit = call.argument<Int>("limit") ?: 30
                        
                        val favorites = contactsManager.getFavorites(offset, limit)
                        result.success(favorites.toString())
                        Log.d(TAG, "Favorites retrieved: ${favorites.length()} contacts (offset: $offset, limit: $limit)")
                    }
                    "getRecentContacts" -> {
                        val offset = call.argument<Int>("offset") ?: 0
                        val limit = call.argument<Int>("limit") ?: 10
                        
                        val recentContacts = contactsManager.getRecentContacts(offset, limit)
                        result.success(recentContacts.toString())
                        Log.d(TAG, "Recent contacts retrieved: ${recentContacts.length()} contacts (offset: $offset, limit: $limit)")
                    }
                    "addToRecent" -> {
                        val contactId = call.argument<String>("contactId") ?: throw Exception("Contact ID is required")
                        val success = contactsManager.addToRecent(contactId)
                        result.success(success)
                        Log.d(TAG, "Contact added to recent: $success")
                    }
                    "clearRecent" -> {
                        val success = contactsManager.clearRecent()
                        result.success(success)
                        Log.d(TAG, "Recent contacts cleared: $success")
                    }
                    else -> {
                        result.notImplemented()
                        Log.d(TAG, "Contacts method not implemented: ${call.method}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in Contacts method call: ${call.method}", e)
                result.error("CONTACTS_ERROR", e.message, e.stackTraceToString())
            }
        }
    }
    
    // Hàm kiểm tra quyền truy cập danh bạ
    private fun checkContactsPermission(): Boolean {
        val readContactsPermission = ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
        val writeContactsPermission = ContextCompat.checkSelfPermission(activity, Manifest.permission.WRITE_CONTACTS) == PackageManager.PERMISSION_GRANTED
        Log.d(TAG, "Contacts permissions status: read=$readContactsPermission, write=$writeContactsPermission")
        return readContactsPermission && writeContactsPermission
    }
    
    // Hàm yêu cầu quyền truy cập danh bạ
    private fun requestContactsPermission() {
        if (!checkContactsPermission()) {
            Log.d(TAG, "Requesting contacts permissions")
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.READ_CONTACTS, Manifest.permission.WRITE_CONTACTS),
                Constants.CONTACTS_PERMISSION_CODE
            )
        } else {
            Log.d(TAG, "Contacts permissions already granted")
        }
    }
}
