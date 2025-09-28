import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'BankApiAddEditScreen.dart';

import 'ApiGuideAndTestScreen.dart'; // Import màn hình hướng dẫn API

class BankApiManagerScreen extends StatefulWidget {
  final String bankType; // "MB_BANK" hoặc "CAKE"
  final String bankName; // Tên hiển thị của ngân hàng

  const BankApiManagerScreen({
    Key? key,
    required this.bankType,
    required this.bankName,
  }) : super(key: key);

  @override
  State<BankApiManagerScreen> createState() => _BankApiManagerScreenState();
}

class _BankApiManagerScreenState extends State<BankApiManagerScreen> {
  final MethodChannel _bankApiChannel = const MethodChannel('com.x319.notifybank/bankapi');
  List<Map<String, dynamic>> _apiList = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadApis();
  }

  // Tải danh sách API
  Future<void> _loadApis() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String apisJson = await _bankApiChannel.invokeMethod('getAllApis', {
        'bankType': widget.bankType,
      });
      
      final List<dynamic> apis = jsonDecode(apisJson);
      setState(() {
        _apiList = apis.map((api) => Map<String, dynamic>.from(api)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Không thể tải danh sách API: ${e.toString()}');
    }
  }

  // Xóa API
  Future<void> _removeApi(String name) async {
    try {
      await _bankApiChannel.invokeMethod('removeApi', {
        'bankType': widget.bankType,
        'name': name,
      });
      
      await _loadApis();
      _showSuccessSnackBar('Xóa API thành công');
    } catch (e) {
      _showErrorDialog('Không thể xóa API: ${e.toString()}');
    }
  }

  // Bật/tắt API
  Future<void> _toggleApiEnabled(String name, bool enabled) async {
    try {
      await _bankApiChannel.invokeMethod('setApiEnabled', {
        'bankType': widget.bankType,
        'name': name,
        'enabled': enabled,
      });
      
      setState(() {
        final apiIndex = _apiList.indexWhere((api) => api['name'] == name);
        if (apiIndex != -1) {
          _apiList[apiIndex]['enabled'] = enabled;
        }
      });
      
      _showSuccessSnackBar(enabled ? 'Đã bật API' : 'Đã tắt API');
    } catch (e) {
      _showErrorDialog('Không thể thay đổi trạng thái API: ${e.toString()}');
      await _loadApis();
    }
  }

  // Cập nhật cài đặt thông báo
  Future<void> _updateNotificationSettings(String name, bool notifyOnMoneyIn, bool notifyOnMoneyOut) async {
    try {
      await _bankApiChannel.invokeMethod('updateNotificationSettings', {
        'bankType': widget.bankType,
        'name': name,
        'notifyOnMoneyIn': notifyOnMoneyIn,
        'notifyOnMoneyOut': notifyOnMoneyOut,
      });
      
      await _loadApis();
      _showSuccessSnackBar('Cập nhật cài đặt thông báo thành công');
    } catch (e) {
      _showErrorDialog('Không thể cập nhật cài đặt thông báo: ${e.toString()}');
    }
  }

  // Cập nhật cài đặt thử lại
  Future<void> _updateRetryConfig(String name, bool retryOnFailure, int maxRetries, int retryDelayMs) async {
    try {
      await _bankApiChannel.invokeMethod('updateRetryConfig', {
        'bankType': widget.bankType,
        'name': name,
        'retryOnFailure': retryOnFailure,
        'maxRetries': maxRetries,
        'retryDelayMs': retryDelayMs,
      });
      
      await _loadApis();
      _showSuccessSnackBar('Cập nhật cài đặt thử lại thành công');
    } catch (e) {
      _showErrorDialog('Không thể cập nhật cài đặt thử lại: ${e.toString()}');
    }
  }

  // Hiển thị dialog lỗi
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lỗi'),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // Hiển thị thông báo thành công
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Xác nhận xóa API
  void _confirmRemoveApi(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa API "$name" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeApi(name);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Hiển thị màn hình chỉnh sửa API
  void _showEditScreen(Map<String, dynamic> api) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => BankApiEditScreen(
          bankType: widget.bankType,
          bankName: widget.bankName,
          existingApi: api,
          onApiSaved: () => _loadApis(),
        ),
      ),
    );
  }

  // Chuyển đến màn hình hướng dẫn API
  void _navigateToApiGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ApiGuideAndTestScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight * 0.15),
        child: AppBar(
          title: Text('Quản lý API ${widget.bankName}'),
          actions: [
            // Thêm nút hướng dẫn API trong AppBar
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Hướng dẫn API',
              onPressed: _navigateToApiGuide,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(screenHeight * 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Danh sách API', 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white
                    )
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => BankApiAddEditScreen(
                            bankType: widget.bankType,
                            bankName: widget.bankName,
                            onApiSaved: () => _loadApis(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm API'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Thêm banner hướng dẫn ở đầu màn hình
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Chưa biết cách cấu hình API? Xem hướng dẫn chi tiết và test API của bạn.',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                TextButton(
                  onPressed: _navigateToApiGuide,
                  child: const Text('XEM NGAY'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
          
          // Phần còn lại của màn hình
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _apiList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Chưa có API nào được cấu hình',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _navigateToApiGuide,
                              icon: const Icon(Icons.help_outline),
                              label: const Text('Xem hướng dẫn cấu hình API'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadApis,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _apiList.length,
                          itemBuilder: (context, index) {
                            final api = _apiList[index];
                            return Container(
                              height: screenHeight * 0.3,
                              margin: const EdgeInsets.only(bottom: 16.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Tên API - 7%
                                  Container(
                                    height: screenHeight * 0.07,
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8.0),
                                        topRight: Radius.circular(8.0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Tên API:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Text(
                                              api['name'],
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: api['enabled'] ?? false,
                                          onChanged: (value) => _toggleApiEnabled(api['name'], value),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // URL API - 7%
                                  Container(
                                    height: screenHeight * 0.07,
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'URL:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Text(
                                              api['url'],
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // API Key - 7%
                                  Container(
                                    height: screenHeight * 0.07,
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'API Key:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Text(
                                              api['key'],
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Nút hành động - 7%
                                  Container(
                                    height: screenHeight * 0.07,
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _confirmRemoveApi(api['name']),
                                            icon: const Icon(Icons.delete, color: Colors.white),
                                            label: const Text('Xóa', style: TextStyle(color: Colors.white)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16.0),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _showEditScreen(api),
                                            icon: const Icon(Icons.edit),
                                            label: const Text('Chỉnh sửa'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      // Giữ lại nút FAB để truy cập nhanh vào màn hình hướng dẫn
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToApiGuide,
        icon: const Icon(Icons.help),
        label: const Text('Hướng dẫn API'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

// Màn hình chỉnh sửa API với bố cục mới
class BankApiEditScreen extends StatefulWidget {
  final String bankType;
  final String bankName;
  final Map<String, dynamic> existingApi;
  final Function onApiSaved;

  const BankApiEditScreen({
    Key? key,
    required this.bankType,
    required this.bankName,
    required this.existingApi,
    required this.onApiSaved,
  }) : super(key: key);

  @override
  _BankApiEditScreenState createState() => _BankApiEditScreenState();
}

class _BankApiEditScreenState extends State<BankApiEditScreen> {
  final MethodChannel _bankApiChannel = const MethodChannel('com.x319.notifybank/bankapi');
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _keyController;
  
  bool _enabled = true;
  bool _notifyOnMoneyIn = true;
  bool _notifyOnMoneyOut = false;
  bool _retryOnFailure = true;
  late TextEditingController _maxRetriesController;
  late TextEditingController _retryDelayMsController;
  
  @override
  void initState() {
    super.initState();
    
    // Khởi tạo các controller với giá trị từ API hiện có
    _nameController = TextEditingController(text: widget.existingApi['name']);
    _urlController = TextEditingController(text: widget.existingApi['url']);
    _keyController = TextEditingController(text: widget.existingApi['key']);
    
    _enabled = widget.existingApi['enabled'] ?? true;
    _notifyOnMoneyIn = widget.existingApi['notifyOnMoneyIn'] ?? true;
    _notifyOnMoneyOut = widget.existingApi['notifyOnMoneyOut'] ?? false;
    _retryOnFailure = widget.existingApi['retryOnFailure'] ?? true;
    
    _maxRetriesController = TextEditingController(
      text: (widget.existingApi['maxRetries'] ?? 3).toString()
    );
    _retryDelayMsController = TextEditingController(
      text: (widget.existingApi['retryDelayMs'] ?? 3000).toString()
    );
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _keyController.dispose();
    _maxRetriesController.dispose();
    _retryDelayMsController.dispose();
    super.dispose();
  }
  
  // Lưu thay đổi API
  Future<void> _saveApi() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    try {
      await _bankApiChannel.invokeMethod('updateApi', {
        'bankType': widget.bankType,
        'oldName': widget.existingApi['name'],
        'name': _nameController.text,
        'url': _urlController.text,
        'key': _keyController.text,
        'enabled': _enabled,
        'notifyOnMoneyIn': _notifyOnMoneyIn,
        'notifyOnMoneyOut': _notifyOnMoneyOut,
        'retryOnFailure': _retryOnFailure,
        'maxRetries': int.parse(_maxRetriesController.text),
        'retryDelayMs': int.parse(_retryDelayMsController.text),
      });
      
      widget.onApiSaved();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật API thành công'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Điều hướng đến màn hình hướng dẫn API
  void _navigateToApiGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ApiGuideAndTestScreen(),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Chỉnh sửa API ${widget.bankName}'),
        actions: [
          // Thêm nút hướng dẫn trong AppBar
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Xem hướng dẫn API',
            onPressed: _navigateToApiGuide,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner hướng dẫn
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.amber),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cần trợ giúp về cách cấu hình API? Xem hướng dẫn chi tiết và test API của bạn.',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToApiGuide,
                      child: const Text('XEM HƯỚNG DẪN'),
                    ),
                  ],
                ),
              ),
              
              // Phần cấu hình cơ bản
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin cơ bản',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên API',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập tên API';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL',
                        border: OutlineInputBorder(),
                        helperText: 'Ví dụ: https://api.example.com/webhook',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập URL';
                        }
                        if (!value.startsWith('http://') && !value.startsWith('https://')) {
                          return 'URL phải bắt đầu bằng http:// hoặc https://';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        border: OutlineInputBorder(),
                        helperText: 'Khóa xác thực cho API của bạn',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập API Key';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        const Text('Trạng thái:'),
                        const SizedBox(width: 16.0),
                        Switch(
                          value: _enabled,
                          onChanged: (value) {
                            setState(() {
                              _enabled = value;
                            });
                          },
                        ),
                        Text(_enabled ? 'Đang bật' : 'Đang tắt'),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Phần cài đặt thông báo
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cài đặt thông báo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        const Text('Thông báo tiền vào:'),
                        const SizedBox(width: 16.0),
                        Switch(
                          value: _notifyOnMoneyIn,
                          onChanged: (value) {
                            setState(() {
                              _notifyOnMoneyIn = value;
                            });
                          },
                        ),
                        Text(_notifyOnMoneyIn ? 'Bật' : 'Tắt'),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        const Text('Thông báo tiền ra:'),
                        const SizedBox(width: 16.0),
                        Switch(
                          value: _notifyOnMoneyOut,
                          onChanged: (value) {
                            setState(() {
                              _notifyOnMoneyOut = value;
                            });
                          },
                        ),
                        Text(_notifyOnMoneyOut ? 'Bật' : 'Tắt'),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Phần cài đặt thử lại
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cài đặt thử lại',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        const Text('Thử lại khi thất bại:'),
                        const SizedBox(width: 16.0),
                        Switch(
                          value: _retryOnFailure,
                          onChanged: (value) {
                            setState(() {
                              _retryOnFailure = value;
                            });
                          },
                        ),
                        Text(_retryOnFailure ? 'Bật' : 'Tắt'),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _maxRetriesController,
                      decoration: const InputDecoration(
                        labelText: 'Số lần thử lại tối đa',
                        border: OutlineInputBorder(),
                        helperText: 'Số lần thử lại khi gặp lỗi (khuyến nghị: 3-5 lần)',
                      ),
                      keyboardType: TextInputType.number,
                      enabled: _retryOnFailure,
                      validator: (value) {
                        if (_retryOnFailure) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập số lần thử lại';
                          }
                          if (int.tryParse(value) == null || int.parse(value) < 0) {
                            return 'Số lần thử lại phải là số nguyên không âm';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _retryDelayMsController,
                      decoration: const InputDecoration(
                        labelText: 'Thời gian giữa các lần thử (ms)',
                        border: OutlineInputBorder(),
                        helperText: 'Thời gian chờ giữa các lần thử (khuyến nghị: 3000-5000ms)',
                      ),
                      keyboardType: TextInputType.number,
                      enabled: _retryOnFailure,
                      validator: (value) {
                        if (_retryOnFailure) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập thời gian chờ';
                          }
                          if (int.tryParse(value) == null || int.parse(value) < 0) {
                            return 'Thời gian chờ phải là số nguyên không âm';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              
              // Nút hướng dẫn và test API
              Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Xem hướng dẫn và test API'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.blue),
                  ),
                  onPressed: _navigateToApiGuide,
                ),
              ),
              
              // Nút lưu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveApi,
                  child: const Text(
                    'Lưu thay đổi',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
