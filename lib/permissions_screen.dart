import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PermissionsScreen extends StatefulWidget {
  final MethodChannel channel;
  final MethodChannel smsChannel;
  final MethodChannel smsReceiverChannel;
  final MethodChannel contactsChannel; // Thêm channel danh bạ

  const PermissionsScreen({
    Key? key,
    required this.channel,
    required this.smsChannel,
    required this.smsReceiverChannel,
    required this.contactsChannel, // Thêm tham số mới
  }) : super(key: key);

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  // Thêm biến kênh đúng
  late final MethodChannel _correctSmsReceiverChannel;
  
  bool _notificationPermissionGranted = false;
  bool _batteryOptimizationDisabled = false;
  bool _needsAutoStartPermission = false;
  bool _isServiceRunning = false;
  
  // SMS permissions
  bool _sendSmsPermissionGranted = false;
  bool _readSmsPermissionGranted = false;
  bool _receiveSmsPermissionGranted = false;
  bool _phoneStatePermissionGranted = false;
  
  // Contacts permissions
  bool _contactsPermissionGranted = false;
  
  bool _isLoading = true;
  bool _permissionsChanged = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo kênh đúng
    _correctSmsReceiverChannel = const MethodChannel('com.x319.notifybank/sms_receiver');
    _checkPermissions();
  }

  // Kiểm tra tất cả các quyền cần thiết
  Future<void> _checkPermissions() async {
    try {
      final bool notificationPermission = await widget.channel.invokeMethod('checkNotificationPermission');
      final bool batteryOptimization = await widget.channel.invokeMethod('checkBatteryOptimization');
      final bool needsAutoStart = await widget.channel.invokeMethod('checkAutoStartPermission');
      final bool serviceRunning = await widget.channel.invokeMethod('isServiceRunning');
      
      // SMS permissions
      final bool sendSmsPermission = await widget.smsChannel.invokeMethod('checkSmsPermission');
      
      // Sử dụng kênh đúng
      final bool readSmsPermission = await _correctSmsReceiverChannel.invokeMethod('checkSmsReceiverPermission') ?? false;
      final bool receiveSmsPermission = await _correctSmsReceiverChannel.invokeMethod('checkSmsReceiverPermission') ?? false;
      final bool phoneStatePermission = await widget.smsChannel.invokeMethod('checkPhoneStatePermission') ?? false;
      
      // Contacts permissions
      final bool contactsPermission = await widget.contactsChannel.invokeMethod('checkContactsPermission') ?? false;

      setState(() {
        _notificationPermissionGranted = notificationPermission;
        _batteryOptimizationDisabled = batteryOptimization;
        _needsAutoStartPermission = needsAutoStart;
        _isServiceRunning = serviceRunning;
        
        _sendSmsPermissionGranted = sendSmsPermission;
        _readSmsPermissionGranted = readSmsPermission;
        _receiveSmsPermissionGranted = receiveSmsPermission;
        _phoneStatePermissionGranted = phoneStatePermission;
        
        _contactsPermissionGranted = contactsPermission;
        
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi kiểm tra quyền: ${e.message}");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Yêu cầu quyền đọc thông báo
  Future<void> _requestNotificationPermission() async {
    try {
      await widget.channel.invokeMethod('requestNotificationPermission');
      // Đợi một chút để người dùng có thời gian cấp quyền
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
      setState(() {
        _permissionsChanged = true;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi yêu cầu quyền thông báo: ${e.message}");
    }
  }

  // Yêu cầu quyền gửi SMS
  Future<void> _requestSendSmsPermission() async {
    try {
      await widget.smsChannel.invokeMethod('requestSmsPermission');
      // Đợi một chút để người dùng có thời gian cấp quyền
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
      setState(() {
        _permissionsChanged = true;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi yêu cầu quyền gửi SMS: ${e.message}");
    }
  }

  // Yêu cầu quyền đọc và nhận SMS
  Future<void> _requestSmsReceiverPermission() async {
    try {
      // Sử dụng kênh đúng thay vì widget.smsReceiverChannel
      await _correctSmsReceiverChannel.invokeMethod('requestSmsReceiverPermission');
      // Đợi một chút để người dùng có thời gian cấp quyền
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
      setState(() {
        _permissionsChanged = true;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi yêu cầu quyền đọc/nhận SMS: ${e.message}");
    }
  }

  // Yêu cầu quyền đọc trạng thái điện thoại
  Future<void> _requestPhoneStatePermission() async {
    try {
      await widget.smsChannel.invokeMethod('requestPhoneStatePermission');
      // Đợi một chút để người dùng có thời gian cấp quyền
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
      setState(() {
        _permissionsChanged = true;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi yêu cầu quyền đọc trạng thái điện thoại: ${e.message}");
    }
  }
  
  // Yêu cầu quyền danh bạ
  Future<void> _requestContactsPermission() async {
    try {
      await widget.contactsChannel.invokeMethod('requestContactsPermission');
      // Đợi một chút để người dùng có thời gian cấp quyền
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
      setState(() {
        _permissionsChanged = true;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi yêu cầu quyền danh bạ: ${e.message}");
    }
  }

  // Yêu cầu tắt tối ưu hóa pin
  Future<void> _requestBatteryOptimization() async {
    try {
      await widget.channel.invokeMethod('requestBatteryOptimization');
      // Đợi một chút để người dùng có thời gian cấp quyền
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
      setState(() {
        _permissionsChanged = true;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi yêu cầu tắt tối ưu hóa pin: ${e.message}");
    }
  }

  // Yêu cầu quyền tự khởi động
  Future<void> _requestAutoStartPermission() async {
    try {
      await widget.channel.invokeMethod('requestAutoStartPermission');
      // Đợi một chút để người dùng có thời gian cấp quyền
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
      setState(() {
        _permissionsChanged = true;
      });
      
      // Hiển thị thông báo hướng dẫn người dùng
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng bật quyền tự khởi động cho ứng dụng trong cài đặt'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on PlatformException catch (e) {
      print("Lỗi khi yêu cầu quyền tự khởi động: ${e.message}");
    }
  }

  // Khởi động lại dịch vụ thông báo
  Future<void> _restartNotificationService() async {
    try {
      await widget.channel.invokeMethod('restartNotificationService');
      // Hiển thị thông báo cho người dùng
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng tắt và bật lại quyền thông báo trong cài đặt'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      await Future.delayed(const Duration(seconds: 2));
      await _checkPermissions();
      setState(() {
        _permissionsChanged = true;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi khởi động lại dịch vụ: ${e.message}");
    }
  }

  // Kiểm tra xem tất cả các quyền cần thiết đã được cấp chưa
  bool get _allPermissionsGranted {
    return _notificationPermissionGranted && 
           _batteryOptimizationDisabled && 
           _isServiceRunning && 
           _sendSmsPermissionGranted &&
           _readSmsPermissionGranted &&
           _receiveSmsPermissionGranted &&
           _phoneStatePermissionGranted &&
           _contactsPermissionGranted; // Thêm kiểm tra quyền danh bạ
  }

  // Kiểm tra xem tất cả các quyền SMS đã được cấp chưa
  bool get _allSmsPermissionsGranted {
    return _sendSmsPermissionGranted &&
           _readSmsPermissionGranted &&
           _receiveSmsPermissionGranted;
  }

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;
    
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _permissionsChanged);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kiểm tra quyền'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, _permissionsChanged);
            },
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner thông báo (10% chiều cao màn hình)
                      Container(
                        height: screenHeight * 0.1,
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: _allPermissionsGranted ? Colors.green.shade100 : Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _allPermissionsGranted ? Colors.green.shade700 : Colors.amber.shade700,
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _allPermissionsGranted ? Icons.check_circle : Icons.info_outline,
                                      color: _allPermissionsGranted ? Colors.green.shade700 : Colors.amber.shade700,
                                      size: 28,
                                    ),
                                    SizedBox(width: screenWidth * 0.03),
                                    Text(
                                      _allPermissionsGranted
                                          ? 'Tất cả quyền đã được cấp!'
                                          : 'Vui lòng cấp các quyền cần thiết để ứng dụng hoạt động chính xác',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: _allPermissionsGranted ? Colors.green.shade700 : Colors.amber.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                if (!_allPermissionsGranted) ...[
                                  SizedBox(height: screenHeight * 0.01),
                                  const Text(
                                    'Ứng dụng cần các quyền này để có thể đọc thông báo, gửi/nhận SMS và hoạt động ổn định trong nền.',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: screenHeight * 0.03),
                      const Text(
                        'Trạng thái quyền:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      
                      // Quyền đọc thông báo
                      _buildPermissionItem(
                        context: context,
                        icon: Icons.notifications,
                        title: 'Quyền đọc thông báo',
                        description: 'Cho phép ứng dụng đọc thông báo từ các ứng dụng khác',
                        isGranted: _notificationPermissionGranted,
                        onRequest: _requestNotificationPermission,
                      ),
                      
                      // Phần quyền SMS - Tiêu đề
                      Container(
                        height: screenHeight * 0.05,
                        margin: EdgeInsets.only(bottom: screenHeight * 0.01, top: screenHeight * 0.01),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: const Text(
                            'Quyền SMS:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      
                      // Quyền gửi SMS
                      _buildPermissionItem(
                        context: context,
                        icon: Icons.send,
                        title: 'Quyền gửi SMS',
                        description: 'Cho phép ứng dụng gửi tin nhắn SMS',
                        isGranted: _sendSmsPermissionGranted,
                        onRequest: _requestSendSmsPermission,
                      ),
                      
                      // Quyền đọc SMS
                      _buildPermissionItem(
                        context: context,
                        icon: Icons.message,
                        title: 'Quyền đọc SMS',
                        description: 'Cho phép ứng dụng đọc tin nhắn SMS hiện có',
                        isGranted: _readSmsPermissionGranted,
                        onRequest: _requestSmsReceiverPermission,
                      ),
                      
                      // Quyền nhận SMS
                      _buildPermissionItem(
                        context: context,
                        icon: Icons.sms,
                        title: 'Quyền nhận SMS',
                        description: 'Cho phép ứng dụng nhận tin nhắn SMS mới',
                        isGranted: _receiveSmsPermissionGranted,
                        onRequest: _requestSmsReceiverPermission,
                      ),
                      
                      // Quyền đọc trạng thái điện thoại
                      _buildPermissionItem(
                        context: context,
                        icon: Icons.sim_card,
                        title: 'Quyền đọc trạng thái điện thoại',
                        description: 'Cho phép ứng dụng đọc thông tin SIM và điện thoại',
                        isGranted: _phoneStatePermissionGranted,
                        onRequest: _requestPhoneStatePermission,
                      ),
                      
                      // Phần quyền danh bạ - Tiêu đề
                      Container(
                        height: screenHeight * 0.05,
                        margin: EdgeInsets.only(bottom: screenHeight * 0.01, top: screenHeight * 0.01),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: const Text(
                            'Quyền danh bạ:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      
                      // Quyền danh bạ
                      _buildPermissionItem(
                        context: context,
                        icon: Icons.contacts,
                        title: 'Quyền truy cập danh bạ',
                        description: 'Cho phép ứng dụng đọc và quản lý danh bạ của bạn',
                        isGranted: _contactsPermissionGranted,
                        onRequest: _requestContactsPermission,
                      ),
                      
                      // Phần quyền hệ thống - Tiêu đề
                      Container(
                        height: screenHeight * 0.05,
                        margin: EdgeInsets.only(bottom: screenHeight * 0.01, top: screenHeight * 0.01),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: const Text(
                            'Quyền hệ thống:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      
                      // Trạng thái dịch vụ thông báo
                      _buildPermissionItem(
                        context: context,
                        icon: Icons.notifications_active,
                        title: 'Dịch vụ thông báo đang chạy',
                        description: 'Dịch vụ lắng nghe thông báo đang hoạt động',
                        isGranted: _isServiceRunning,
                        onRequest: _restartNotificationService,
                        buttonText: 'Khởi động lại',
                      ),
                      
                      // Quyền tắt tối ưu hóa pin
                      _buildPermissionItem(
                        context: context,
                        icon: Icons.battery_alert,
                        title: 'Tắt tối ưu hóa pin',
                        description: 'Cho phép ứng dụng chạy trong nền mà không bị hệ thống tắt',
                        isGranted: _batteryOptimizationDisabled,
                        onRequest: _requestBatteryOptimization,
                        buttonText: 'Tắt tối ưu hóa',
                      ),
                      
                      // Quyền tự khởi động
                      if (_needsAutoStartPermission)
                        _buildPermissionItem(
                          context: context,
                          icon: Icons.power_settings_new,
                          title: 'Quyền tự khởi động',
                          description: 'Cho phép ứng dụng tự khởi động khi thiết bị khởi động',
                          isGranted: false, // Không thể kiểm tra trạng thái này trên nhiều thiết bị
                          onRequest: _requestAutoStartPermission,
                          buttonText: 'Cài đặt',
                          warningColor: Colors.orange,
                        ),
                      
                      SizedBox(height: screenHeight * 0.03),
                      
                      // Nút cấp tất cả quyền SMS
                      if (!_allSmsPermissionsGranted)
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _requestSendSmsPermission();
                              await _requestSmsReceiverPermission();
                              await _requestPhoneStatePermission();
                            },
                            icon: const Icon(Icons.sms),
                            label: const Text('Cấp tất cả quyền SMS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.04, 
                                vertical: screenHeight * 0.015
                              ),
                            ),
                          ),
                        ),
                      
                      SizedBox(height: screenHeight * 0.02),
                      
                      // Nút khởi động lại dịch vụ
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _restartNotificationService,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Khởi động lại dịch vụ thông báo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04, 
                              vertical: screenHeight * 0.015
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: screenHeight * 0.02),
                      
                      // Thông tin hướng dẫn
                      Container(
                        height: screenHeight * 0.25,
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.help_outline, color: Colors.grey),
                                    SizedBox(width: screenWidth * 0.02),
                                    const Text(
                                      'Hướng dẫn',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenHeight * 0.01),
                                const Text(
                                  '1. Cấp tất cả các quyền được yêu cầu ở trên',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                const Text(
                                  '2. Quyền SMS cho phép ứng dụng gửi, nhận và đọc tin nhắn',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                const Text(
                                  '3. Quyền thông báo cho phép ứng dụng đọc thông báo từ các ứng dụng khác',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                const Text(
                                  '4. Quyền danh bạ cho phép ứng dụng đọc và quản lý danh bạ của bạn',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                const Text(
                                  '5. Nếu thông báo không hoạt động, hãy thử khởi động lại dịch vụ',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                const Text(
                                  '6. Trên một số thiết bị, bạn cần vào cài đặt hệ thống để bật quyền tự khởi động',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                const Text(
                                  '7. Đảm bảo ứng dụng không bị tắt khi chạy trong nền bằng cách tắt tối ưu hóa pin',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: screenHeight * 0.03),
                      
                      // Nút quay lại
                      if (_allPermissionsGranted)
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context, _permissionsChanged);
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Tất cả quyền đã được cấp, quay lại'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.04, 
                                vertical: screenHeight * 0.015
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // Widget hiển thị một mục quyền
  Widget _buildPermissionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
    String buttonText = 'Cấp quyền',
    Color? warningColor,
  }) {
    // Lấy kích thước màn hình
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;
    
    // Tổng chiều cao cho mỗi quyền là 20% chiều cao màn hình
    final double itemHeight = screenHeight * 0.2;
    // Chiều cao cho tiêu đề là 5% chiều cao màn hình
    final double titleHeight = screenHeight * 0.05;
    // Chiều cao cho nội dung là 10% chiều cao màn hình
    final double contentHeight = screenHeight * 0.1;
    // Chiều cao cho nút là 5% chiều cao màn hình
    final double buttonHeight = screenHeight * 0.05;
    
    return Container(
      height: itemHeight,
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGranted ? Colors.green.shade300 : (warningColor ?? Colors.red.shade300),
        ),
      ),
      child: Column(
        children: [
          // Phần tiêu đề - 5% chiều cao màn hình
          Container(
            height: titleHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isGranted ? Colors.green : (warningColor ?? Colors.red),
                    size: 24,
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Icon(
                    isGranted ? Icons.check_circle : Icons.cancel,
                    color: isGranted ? Colors.green : (warningColor ?? Colors.red),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          // Phần nội dung - 10% chiều cao màn hình
          Container(
            height: contentHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ),
          ),
          
          // Phần nút - 5% chiều cao màn hình
          if (!isGranted)
            Container(
              height: buttonHeight,
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ElevatedButton(
                  onPressed: onRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: warningColor ?? Colors.red.shade400,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(buttonText),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
