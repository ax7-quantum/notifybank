import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class SmsHistoryTab extends StatefulWidget {
  const SmsHistoryTab({Key? key}) : super(key: key);

  @override
  State<SmsHistoryTab> createState() => _SmsHistoryTabState();
}

class _SmsHistoryTabState extends State<SmsHistoryTab> {
  final MethodChannel _smsChannel = const MethodChannel('com.x319.notifybank/sms');
  
  bool _isLoading = false;
  List<dynamic> _receivedSms = [];
  List<dynamic> _sentSms = [];
  int _totalReceivedCount = 0;
  int _totalSentCount = 0;
  bool _isSearchMode = false;
  bool _showSentMessages = false;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadReceivedSms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Tải danh sách tin nhắn đã nhận
  Future<void> _loadReceivedSms() async {
    setState(() {
      _isLoading = true;
      _showSentMessages = false;
    });

    try {
      // Lấy tin nhắn đã nhận từ SharedPreferences
      final String smsJson = await _smsChannel.invokeMethod('getReceivedSms', {
        'limit': 50,
        'onlyUnread': false,
      });
      
      List<dynamic> smsList = [];
      try {
        smsList = json.decode(smsJson) as List<dynamic>;
      } catch (e) {
        print("Lỗi khi parse JSON tin nhắn SMS: $e");
        smsList = [];
      }

      setState(() {
        _receivedSms = smsList;
        _totalReceivedCount = smsList.length;
        _isLoading = false;
      });
    } catch (e) {
      print("Lỗi khi tải tin nhắn SMS: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Tải danh sách tin nhắn đã gửi
  Future<void> _loadSentSms() async {
    setState(() {
      _isLoading = true;
      _showSentMessages = true;
    });

    try {
      // Lấy tin nhắn đã gửi từ SharedPreferences
      final String smsJson = await _smsChannel.invokeMethod('getSmsHistory', {
        'limit': 50,
      });
      
      List<dynamic> smsList = [];
      try {
        smsList = json.decode(smsJson) as List<dynamic>;
      } catch (e) {
        print("Lỗi khi parse JSON tin nhắn đã gửi: $e");
        smsList = [];
      }

      setState(() {
        _sentSms = smsList;
        _totalSentCount = smsList.length;
        _isLoading = false;
      });
    } catch (e) {
      print("Lỗi khi tải tin nhắn đã gửi: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Đánh dấu tin nhắn đã đọc
  Future<void> _markAsRead(String id) async {
    try {
      await _smsChannel.invokeMethod('markSmsAsRead', {'id': id});
      
      setState(() {
        for (var sms in _receivedSms) {
          if (sms['id'] == id) {
            sms['isRead'] = true;
            break;
          }
        }
      });
    } catch (e) {
      print("Lỗi khi đánh dấu tin nhắn đã đọc: $e");
    }
  }

  // Xóa tin nhắn
  Future<void> _deleteSms(String id) async {
    try {
      final bool success = await _smsChannel.invokeMethod('deleteSms', {'id': id});
      
      if (success) {
        setState(() {
          _receivedSms.removeWhere((sms) => sms['id'] == id);
          _totalReceivedCount--;
        });
        _showSnackBar('Đã xóa tin nhắn');
      }
    } catch (e) {
      print("Lỗi khi xóa tin nhắn: $e");
    }
  }

  // Tìm kiếm tin nhắn
  Future<void> _searchSms() async {
    if (_searchController.text.isEmpty) {
      if (_showSentMessages) {
        _loadSentSms();
      } else {
        _loadReceivedSms();
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String methodName = _showSentMessages ? 'searchSentSms' : 'searchSms';
      final String smsJson = await _smsChannel.invokeMethod(methodName, {
        'query': _searchController.text,
        'limit': 50,
      });
      
      List<dynamic> smsList = [];
      try {
        smsList = json.decode(smsJson) as List<dynamic>;
      } catch (e) {
        print("Lỗi khi parse JSON kết quả tìm kiếm: $e");
        smsList = [];
      }

      setState(() {
        if (_showSentMessages) {
          _sentSms = smsList;
        } else {
          _receivedSms = smsList;
        }
        _isLoading = false;
      });
    } catch (e) {
      print("Lỗi khi tìm kiếm tin nhắn: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Hiển thị thông báo
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Định dạng thời gian
  String _formatTimestamp(int timestamp) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  // Hiển thị menu tùy chọn khi nhấn giữ tin nhắn đã nhận
  void _showReceivedSmsOptions(BuildContext context, dynamic sms) {
    final String id = sms['id'] ?? '';
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Sao chép nội dung'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: sms['message'] ?? ''));
                  Navigator.pop(context);
                  _showSnackBar('Đã sao chép nội dung tin nhắn');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Xóa tin nhắn', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSms(id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Hiển thị menu tùy chọn khi nhấn giữ tin nhắn đã gửi
  void _showSentSmsOptions(BuildContext context, dynamic sms) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Sao chép nội dung'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: sms['message'] ?? ''));
                  Navigator.pop(context);
                  _showSnackBar('Đã sao chép nội dung tin nhắn');
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Sao chép số điện thoại'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: sms['phoneNumber'] ?? ''));
                  Navigator.pop(context);
                  _showSnackBar('Đã sao chép số điện thoại');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;
    
    return Column(
      children: [
        // Phần đầu (10% chiều cao màn hình) - Chứa nút chuyển chế độ và tiêu đề
        Container(
          height: screenHeight * 0.1,
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Nút chuyển chế độ tin nhắn đã nhận
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isSearchMode = false;
                  });
                  _loadReceivedSms();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_isSearchMode && !_showSentMessages
                      ? Theme.of(context).primaryColor 
                      : Theme.of(context).primaryColor.withOpacity(0.5),
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                ),
                child: const Text('Đã nhận'),
              ),
              SizedBox(width: screenWidth * 0.02),
              // Nút chuyển chế độ tin nhắn đã gửi
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isSearchMode = false;
                  });
                  _loadSentSms();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_isSearchMode && _showSentMessages
                      ? Theme.of(context).primaryColor 
                      : Theme.of(context).primaryColor.withOpacity(0.5),
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                ),
                child: const Text('Đã gửi'),
              ),
              SizedBox(width: screenWidth * 0.02),
              // Nút chuyển chế độ tìm kiếm
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isSearchMode = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSearchMode 
                      ? Theme.of(context).primaryColor 
                      : Theme.of(context).primaryColor.withOpacity(0.5),
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                ),
                child: const Text('Tìm kiếm'),
              ),
              const Spacer(),
              // Hiển thị tổng số tin nhắn
              if (!_isSearchMode)
                Text(
                  _showSentMessages 
                      ? 'Tổng: $_totalSentCount tin nhắn' 
                      : 'Tổng: $_totalReceivedCount tin nhắn',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
        
        // Phần tìm kiếm (hiển thị khi ở chế độ tìm kiếm)
        if (_isSearchMode)
          Container(
            height: screenHeight * 0.07,
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
            child: Row(
              children: [
                // Ô nhập tìm kiếm (70% màn hình)
                Container(
                  width: screenWidth * 0.7,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Nhập nội dung tìm kiếm...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.02,
                        vertical: screenHeight * 0.01,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                // Nút tìm kiếm (7% màn hình)
                Container(
                  width: screenWidth * 0.07,
                  child: ElevatedButton(
                    onPressed: _searchSms,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          
        // Danh sách tin nhắn (phần còn lại của màn hình)
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _showSentMessages
                  ? _buildSentSmsListView(screenHeight, screenWidth)
                  : _buildReceivedSmsListView(screenHeight, screenWidth),
        ),
      ],
    );
  }

  // Widget hiển thị danh sách tin nhắn đã nhận
  Widget _buildReceivedSmsListView(double screenHeight, double screenWidth) {
    return _receivedSms.isEmpty
        ? Center(
            child: Text(
              _isSearchMode 
                  ? 'Không tìm thấy tin nhắn nào' 
                  : 'Chưa có tin nhắn nào',
              style: TextStyle(color: Colors.grey),
            ),
          )
        : ListView.builder(
            itemCount: _receivedSms.length,
            itemBuilder: (context, index) {
              final sms = _receivedSms[index];
              final bool isRead = sms['isRead'] ?? false;
              
              return GestureDetector(
                onLongPress: () => _showReceivedSmsOptions(context, sms),
                child: Container(
                  height: screenHeight * 0.3, // Mỗi tin nhắn cao 30% màn hình
                  margin: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenHeight * 0.005,
                  ),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Phần 1: Số điện thoại (7% chiều cao màn hình)
                      Container(
                        height: screenHeight * 0.07,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Icon(Icons.person, size: screenWidth * 0.05),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                sms['sender'] ?? 'Không rõ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Phần 2: Nội dung tin nhắn (16% chiều cao màn hình)
                      Container(
                        height: screenHeight * 0.16,
                        width: double.infinity,
                        padding: EdgeInsets.all(screenWidth * 0.02),
                        child: SingleChildScrollView(
                          child: Text(
                            sms['message'] ?? 'Không có nội dung',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      
                      // Phần 3: Thời gian / trạng thái đọc (7% chiều cao màn hình)
                      Container(
                        height: screenHeight * 0.07,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Icon(
                                isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                                size: screenWidth * 0.05,
                                color: isRead ? Colors.green : Colors.orange,
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                isRead ? 'Đã đọc' : 'Chưa đọc',
                                style: TextStyle(
                                  color: isRead ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Icon(Icons.access_time, size: screenWidth * 0.05),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                _formatTimestamp(sms['timestamp'] ?? 0),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  // Widget hiển thị danh sách tin nhắn đã gửi
  Widget _buildSentSmsListView(double screenHeight, double screenWidth) {
    return _sentSms.isEmpty
        ? Center(
            child: Text(
              _isSearchMode 
                  ? 'Không tìm thấy tin nhắn nào' 
                  : 'Chưa có tin nhắn nào',
              style: TextStyle(color: Colors.grey),
            ),
          )
        : ListView.builder(
            itemCount: _sentSms.length,
            itemBuilder: (context, index) {
              final sms = _sentSms[index];
              final bool success = sms['success'] ?? true;
              
              return GestureDetector(
                onLongPress: () => _showSentSmsOptions(context, sms),
                child: Container(
                  height: screenHeight * 0.3, // Mỗi tin nhắn cao 30% màn hình
                  margin: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenHeight * 0.005,
                  ),
                  decoration: BoxDecoration(
                    color: success ? Colors.white : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Phần 1: Số điện thoại (7% chiều cao màn hình)
                      Container(
                        height: screenHeight * 0.07,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Icon(Icons.person, size: screenWidth * 0.05),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                sms['phoneNumber'] ?? 'Không rõ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Phần 2: Nội dung tin nhắn (16% chiều cao màn hình)
                      Container(
                        height: screenHeight * 0.16,
                        width: double.infinity,
                        padding: EdgeInsets.all(screenWidth * 0.02),
                        child: SingleChildScrollView(
                          child: Text(
                            sms['message'] ?? 'Không có nội dung',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      
                      // Phần 3: Thời gian / trạng thái gửi (7% chiều cao màn hình)
                      Container(
                        height: screenHeight * 0.07,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Icon(
                                success ? Icons.check_circle : Icons.error,
                                size: screenWidth * 0.05,
                                color: success ? Colors.green : Colors.red,
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                success ? 'Đã gửi thành công' : 'Gửi thất bại',
                                style: TextStyle(
                                  color: success ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Icon(Icons.access_time, size: screenWidth * 0.05),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                _formatTimestamp(sms['timestamp'] ?? 0),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (sms['simId'] != null && sms['simId'] != -1) ...[
                                SizedBox(width: screenWidth * 0.03),
                                Icon(Icons.sim_card, size: screenWidth * 0.05),
                                SizedBox(width: screenWidth * 0.01),
                                Text(
                                  'SIM ${sms['simId']}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
