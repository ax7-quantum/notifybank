
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContactManager {
  static final ContactManager _instance = ContactManager._internal();
  final MethodChannel _contactsChannel = const MethodChannel('com.x319.notifybank/contacts');
  
  // Biến cho danh bạ
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  bool _isLoadingContacts = false;
  bool _hasMoreContacts = true;
  int _totalContactsCount = 0;
  int _currentPage = 0;
  final int _pageSize = 30;
  
  // Biến cho giao diện
  final TextEditingController searchController = TextEditingController();
  bool _showContactPicker = false;
  int _contactPickerMode = 0; // 0: Chọn cho cá nhân, 1: Chọn cho hàng loạt
  Function(Map<String, dynamic>)? _onContactSelected;
  Function(String)? _onPhoneNumberAdded;
  BuildContext? _context;

  // Singleton pattern
  factory ContactManager() {
    return _instance;
  }

  ContactManager._internal();

  // Getters
  List<Map<String, dynamic>> get contacts => _contacts;
  List<Map<String, dynamic>> get filteredContacts => _filteredContacts;
  bool get isLoadingContacts => _isLoadingContacts;
  bool get hasMoreContacts => _hasMoreContacts;
  int get totalContactsCount => _totalContactsCount;
  bool get isContactPickerVisible => _showContactPicker; // Đổi tên từ showContactPicker thành isContactPickerVisible

  // Kiểm tra quyền truy cập danh bạ
  Future<bool> checkContactsPermission() async {
    try {
      final bool hasPermission = await _contactsChannel.invokeMethod('checkContactsPermission');
      if (!hasPermission) {
        await _contactsChannel.invokeMethod('requestContactsPermission');
        return await _contactsChannel.invokeMethod('checkContactsPermission');
      }
      return hasPermission;
    } catch (e) {
      print("Lỗi khi kiểm tra quyền danh bạ: $e");
      return false;
    }
  }

  // Lấy tổng số liên hệ
  Future<int> getTotalContactsCount() async {
    try {
      final int count = await _contactsChannel.invokeMethod('getTotalContactsCount');
      _totalContactsCount = count;
      return count;
    } catch (e) {
      print("Lỗi khi lấy tổng số liên hệ: $e");
      return 0;
    }
  }

  // Tải danh sách liên hệ với phân trang

Future<List<Map<String, dynamic>>> loadContacts({bool refresh = false}) async {
  if (_isLoadingContacts) return _contacts;
  
  // Nếu refresh, reset lại trạng thái phân trang
  if (refresh) {
    _currentPage = 0;
    _contacts = [];
    _hasMoreContacts = true;
  }
  
  // Nếu không còn dữ liệu để tải, trả về danh sách hiện tại
  if (!_hasMoreContacts) return _contacts;
  
  _isLoadingContacts = true;
  
  try {
    // Tính offset dựa trên trang hiện tại
    final int offset = _currentPage * _pageSize;
    print("Tải danh bạ: offset=$offset, limit=$_pageSize");
    
    // Gọi phương thức native để lấy danh bạ với phân trang
    final String contactsJson = await _contactsChannel.invokeMethod('getAllContacts', {
      "offset": offset,
      "limit": _pageSize
    });
    
    print("JSON danh bạ nhận được (${contactsJson.length} ký tự)");
    if (contactsJson.length < 100) {
      print("JSON đầy đủ: $contactsJson");
    } else {
      print("JSON mẫu: ${contactsJson.substring(0, 100)}...");
    }
    
    try {
      // Parse JSON thành danh sách đối tượng
      final List<dynamic> contactsData = jsonDecode(contactsJson);
      print("Số lượng liên hệ nhận được: ${contactsData.length}");
      
      if (contactsData.isNotEmpty) {
        print("Mẫu dữ liệu liên hệ đầu tiên: ${contactsData[0]}");
      }
      
      // Chuyển đổi dữ liệu thành danh sách Map
      final List<Map<String, dynamic>> newContacts = 
          contactsData.map((contact) => Map<String, dynamic>.from(contact)).toList();
      
      // Cập nhật danh sách liên hệ
      if (refresh) {
        _contacts = newContacts;
      } else {
        _contacts.addAll(newContacts);
      }
      
      // Cập nhật trạng thái phân trang
      _currentPage++;
      _hasMoreContacts = newContacts.length == _pageSize;
      
      // Cập nhật danh sách đã lọc (mặc định là toàn bộ danh sách)
      _filteredContacts = List.from(_contacts);
      
      _isLoadingContacts = false;
      
      // Cập nhật tổng số liên hệ nếu chưa có
      if (_totalContactsCount == 0) {
        await getTotalContactsCount();
      }
      
      return _contacts;
    } catch (parseError) {
      print("Lỗi khi parse JSON danh bạ: $parseError");
      _isLoadingContacts = false;
      return [];
    }
  } catch (e) {
    print("Lỗi khi tải danh bạ: $e");
    _isLoadingContacts = false;
    return [];
  }
}

// Tìm kiếm danh bạ với phân trang
Future<List<Map<String, dynamic>>> searchContacts(String query, {bool refresh = false}) async {
  if (query.isEmpty) {
    _filteredContacts = List.from(_contacts);
    return _filteredContacts;
  }
  
  if (_isLoadingContacts) return _filteredContacts;
  
  // Nếu refresh, reset lại trạng thái tìm kiếm
  if (refresh) {
    _filteredContacts = [];
    _currentPage = 0;
    _hasMoreContacts = true;
  }
  
  // Nếu không còn dữ liệu để tải, trả về danh sách hiện tại
  if (!_hasMoreContacts) return _filteredContacts;
  
  _isLoadingContacts = true;
  
  try {
    // Tính offset dựa trên trang hiện tại
    final int offset = _currentPage * _pageSize;
    print("Tìm kiếm danh bạ: query='$query', offset=$offset, limit=$_pageSize");
    
    // Gọi phương thức native để tìm kiếm với phân trang
    final String contactsJson = await _contactsChannel.invokeMethod('searchContacts', {
      "query": query,
      "offset": offset,
      "limit": _pageSize
    });
    
    print("JSON tìm kiếm nhận được (${contactsJson.length} ký tự)");
    if (contactsJson.length < 100) {
      print("JSON đầy đủ: $contactsJson");
    } else {
      print("JSON mẫu: ${contactsJson.substring(0, 100)}...");
    }
    
    try {
      // Parse JSON thành danh sách đối tượng
      final List<dynamic> contactsData = jsonDecode(contactsJson);
      print("Số lượng kết quả tìm kiếm: ${contactsData.length}");
      
      if (contactsData.isNotEmpty) {
        print("Mẫu kết quả tìm kiếm đầu tiên: ${contactsData[0]}");
      }
      
      // Chuyển đổi dữ liệu thành danh sách Map
      final List<Map<String, dynamic>> newContacts = 
          contactsData.map((contact) => Map<String, dynamic>.from(contact)).toList();
      
      // Cập nhật danh sách tìm kiếm
      if (refresh) {
        _filteredContacts = newContacts;
      } else {
        _filteredContacts.addAll(newContacts);
      }
      
      // Cập nhật trạng thái phân trang
      _currentPage++;
      _hasMoreContacts = newContacts.length == _pageSize;
      
      _isLoadingContacts = false;
      return _filteredContacts;
    } catch (parseError) {
      print("Lỗi khi parse JSON tìm kiếm: $parseError");
      _isLoadingContacts = false;
      return _filteredContacts;
    }
  } catch (e) {
    print("Lỗi khi tìm kiếm danh bạ: $e");
    _isLoadingContacts = false;
    return _filteredContacts;
  }
}

// Lấy danh sách yêu thích với phân trang
Future<List<Map<String, dynamic>>> getFavorites({int offset = 0, int limit = 30}) async {
  try {
    print("Lấy danh sách yêu thích: offset=$offset, limit=$limit");
    
    final String favoritesJson = await _contactsChannel.invokeMethod('getFavorites', {
      "offset": offset,
      "limit": limit
    });
    
    print("JSON yêu thích nhận được (${favoritesJson.length} ký tự)");
    if (favoritesJson.length < 100) {
      print("JSON đầy đủ: $favoritesJson");
    } else {
      print("JSON mẫu: ${favoritesJson.substring(0, 100)}...");
    }
    
    try {
      final List<dynamic> favoritesData = jsonDecode(favoritesJson);
      print("Số lượng liên hệ yêu thích: ${favoritesData.length}");
      
      if (favoritesData.isNotEmpty) {
        print("Mẫu liên hệ yêu thích đầu tiên: ${favoritesData[0]}");
      }
      
      return favoritesData.map((contact) => Map<String, dynamic>.from(contact)).toList();
    } catch (parseError) {
      print("Lỗi khi parse JSON yêu thích: $parseError");
      return [];
    }
  } catch (e) {
    print("Lỗi khi lấy danh sách yêu thích: $e");
    return [];
  }
}

// Lấy danh sách liên hệ gần đây với phân trang
Future<List<Map<String, dynamic>>> getRecentContacts({int offset = 0, int limit = 10}) async {
  try {
    print("Lấy danh sách liên hệ gần đây: offset=$offset, limit=$limit");
    
    final String recentJson = await _contactsChannel.invokeMethod('getRecentContacts', {
      "offset": offset,
      "limit": limit
    });
    
    print("JSON gần đây nhận được (${recentJson.length} ký tự)");
    if (recentJson.length < 100) {
      print("JSON đầy đủ: $recentJson");
    } else {
      print("JSON mẫu: ${recentJson.substring(0, 100)}...");
    }
    
    try {
      final List<dynamic> recentData = jsonDecode(recentJson);
      print("Số lượng liên hệ gần đây: ${recentData.length}");
      
      if (recentData.isNotEmpty) {
        print("Mẫu liên hệ gần đây đầu tiên: ${recentData[0]}");
      }
      
      return recentData.map((contact) => Map<String, dynamic>.from(contact)).toList();
    } catch (parseError) {
      print("Lỗi khi parse JSON gần đây: $parseError");
      return [];
    }
  } catch (e) {
    print("Lỗi khi lấy danh sách liên hệ gần đây: $e");
    return [];
  }
}

// Lấy chi tiết liên hệ theo ID
Future<Map<String, dynamic>?> getContactById(String contactId) async {
  try {
    print("Lấy chi tiết liên hệ theo ID: $contactId");
    
    final String contactJson = await _contactsChannel.invokeMethod('getContactById', {
      "contactId": contactId
    });
    
    print("JSON chi tiết nhận được (${contactJson.length} ký tự)");
    if (contactJson.length < 100) {
      print("JSON đầy đủ: $contactJson");
    } else {
      print("JSON mẫu: ${contactJson.substring(0, 100)}...");
    }
    
    try {
      final Map<String, dynamic> contactMap = Map<String, dynamic>.from(jsonDecode(contactJson));
      print("Chi tiết liên hệ: id=${contactMap['id']}, displayName=${contactMap['displayName']}");
      return contactMap;
    } catch (parseError) {
      print("Lỗi khi parse JSON chi tiết: $parseError");
      return null;
    }
  } catch (e) {
    print("Lỗi khi lấy chi tiết liên hệ: $e");
    return null;
  }
}

// Lấy chi tiết liên hệ theo số điện thoại
Future<Map<String, dynamic>?> getContactByPhoneNumber(String phoneNumber) async {
  try {
    print("Lấy chi tiết liên hệ theo số điện thoại: $phoneNumber");
    
    final String contactJson = await _contactsChannel.invokeMethod('getContactByPhoneNumber', {
      "phoneNumber": phoneNumber
    });
    
    if (contactJson.isEmpty) {
      print("Không tìm thấy liên hệ cho số điện thoại: $phoneNumber");
      return null;
    }
    
    print("JSON theo số điện thoại nhận được (${contactJson.length} ký tự)");
    if (contactJson.length < 100) {
      print("JSON đầy đủ: $contactJson");
    } else {
      print("JSON mẫu: ${contactJson.substring(0, 100)}...");
    }
    
    try {
      final Map<String, dynamic> contactMap = Map<String, dynamic>.from(jsonDecode(contactJson));
      print("Chi tiết liên hệ theo số điện thoại: id=${contactMap['id']}, displayName=${contactMap['displayName']}");
      return contactMap;
    } catch (parseError) {
      print("Lỗi khi parse JSON theo số điện thoại: $parseError");
      return null;
    }
  } catch (e) {
    print("Lỗi khi lấy chi tiết liên hệ theo số điện thoại: $e");
    return null;
  }
}
  // Thêm liên hệ vào danh sách yêu thích
  Future<bool> addToFavorites(String contactId) async {
    try {
      return await _contactsChannel.invokeMethod('addToFavorites', {
        "contactId": contactId
      });
    } catch (e) {
      print("Lỗi khi thêm vào yêu thích: $e");
      return false;
    }
  }
  
  // Xóa liên hệ khỏi danh sách yêu thích
  Future<bool> removeFromFavorites(String contactId) async {
    try {
      return await _contactsChannel.invokeMethod('removeFromFavorites', {
        "contactId": contactId
      });
    } catch (e) {
      print("Lỗi khi xóa khỏi yêu thích: $e");
      return false;
    }
  }
  
  // Thêm liên hệ vào danh sách gần đây
  Future<bool> addToRecent(String contactId) async {
    try {
      return await _contactsChannel.invokeMethod('addToRecent', {
        "contactId": contactId
      });
    } catch (e) {
      print("Lỗi khi thêm vào danh sách gần đây: $e");
      return false;
    }
  }
  
  // Xóa danh sách liên hệ gần đây
  Future<bool> clearRecent() async {
    try {
      return await _contactsChannel.invokeMethod('clearRecent');
    } catch (e) {
      print("Lỗi khi xóa danh sách gần đây: $e");
      return false;
    }
  }
  
  // Reset trạng thái
  void resetState() {
    _contacts = [];
    _filteredContacts = [];
    _isLoadingContacts = false;
    _hasMoreContacts = true;
    _currentPage = 0;
    _totalContactsCount = 0;
    searchController.clear();
  }
  
  // Lấy số điện thoại từ contact
  String getPhoneNumberFromContact(Map<String, dynamic> contact) {
    final List<dynamic> phoneNumbers = contact['phoneNumbers'] ?? [];
    if (phoneNumbers.isEmpty) return '';
    return phoneNumbers[0]['number'] ?? '';
  }
  
  // Kiểm tra nếu contact có số điện thoại
  bool contactHasPhoneNumber(Map<String, dynamic> contact) {
    final List<dynamic> phoneNumbers = contact['phoneNumbers'] ?? [];
    return phoneNumbers.isNotEmpty && phoneNumbers[0]['number'] != null;
  }
  
  // Tải thêm danh bạ khi cuộn đến cuối danh sách
  Future<List<Map<String, dynamic>>> loadMoreContacts() async {
    if (!_hasMoreContacts || _isLoadingContacts) return _contacts;
    return await loadContacts();
  }
  
  // Tải thêm kết quả tìm kiếm khi cuộn đến cuối danh sách
  Future<List<Map<String, dynamic>>> loadMoreSearchResults(String query) async {
    if (!_hasMoreContacts || _isLoadingContacts || query.isEmpty) return _filteredContacts;
    return await searchContacts(query);
  }

  // ======= PHẦN GIAO DIỆN DANH BẠ =======

  // Hiển thị màn hình chọn danh bạ - Đổi tên phương thức từ showContactPicker thành openContactPicker
  void openContactPicker(BuildContext context, int mode, {
    required Function(Map<String, dynamic>) onContactSelected,
    Function(String)? onPhoneNumberAdded
  }) {
    _context = context;
    _showContactPicker = true;
    _contactPickerMode = mode;
    _onContactSelected = onContactSelected;
    _onPhoneNumberAdded = onPhoneNumberAdded;
    resetState();
    loadContacts();
    
    // Hiển thị màn hình chọn danh bạ
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _buildContactPickerScreen(),
      ),
    );
  }
  
  // Đóng màn hình chọn danh bạ
  void closeContactPicker() {
    if (_context != null) {
      Navigator.of(_context!).pop();
      _showContactPicker = false;
      _context = null;
    }
  }

  // Xử lý khi chọn số điện thoại từ danh bạ
  void _selectPhoneNumber(Map<String, dynamic> contact) {
    final String phoneNumber = getPhoneNumberFromContact(contact);
    
    if (_contactPickerMode == 0) {
      // Chế độ cá nhân
      if (_onContactSelected != null) {
        _onContactSelected!(contact);
      }
    } else {
      // Chế độ hàng loạt
      if (_onPhoneNumberAdded != null) {
        _onPhoneNumberAdded!(phoneNumber);
      }
    }
    
    closeContactPicker();
  }

  // Xây dựng màn hình chọn danh bạ
  Widget _buildContactPickerScreen() {
    return StatefulBuilder(
      builder: (context, setState) {
        // Lấy kích thước màn hình
        final Size screenSize = MediaQuery.of(context).size;
        final double screenHeight = screenSize.height;
        final double screenWidth = screenSize.width;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chọn từ danh bạ'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: closeContactPicker,
            ),
          ),
          body: Column(
            children: [
              // Thanh tìm kiếm - 8% màn hình
              Container(
                height: screenHeight * 0.08,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.01),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm danh bạ',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    searchContacts(value, refresh: true).then((_) {
                      setState(() {}); // Cập nhật UI sau khi tìm kiếm
                    });
                  },
                ),
              ),
              
              // Danh sách danh bạ - phần còn lại
              Expanded(
                child: _isLoadingContacts && _filteredContacts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredContacts.isEmpty
                    ? const Center(child: Text('Không tìm thấy danh bạ nào'))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (!_isLoadingContacts && _hasMoreContacts &&
                              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                            if (searchController.text.isEmpty) {
                              loadMoreContacts().then((_) => setState(() {}));
                            } else {
                              loadMoreSearchResults(searchController.text).then((_) => setState(() {}));
                            }
                          }
                          return true;
                        },
                        child: ListView.builder(
                          itemCount: _filteredContacts.length + (_hasMoreContacts ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Hiển thị loading indicator ở cuối danh sách nếu đang tải thêm
                            if (index == _filteredContacts.length) {
                              return Container(
                                padding: const EdgeInsets.all(16.0),
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(),
                              );
                            }
                            
                            final contact = _filteredContacts[index];
final String displayName = contact['name'] ?? 'Không có tên';

                            
                            // Nếu không có số điện thoại, bỏ qua
                            if (!contactHasPhoneNumber(contact)) return const SizedBox.shrink();
                            
                            return Container(
                              height: screenHeight * 0.1, // Chiều cao 10% màn hình cho mỗi mục
                              child: Card(
                                margin: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenHeight * 0.005,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    displayName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(getPhoneNumberFromContact(contact)),
                                  trailing: _contactPickerMode == 1
                                    ? IconButton(
                                        icon: const Icon(Icons.add_circle, color: Colors.green),
                                        onPressed: () {
                                          if (_onPhoneNumberAdded != null) {
                                            _onPhoneNumberAdded!(getPhoneNumberFromContact(contact));
                                          }
                                        },
                                      )
                                    : null,
                                  onTap: () => _selectPhoneNumber(contact),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      }
    );
  }
  
  // Hiển thị danh sách liên hệ yêu thích
  Widget buildFavoritesListWidget({
    required Function(Map<String, dynamic>) onContactSelected,
    double height = 200,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: getFavorites(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: height,
            child: const Center(
              child: Text('Không có liên hệ yêu thích nào'),
            ),
          );
        }
        
        final favorites = snapshot.data!;
        
        return Container(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final contact = favorites[index];
              final String displayName = contact['name'] ?? 'Không có tên';
              
              return Container(
                width: 100,
                margin: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: () => onContactSelected(contact),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        getPhoneNumberFromContact(contact),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  // Hiển thị danh sách liên hệ gần đây
  Widget buildRecentContactsWidget({
    required Function(Map<String, dynamic>) onContactSelected,
    double height = 200,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: getRecentContacts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: height,
            child: const Center(
              child: Text('Không có liên hệ gần đây nào'),
            ),
          );
        }
        
        final recentContacts = snapshot.data!;
        
        return Container(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recentContacts.length,
            itemBuilder: (context, index) {
              final contact = recentContacts[index];
              final String displayName = contact['name'] ?? 'Không có tên';
              
              return Container(
                width: 100,
                margin: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: () => onContactSelected(contact),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.green.shade100,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        getPhoneNumberFromContact(contact),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  // Widget hiển thị số điện thoại đã chọn với khả năng xóa
  Widget buildSelectedPhoneNumbersWidget({
    required List<String> phoneNumbers,
    required Function(int) onRemove,
    required VoidCallback onClearAll,
    double height = 200,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách số điện thoại (${phoneNumbers.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: phoneNumbers.isEmpty ? null : onClearAll,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Xóa tất cả', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: phoneNumbers.isEmpty
                ? const Center(child: Text('Chưa có số điện thoại nào'))
                : ListView.builder(
                    itemCount: phoneNumbers.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        dense: true,
                        title: Text(phoneNumbers[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => onRemove(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

