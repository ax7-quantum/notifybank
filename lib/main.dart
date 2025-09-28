
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'bank/notification_view.dart';
import 'bank/cake_transaction_view.dart';
import 'bank/mb_transaction_view.dart';
import 'bank/MomoTransactionView.dart';
import 'sms_manager_view.dart';
import 'permissions_screen.dart';
import 'app_settings_view.dart';
import 'intro_screen.dart';  // Tạo file này sau

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'quản lý giao dịch',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MethodChannel _channel = const MethodChannel('com.x319.notifybank/notification');
  final MethodChannel _smsChannel = const MethodChannel('com.x319.notifybank/sms');
  final MethodChannel _smsReceiverChannel = const MethodChannel('com.x319.notifybank/sms_receiver');
  final MethodChannel _contactsChannel = const MethodChannel('com.x319.notifybank/contacts');
  final MethodChannel _bankApiChannel = const MethodChannel('com.x319.notifybank/bankapi');
  final MethodChannel _appInfoChannel = const MethodChannel('com.x319.notifybank/app_info');

  bool _notificationPermissionGranted = false;
  bool _smsPermissionGranted = false;
  bool _isServiceRunning = false;
  bool _isLoading = true;
  bool _shouldShowIntroDialog = false;
  
  // Biến để theo dõi chế độ hiển thị
  String _currentView = 'none'; // 'none', 'notifications', 'transactions', 'mb_transactions', 'momo_transactions', 'settings'
  
  // Biến lưu thông tin giao dịch
  int _mbBankCount = 0;
  int _cakeCount = 0;
  int _momoCount = 0;
  int _totalCount = 0;
  String _latestBankType = '';
  int _latestTimestamp = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _checkIntroDialog();
    _loadTransactionData();
  }

  // Tải dữ liệu giao dịch từ native
  Future<void> _loadTransactionData() async {
    try {
      final String? transactionData = await _bankApiChannel.invokeMethod('getAllTransactions');
      if (transactionData != null) {
        final Map<String, dynamic> data = json.decode(transactionData);
        
        setState(() {
          // Lấy số lượng giao dịch
          final Map<String, dynamic> summary = data['summary'];
          _mbBankCount = summary['MB_BANK'] ?? 0;
          _cakeCount = summary['CAKE'] ?? 0;
          _momoCount = summary['MOMO'] ?? 0;
          _totalCount = summary['TOTAL'] ?? 0;
          
          // Lấy thông tin giao dịch mới nhất
          if (data.containsKey('latestTransaction')) {
            final Map<String, dynamic> latest = data['latestTransaction'];
            _latestBankType = latest['bankType'] ?? '';
            _latestTimestamp = latest['timestamp'] ?? 0;
          }
        });
      }
    } on PlatformException catch (e) {
      print("Lỗi khi tải dữ liệu giao dịch: ${e.message}");
    }
  }

  // Kiểm tra xem có nên hiển thị hộp thoại giới thiệu không
  Future<void> _checkIntroDialog() async {
    try {
      final bool shouldShow = await _appInfoChannel.invokeMethod('shouldShowIntroDialog');
      setState(() {
        _shouldShowIntroDialog = shouldShow;
      });
      
      if (shouldShow) {
        // Hiển thị hộp thoại giới thiệu sau khi build hoàn tất
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showIntroDialog();
        });
      }
    } on PlatformException catch (e) {
      print("Lỗi khi kiểm tra hộp thoại giới thiệu: ${e.message}");
    }
  }
  
  // Hiển thị hộp thoại giới thiệu
  void _showIntroDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Chào mừng đến với ứng dụng'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Để có thể cấp quyền, xin vui lòng bấm vào đây để mở cài đặt thông tin ứng dụng, sau đó click vào mục cho phép cài đặt giới hạn và sau đó quay trở lại ứng dụng và cấp quyền.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ứng dụng này sẽ có dịch vụ chạy nền để nhận và xử lý thông báo kể cả khi ứng dụng bị đóng.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IntroScreen(),
                      ),
                    );
                  },
                  child: const Text('Đọc giới thiệu về ứng dụng'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    try {
                      await _appInfoChannel.invokeMethod('openAppInfo');
                    } catch (e) {
                      print("Lỗi khi mở cài đặt thông tin ứng dụng: $e");
                    }
                  },
                  child: const Text('Mở cài đặt thông tin ứng dụng'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Đánh dấu đã hiển thị hộp thoại
                try {
                  await _appInfoChannel.invokeMethod('markIntroDialogShown');
                } catch (e) {
                  print("Lỗi khi đánh dấu hộp thoại đã hiển thị: $e");
                }
                Navigator.of(context).pop();
              },
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  // Kiểm tra quyền cơ bản cần thiết
  Future<void> _checkPermissions() async {
    try {
      final bool notificationPermission = await _channel.invokeMethod('checkNotificationPermission');
      final bool serviceRunning = await _channel.invokeMethod('isServiceRunning');
      final bool smsPermission = await _smsChannel.invokeMethod('checkSmsPermission');

      setState(() {
        _notificationPermissionGranted = notificationPermission;
        _isServiceRunning = serviceRunning;
        _smsPermissionGranted = smsPermission;
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi kiểm tra quyền: ${e.message}");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Mở màn hình quyền
  void _openPermissionsScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PermissionsScreen(
          channel: _channel,
          smsChannel: _smsChannel,
          smsReceiverChannel: _smsReceiverChannel,
          contactsChannel: _contactsChannel,
        ),
      ),
    );
    
    if (result == true) {
      // Nếu có thay đổi quyền, cập nhật lại trạng thái
      _checkPermissions();
    }
  }

  // Mở cài đặt thông tin ứng dụng
  void _openAppInfo() async {
    try {
      await _appInfoChannel.invokeMethod('openAppInfo');
    } catch (e) {
      print("Lỗi khi mở cài đặt thông tin ứng dụng: $e");
    }
  }

  // Hiển thị màn hình thông báo
  void _showNotificationView() {
    if (_notificationPermissionGranted) {
      setState(() {
        _currentView = 'notifications';
      });
    } else {
      _openPermissionsScreen();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấp quyền thông báo trước khi sử dụng tính năng này'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Hiển thị màn hình giao dịch Cake
  void _showCakeTransactionView() {
    if (_notificationPermissionGranted) {
      setState(() {
        _currentView = 'transactions';
      });
    } else {
      _openPermissionsScreen();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấp quyền thông báo trước khi sử dụng tính năng này'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Hiển thị màn hình giao dịch MB
  void _showMBTransactionView() {
    if (_notificationPermissionGranted) {
      setState(() {
        _currentView = 'mb_transactions';
      });
    } else {
      _openPermissionsScreen();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấp quyền thông báo trước khi sử dụng tính năng này'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Hiển thị màn hình giao dịch MoMo
  void _showMomoTransactionView() {
    if (_notificationPermissionGranted) {
      setState(() {
        _currentView = 'momo_transactions';
      });
    } else {
      _openPermissionsScreen();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấp quyền thông báo trước khi sử dụng tính năng này'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Mở màn hình quản lý tin nhắn SMS
  void _openSmsManager() {
    if (_smsPermissionGranted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SmsManagerView(),
        ),
      );
    } else {
      _openPermissionsScreen();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấp quyền SMS trước khi sử dụng tính năng này'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Mở màn hình cài đặt ứng dụng
  void _openAppSettings() {
    setState(() {
      _currentView = 'settings';
    });
  }
  
  // Hiển thị màn hình giao dịch tương ứng với ngân hàng của giao dịch mới nhất
  void _showLatestTransactionView() {
    if (_latestBankType.isEmpty) return;
    
    switch (_latestBankType) {
      case 'MB_BANK':
        _showMBTransactionView();
        break;
      case 'CAKE':
        _showCakeTransactionView();
        break;
      case 'MOMO':
        _showMomoTransactionView();
        break;
      default:
        _showNotificationView();
        break;
    }
  }
  
  // Định dạng thời gian giao dịch mới nhất
  String _formatLatestTransactionTime() {
    if (_latestTimestamp == 0) return '';
    
    final DateTime now = DateTime.now();
    final DateTime transactionTime = DateTime.fromMillisecondsSinceEpoch(_latestTimestamp);
    final Duration difference = now.difference(transactionTime);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} giây trước';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else {
      return '${difference.inDays} ngày trước';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;
    
    // Tính toán chiều cao cho mỗi hàng nút (10% chiều cao màn hình)
    final double rowHeight = screenHeight * 0.1;
    // Tính toán chiều cao cho phần thông tin giao dịch (11% chiều cao màn hình)
    final double transactionInfoHeight = screenHeight * 0.11;

    return Scaffold(
      appBar: AppBar(
        title: const Text('quản lý giao dịch'),
        actions: [

    IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Giới thiệu ứng dụng',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const IntroScreen(),
          ),
        );
      },
    ),
          // nút mở cài đặt thông tin ứng dụng
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Thông tin ứng dụng',
            onPressed: _openAppInfo,
          ),
          // Nút kiểm tra quyền
          IconButton(
            icon: const Icon(Icons.security),
            tooltip: 'Kiểm tra quyền',
            onPressed: _openPermissionsScreen,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Thông báo kiểm tra quyền
                if (!_notificationPermissionGranted || !_isServiceRunning)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cần thiết lập quyền!',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Vui lòng click vào "Kiểm tra quyền" và làm theo hướng dẫn trước khi sử dụng ứng dụng này!',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _openPermissionsScreen,
                          child: const Text('Kiểm tra'),
                        ),
                      ],
                    ),
                  ),
                
                // Hàng 1: Nút cài đặt, nút quản lý tin nhắn (10% chiều cao màn hình)
                SizedBox(
                  height: rowHeight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: screenWidth * 0.4,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: ElevatedButton.icon(
                              onPressed: _openAppSettings,
                              icon: const Icon(Icons.settings),
                              label: const Text('Cài đặt'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentView == 'settings' ? Colors.blue : null,
                                foregroundColor: _currentView == 'settings' ? Colors.white : null,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: screenWidth * 0.4,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: ElevatedButton.icon(
                              onPressed: _openSmsManager,
                              icon: const Icon(Icons.sms),
                              label: const Text('Quản lý tin nhắn'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Hàng 2: Xem tất cả thông báo, giao dịch Cake, giao dịch MB, giao dịch MoMo (10% chiều cao màn hình)
                SizedBox(
                  height: rowHeight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: screenWidth * 0.4,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: ElevatedButton.icon(
                              onPressed: _notificationPermissionGranted ? _showNotificationView : _openPermissionsScreen,
                              icon: const Icon(Icons.notifications),
                              label: const Text('Xem tất cả thông báo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentView == 'notifications' ? Colors.blue : null,
                                foregroundColor: _currentView == 'notifications' ? Colors.white : null,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: screenWidth * 0.4,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Stack(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _notificationPermissionGranted ? _showCakeTransactionView : _openPermissionsScreen,
                                  icon: const Icon(Icons.cake),
                                  label: const Text('Giao dịch Cake'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _currentView == 'transactions' ? Colors.blue : null,
                                    foregroundColor: _currentView == 'transactions' ? Colors.white : null,
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                                if (_cakeCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 22,
                                        minHeight: 22,
                                      ),
                                      child: Text(
                                        '$_cakeCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: screenWidth * 0.4,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Stack(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _notificationPermissionGranted ? _showMBTransactionView : _openPermissionsScreen,
                                  icon: const Icon(Icons.account_balance),
                                  label: const Text('Giao dịch MB'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _currentView == 'mb_transactions' ? Colors.blue : null,
                                    foregroundColor: _currentView == 'mb_transactions' ? Colors.white : null,
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                                if (_mbBankCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 22,
                                        minHeight: 22,
                                      ),
                                      child: Text(
                                        '$_mbBankCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: screenWidth * 0.4,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Stack(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _notificationPermissionGranted ? _showMomoTransactionView : _openPermissionsScreen,
                                  icon: const Icon(Icons.account_balance_wallet),
                                  label: const Text('Giao dịch MoMo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _currentView == 'momo_transactions' ? Colors.purple : null,
                                    foregroundColor: _currentView == 'momo_transactions' ? Colors.white : null,
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                                if (_momoCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 22,
                                        minHeight: 22,
                                      ),
                                      child: Text(
                                        '$_momoCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Phần thông tin giao dịch (11% chiều cao màn hình)
                SizedBox(
                  height: transactionInfoHeight,
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tổng số giao dịch: $_totalCount',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (_latestTimestamp > 0)
                                Text(
                                  _formatLatestTransactionTime(),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_latestBankType.isNotEmpty)
                            Row(
                              children: [
                                Text(
                                  'Giao dịch mới nhất: ${_latestBankType.replaceAll('_', ' ')}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _showLatestTransactionView,
                                  child: const Text('Xem'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Hiển thị nội dung tương ứng với chế độ xem hiện tại (69% chiều cao màn hình còn lại)
                if (_currentView == 'none')
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.touch_app, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Chọn loại thông báo để xem',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_currentView == 'notifications')
                  const Expanded(child: NotificationView())
                else if (_currentView == 'transactions')
                  const Expanded(child: CakeTransactionView())
                else if (_currentView == 'mb_transactions')
                  const Expanded(child: MBTransactionView())
                else if (_currentView == 'momo_transactions')
                  const Expanded(child: MomoTransactionView())
                else if (_currentView == 'settings')
                  const Expanded(child: AppSettingsView()),
              ],
            ),
    );
  }
}
