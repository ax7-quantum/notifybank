import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppSettingsView extends StatefulWidget {
  const AppSettingsView({Key? key}) : super(key: key);

  @override
  State<AppSettingsView> createState() => _AppSettingsViewState();
}

class _AppSettingsViewState extends State<AppSettingsView> {
  final MethodChannel _settingsChannel = const MethodChannel('com.x319.notifybank/appsettings');
  
  int _notificationThreads = 1;
  List<int> _availableThreads = [1, 2, 3, 4, 5];
  bool _saveNotifications = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Tải cài đặt từ native
  Future<void> _loadSettings() async {
    try {
      final String settingsJson = await _settingsChannel.invokeMethod('getAppSettings');
      final Map<String, dynamic> settings = jsonDecode(settingsJson);
      
      setState(() {
        _notificationThreads = settings['notificationThreads'] ?? 1;
        _saveNotifications = settings['saveNotifications'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      print('Lỗi khi tải cài đặt: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải cài đặt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Thay đổi số luồng thông báo
  Future<void> _changeThreads(int value) async {
    try {
      final int newThreads = await _settingsChannel.invokeMethod('setThreads', {'value': value});
      setState(() {
        _notificationThreads = newThreads;
      });
      _showSuccessMessage('Đã thay đổi số luồng thông báo thành $_notificationThreads');
    } catch (e) {
      _showErrorMessage('Không thể thay đổi số luồng: $e');
    }
  }

  // Bật/tắt lưu thông báo
  Future<void> _toggleSaveNotifications() async {
    try {
      final bool newState = await _settingsChannel.invokeMethod('toggleSaveNotifications');
      setState(() {
        _saveNotifications = newState;
      });
      _showSuccessMessage(_saveNotifications 
        ? 'Đã bật lưu thông báo' 
        : 'Đã tắt lưu thông báo');
    } catch (e) {
      _showErrorMessage('Không thể thay đổi cài đặt lưu thông báo: $e');
    }
  }

  // Đặt lại cài đặt mặc định
  Future<void> _resetToDefaults() async {
    try {
      await _settingsChannel.invokeMethod('resetToDefaults');
      await _loadSettings();
      _showSuccessMessage('Đã đặt lại cài đặt mặc định');
    } catch (e) {
      _showErrorMessage('Không thể đặt lại cài đặt: $e');
    }
  }

  // Hiển thị thông báo thành công
  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Hiển thị thông báo lỗi
  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    return _isLoading
        ? Center(
            child: Container(
              width: screenWidth * 0.1,
              height: screenWidth * 0.1,
              child: const CircularProgressIndicator(),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadSettings,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth * 0.04),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                width: screenWidth,
                constraints: BoxConstraints(minHeight: screenHeight * 0.9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề
                    Container(
                      width: double.infinity,
                      child: const Text(
                        'Cài đặt ứng dụng',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    
                    // Cài đặt số luồng thông báo - Hàng trên 10%
                    Container(
                      width: double.infinity,
                      height: screenHeight * 0.1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Bên trái: Combo box chọn số luồng
                          Expanded(
                            child: Row(
                              children: [
                                const Text(
                                  'Số luồng xử lý: ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue),
                                  ),
                                  child: DropdownButton<int>(
                                    value: _notificationThreads,
                                    underline: Container(),
                                    items: _availableThreads.map((int value) {
                                      return DropdownMenuItem<int>(
                                        value: value,
                                        child: Text('$value'),
                                      );
                                    }).toList(),
                                    onChanged: (int? newValue) {
                                      if (newValue != null) {
                                        _changeThreads(newValue);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Bên phải: Switch bật/tắt lưu thông báo
                          Container(
                            child: Row(
                              children: [
                                const Text(
                                  'Lưu thông báo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Switch(
                                  value: _saveNotifications,
                                  onChanged: (value) => _toggleSaveNotifications(),
                                  activeColor: Colors.blue,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Chú thích số luồng - 20% và có cuộn dọc
                    Container(
                      width: double.infinity,
                      height: screenHeight * 0.2,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Việc tăng số luồng sẽ không ảnh hưởng đến hiệu xuất chung của máy. '
                            'Việc này sẽ cần thiết trong tình huống có nhiều thông báo diễn ra đồng thời! '
                            'Do mạng tiêu tốn ít tài nguyên và trong tình huống đặc biệt số luồng càng cao '
                            'sẽ sử lý các thông báo tức thì.',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.03),
                    
                    // Chú thích lưu thông báo - 20% và có cuộn dọc
                    Container(
                      width: double.infinity,
                      height: screenHeight * 0.2,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Việc tắt lưu thông báo sẽ chỉ tắt lưu thông báo ở mục tất cả thông báo, '
                            'các thông báo giao dịch sẽ không ảnh hưởng. Nếu bạn muốn xem thông báo và '
                            'trích xuất thông báo và sử lý, có thể bật để xem lại các thông báo.',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.03),
                    
                    // Nút đặt lại cài đặt mặc định
                    Center(
                      child: Container(
                        width: screenWidth * 0.6,
                        height: screenHeight * 0.06,
                        child: ElevatedButton.icon(
                          onPressed: _resetToDefaults,
                          icon: const Icon(Icons.restore),
                          label: const Text('Đặt lại cài đặt mặc định'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04, 
                              vertical: screenHeight * 0.015
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    
                    // Thông tin phiên bản
                    Container(
                      width: double.infinity,
                      height: screenHeight * 0.05,
                      child: const Center(
                        child: Text(
                          'Phiên bản 1.0.0',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                  ],
                ),
              ),
            ),
          );
  }
}
