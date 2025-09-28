
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ReceivedSmsTab extends StatefulWidget {
  const ReceivedSmsTab({Key? key}) : super(key: key);

  @override
  State<ReceivedSmsTab> createState() => _ReceivedSmsTabState();
}

class _ReceivedSmsTabState extends State<ReceivedSmsTab> {
  final MethodChannel _smsChannel = const MethodChannel('com.x319.notifybank/sms');
  bool _isLoading = false;
  List<dynamic> _receivedSms = [];

  @override
  void initState() {
    super.initState();
    _loadReceivedSms();
  }

  // Tải tin nhắn đã nhận
  Future<void> _loadReceivedSms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Lấy lịch sử tin nhắn đã nhận
      final String receivedSmsJson = await _smsChannel.invokeMethod('getReceivedSms');
      List<dynamic> receivedSmsList = [];
      try {
        receivedSmsList = json.decode(receivedSmsJson) as List<dynamic>;
      } catch (e) {
        print("Lỗi khi parse JSON tin nhắn nhận được: $e");
        receivedSmsList = [];
      }

      setState(() {
        _receivedSms = receivedSmsList;
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi tải tin nhắn đã nhận: ${e.message}");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Xóa tin nhắn đã nhận
  Future<void> _clearReceivedSms() async {
    try {
      final bool success = await _smsChannel.invokeMethod('clearReceivedSms');
      if (success) {
        _showSnackBar('Đã xóa tin nhắn đã nhận');
        _loadReceivedSms();
      }
    } on PlatformException catch (e) {
      print("Lỗi khi xóa tin nhắn đã nhận: ${e.message}");
      _showSnackBar('Lỗi: ${e.message}');
    }
  }

  // Đánh dấu tin nhắn đã đọc
  Future<void> _markSmsAsRead(int index) async {
    try {
      final bool success = await _smsChannel.invokeMethod('markSmsAsRead', {"index": index});
      if (success) {
        _loadReceivedSms();
      }
    } on PlatformException catch (e) {
      print("Lỗi khi đánh dấu tin nhắn đã đọc: ${e.message}");
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
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;
    
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Thanh công cụ (5% chiều cao màn hình)
              if (_receivedSms.isNotEmpty)
                Container(
                  height: screenHeight * 0.05,
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _clearReceivedSms,
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Xóa tất cả'),
                      ),
                    ],
                  ),
                ),
              
              // Danh sách tin nhắn đã nhận (95% chiều cao màn hình còn lại)
              Expanded(
                child: _receivedSms.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa nhận được tin nhắn nào',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReceivedSms,
                        child: ListView.builder(
                          itemCount: _receivedSms.length,
                          itemBuilder: (context, index) {
                            final sms = _receivedSms[index];
                            final bool isRead = sms['isRead'] ?? false;
                            
                            return InkWell(
                              onTap: () {
                                if (!isRead) {
                                  _markSmsAsRead(index);
                                }
                              },
                              child: Card(
                                margin: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.02, 
                                  vertical: screenHeight * 0.005
                                ),
                                color: isRead ? null : Colors.blue.withOpacity(0.1),
                                child: Padding(
                                  padding: EdgeInsets.all(screenWidth * 0.02),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                                            color: isRead ? Colors.grey : Colors.blue,
                                            size: screenWidth * 0.06,
                                          ),
                                          SizedBox(width: screenWidth * 0.02),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sms['sender'] ?? 'Không rõ người gửi',
                                                  style: TextStyle(
                                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(height: screenHeight * 0.005),
                                                Text(
                                                  _formatTimestamp(sms['timestamp'] ?? 0),
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (!isRead)
                                                IconButton(
                                                  icon: const Icon(Icons.done_all),
                                                  onPressed: () => _markSmsAsRead(index),
                                                  tooltip: 'Đánh dấu đã đọc',
                                                ),
                                              IconButton(
                                                icon: const Icon(Icons.content_copy),
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: sms['message'] ?? ''));
                                                  _showSnackBar('Đã sao chép nội dung tin nhắn');
                                                },
                                                tooltip: 'Sao chép nội dung',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: screenHeight * 0.01),
                                      const Divider(height: 1),
                                      SizedBox(height: screenHeight * 0.01),
                                      // Nội dung tin nhắn với khả năng cuộn
                                      Container(
                                        width: double.infinity,
                                        constraints: BoxConstraints(
                                          maxHeight: screenHeight * 0.1,
                                        ),
                                        child: SingleChildScrollView(
                                          child: Text(sms['message'] ?? 'Không có nội dung'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
  }
}