import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationView extends StatefulWidget {
  const NotificationView({Key? key}) : super(key: key);

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  final MethodChannel _channel = const MethodChannel('com.x319.notifybank/notification');
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // Tải danh sách thông báo từ SharedPreferences
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final String notificationsJson = await _channel.invokeMethod('getNotifications');
      
      // Xử lý chuỗi JSON nhận được
      List<dynamic> decodedList = [];
      try {
        decodedList = json.decode(notificationsJson) as List<dynamic>;
      } catch (e) {
        print("Lỗi khi parse JSON: $e");
        print("JSON nhận được: $notificationsJson");
        decodedList = [];
      }
      
      setState(() {
        _notifications = decodedList;
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi tải thông báo: ${e.message}");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Xóa tất cả thông báo
  Future<void> _clearNotifications() async {
    try {
      await _channel.invokeMethod('clearNotifications');
      _loadNotifications();
    } on PlatformException catch (e) {
      print("Lỗi khi xóa thông báo: ${e.message}");
    }
  }

  // Sao chép nội dung thông báo vào clipboard
  void _copyNotificationToClipboard(dynamic notification) {
    final String notificationStr = json.encode(notification);
    Clipboard.setData(ClipboardData(text: notificationStr));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép thông báo vào bộ nhớ tạm'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;
    
    return Expanded(
      child: Column(
        children: [
          // Tiêu đề và nút xóa
          Container(
            height: screenHeight * 0.05,
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách thông báo (${_notifications.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_notifications.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearNotifications,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Xóa tất cả'),
                  ),
              ],
            ),
          ),
          
          // Danh sách thông báo
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có thông báo nào',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        child: ListView.builder(
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            
                            // Lấy tiêu đề và nội dung an toàn
                            String title = notification['title']?.toString() ?? 'Không có tiêu đề';
                            String text = notification['text']?.toString() ?? 'Không có nội dung';
                            String packageName = notification['packageName']?.toString() ?? 'Không xác định';
                            String formattedTime = notification['formattedTime']?.toString() ?? 'Không xác định';
                            
                            // Lấy chữ cái đầu tiên an toàn
                            String firstLetter = 'N';
                            if (title.isNotEmpty) {
                              firstLetter = title.substring(0, 1).toUpperCase();
                            }
                            
                            return Card(
                              margin: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.04,
                                vertical: screenHeight * 0.01,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(screenWidth * 0.02),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header with app info
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          child: Text(firstLetter),
                                        ),
                                        SizedBox(width: screenWidth * 0.02),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              // Phần tên gói - 7% chiều cao màn hình, có cuộn ngang
                                              Container(
                                                height: screenHeight * 0.07,
                                                child: SingleChildScrollView(
                                                  scrollDirection: Axis.horizontal,
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        'Ứng dụng: $packageName',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                'Thời gian: $formattedTime',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const Divider(),
                                    
                                    // Phần nội dung - 15% chiều cao màn hình, có cuộn
                                    Container(
                                      width: double.infinity,
                                      height: screenHeight * 0.15,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.all(8),
                                      margin: EdgeInsets.only(bottom: screenHeight * 0.01),
                                      child: SingleChildScrollView(
                                        child: Text(
                                          text,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Hiển thị thông báo đầy đủ - 30% chiều cao màn hình, có cuộn
                                    Container(
                                      width: double.infinity,
                                      height: screenHeight * 0.3,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.all(8),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Tiêu đề: $title',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            SizedBox(height: screenHeight * 0.01),
                                            Text('Ứng dụng: $packageName'),
                                            SizedBox(height: screenHeight * 0.005),
                                            Text('Thời gian: $formattedTime'),
                                            SizedBox(height: screenHeight * 0.01),
                                            Text('Nội dung:'),
                                            SizedBox(height: screenHeight * 0.005),
                                            Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                text,
                                                style: TextStyle(height: 1.3),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    SizedBox(height: screenHeight * 0.01),
                                    
                                    // Nút sao chép dữ liệu thô - 5% chiều cao màn hình
                                    Container(
                                      height: screenHeight * 0.05,
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _copyNotificationToClipboard(notification),
                                        icon: const Icon(Icons.copy),
                                        label: const Text('Sao chép dữ liệu thô'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[700],
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
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
}