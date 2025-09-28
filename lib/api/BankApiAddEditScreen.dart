
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BankApiAddEditScreen extends StatefulWidget {
  final String bankType; // Nhận loại ngân hàng ("MB_BANK" hoặc "CAKE")
  final String bankName; // Tên hiển thị của ngân hàng (MB Bank hoặc Cake)
  final Map<String, dynamic>? existingApi; // API hiện có (nếu đang chỉnh sửa)
  final Function onApiSaved; // Callback khi lưu thành công

  const BankApiAddEditScreen({
    Key? key,
    required this.bankType,
    required this.bankName,
    this.existingApi,
    required this.onApiSaved,
  }) : super(key: key);

  @override
  State<BankApiAddEditScreen> createState() => _BankApiAddEditScreenState();
}

class _BankApiAddEditScreenState extends State<BankApiAddEditScreen> {
  final MethodChannel _bankApiChannel = const MethodChannel('com.x319.notifybank/bankapi');
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers cho các trường nhập liệu
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  late final TextEditingController _maxRetriesController;
  late final TextEditingController _retryDelayMsController;
  
  // Các giá trị cấu hình
  late bool _enabled;
  late bool _notifyOnMoneyIn;
  late bool _notifyOnMoneyOut;
  late bool _retryOnFailure;
  
  // Điều kiện
  late String _conditions;
  List<String> _conditionsList = [];
  int _nextConditionIndex = 1;

  @override
  void initState() {
    super.initState();
    
    // Khởi tạo giá trị từ API hiện có hoặc giá trị mặc định
    final isEditing = widget.existingApi != null;
    
    _nameController = TextEditingController(text: isEditing ? widget.existingApi!['name'] : '');
    _urlController = TextEditingController(text: isEditing ? widget.existingApi!['url'] : '');
    _keyController = TextEditingController(text: isEditing ? widget.existingApi!['key'] : '');
    _maxRetriesController = TextEditingController(
        text: (isEditing ? widget.existingApi!['maxRetries'] ?? 3 : 3).toString());
    _retryDelayMsController = TextEditingController(
        text: (isEditing ? widget.existingApi!['retryDelayMs'] ?? 3000 : 3000).toString());
    
    _enabled = isEditing ? widget.existingApi!['enabled'] ?? true : true;
    _notifyOnMoneyIn = isEditing ? widget.existingApi!['notifyOnMoneyIn'] ?? true : true;
    _notifyOnMoneyOut = isEditing ? widget.existingApi!['notifyOnMoneyOut'] ?? false : false;
    _retryOnFailure = isEditing ? widget.existingApi!['retryOnFailure'] ?? true : true;
    
    // Khởi tạo điều kiện
    _conditions = isEditing ? widget.existingApi!['conditions'] ?? '' : '';
    _parseExistingConditions();
  }

  // Phân tích điều kiện hiện có
  void _parseExistingConditions() {
    if (_conditions.isEmpty) {
      _nextConditionIndex = 1;
      return;
    }
    
    // Sử dụng regex để tách các phần điều kiện theo mẫu *X#...#
    RegExp conditionPattern = RegExp(r'\*(\d+)#([^*]+)#');
    Iterable<RegExpMatch> matches = conditionPattern.allMatches(_conditions);
    
    _conditionsList = [];
    int maxIndex = 0;
    
    for (var match in matches) {
      int index = int.parse(match.group(1)!);
      String content = match.group(2)!;
      
      if (index > maxIndex) {
        maxIndex = index;
      }
      
      _conditionsList.add('*$index#$content#');
    }
    
    // Cập nhật chỉ số tiếp theo
    _nextConditionIndex = maxIndex + 1;
  }

  @override
  void dispose() {
    // Giải phóng tài nguyên
    _nameController.dispose();
    _urlController.dispose();
    _keyController.dispose();
    _maxRetriesController.dispose();
    _retryDelayMsController.dispose();
    super.dispose();
  }

  // Thêm API mới
  Future<void> _addApi() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Chuyển đổi giá trị số
      final int maxRetries = int.parse(_maxRetriesController.text);
      final int retryDelayMs = int.parse(_retryDelayMsController.text);

      await _bankApiChannel.invokeMethod('addApi', {
        'bankType': widget.bankType,
        'name': _nameController.text,
        'apiUrl': _urlController.text,
        'apiKey': _keyController.text,
        'enabled': _enabled,
        'notifyOnMoneyIn': _notifyOnMoneyIn,
        'notifyOnMoneyOut': _notifyOnMoneyOut,
        'retryOnFailure': _retryOnFailure,
        'maxRetries': maxRetries,
        'retryDelayMs': retryDelayMs,
        'conditions': _conditions,
      });
      
      setState(() {
        _isLoading = false;
      });

      // Gọi callback và quay lại màn hình trước
      widget.onApiSaved();
      Navigator.pop(context);
      _showSuccessSnackBar('Thêm API thành công');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Không thể thêm API: ${e.toString()}');
    }
  }

  // Cập nhật API
  Future<void> _updateApi() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Chuyển đổi giá trị số
      final int maxRetries = int.parse(_maxRetriesController.text);
      final int retryDelayMs = int.parse(_retryDelayMsController.text);

      await _bankApiChannel.invokeMethod('updateApi', {
        'bankType': widget.bankType,
        'name': _nameController.text,
        'apiUrl': _urlController.text,
        'apiKey': _keyController.text,
        'enabled': _enabled,
        'notifyOnMoneyIn': _notifyOnMoneyIn,
        'notifyOnMoneyOut': _notifyOnMoneyOut,
        'retryOnFailure': _retryOnFailure,
        'maxRetries': maxRetries,
        'retryDelayMs': retryDelayMs,
        'conditions': _conditions,
      });
      
      setState(() {
        _isLoading = false;
      });

      // Gọi callback và quay lại màn hình trước
      widget.onApiSaved();
      Navigator.pop(context);
      _showSuccessSnackBar('Cập nhật API thành công');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Không thể cập nhật API: ${e.toString()}');
    }
  }

  // Thêm điều kiện mới
  void _addNewCondition(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thêm điều kiện'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.numbers),
              title: Text('Điều kiện số'),
              subtitle: Text('Ví dụ: 1=5000'),
              onTap: () {
                Navigator.pop(context);
                _showNumberConditionDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.text_fields),
              title: Text('Điều kiện từ khóa'),
              subtitle: Text('Ví dụ: vip1, vip2, vip3'),
              onTap: () {
                Navigator.pop(context);
                _showKeywordConditionDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
        ],
      ),
    );
  }

  // Dialog thêm điều kiện số
  void _showNumberConditionDialog() {
    final TextEditingController rangeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Điều kiện số'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nhập khoảng số (ví dụ: 1=5000) để kiểm tra số tiền trong nội dung giao dịch.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              controller: rangeController,
              decoration: InputDecoration(
                labelText: 'Khoảng số',
                hintText: 'Ví dụ: 1=5000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (rangeController.text.isNotEmpty) {
                // Tạo chuỗi điều kiện
                String condition = '*${_nextConditionIndex}#${rangeController.text}#';
                setState(() {
                  _conditionsList.add(condition);
                  _nextConditionIndex++;
                  _updateConditionsString();
                });
                Navigator.pop(context);
              }
            },
            child: Text('Thêm'),
          ),
        ],
      ),
    );
  }

  // Dialog thêm điều kiện từ khóa
  void _showKeywordConditionDialog() {
    final TextEditingController keywordsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Điều kiện từ khóa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nhập các từ khóa, mỗi từ khóa cách nhau bởi dấu phẩy.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              controller: keywordsController,
              decoration: InputDecoration(
                labelText: 'Từ khóa',
                hintText: 'Ví dụ: vip1, vip2, vip3',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (keywordsController.text.isNotEmpty) {
                // Xử lý từ khóa và tạo chuỗi điều kiện
                List<String> keywords = keywordsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                
                if (keywords.isNotEmpty) {
                  // Tạo chuỗi điều kiện từ khóa
                  String keywordString = '*' + keywords.join('*');
                  String condition = '*${_nextConditionIndex}#$keywordString#';
                  
                  setState(() {
                    _conditionsList.add(condition);
                    _nextConditionIndex++;
                    _updateConditionsString();
                  });
                }
                Navigator.pop(context);
              }
            },
            child: Text('Thêm'),
          ),
        ],
      ),
    );
  }

  // Cập nhật chuỗi điều kiện từ danh sách
  void _updateConditionsString() {
    _conditions = _conditionsList.join('');
  }

  // Xóa điều kiện
  void _removeCondition(int index) {
    setState(() {
      _conditionsList.removeAt(index);
      _updateConditionsString();
    });
  }

  // Hiển thị nội dung điều kiện dễ đọc
  String _getReadableCondition(String condition) {
    // Tách điều kiện theo mẫu *X#...#
    RegExp conditionPattern = RegExp(r'\*(\d+)#([^#]+)#');
    var match = conditionPattern.firstMatch(condition);
    
    if (match != null) {
      String index = match.group(1)!;
      String content = match.group(2)!;
      
      // Kiểm tra loại điều kiện
      if (content.contains('=')) {
        // Điều kiện số
        return 'Điều kiện $index: Số tiền trong khoảng $content';
      } else if (content.startsWith('*')) {
        // Điều kiện từ khóa
        String keywords = content.substring(1).replaceAll('*', ', ');
        return 'Điều kiện $index: Có chứa từ khóa: $keywords';
      }
      
      return 'Điều kiện $index: $content';
    }
    
    return condition;
  }

  // Hiển thị dialog lỗi
  void _showErrorDialog(String message) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lỗi'),
        content: Container(
          width: screenWidth * 0.8,
          constraints: BoxConstraints(maxHeight: screenHeight * 0.3),
          child: SingleChildScrollView(
            child: Text(message),
          ),
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

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    final bool isEditing = widget.existingApi != null;
    final bool nameEnabled = !isEditing; // Không cho phép sửa tên API nếu đang chỉnh sửa
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa API' : 'Thêm API mới'),
        actions: [
          if (_isLoading)
            Container(
              width: screenWidth * 0.1,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: isEditing ? _updateApi : _addApi,
              tooltip: 'Lưu',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin cơ bản
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                child: Text(
                  'Thông tin cơ bản',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              
              // Tên API
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên API',
                  hintText: 'Nhập tên API',
                  border: OutlineInputBorder(),
                ),
                enabled: nameEnabled,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tên API';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // URL API
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL API',
                  hintText: 'Nhập URL API',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập URL API';
                  }
                  if (!Uri.parse(value).isAbsolute) {
                    return 'URL không hợp lệ';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // API Key
              TextFormField(
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Nhập API Key',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập API Key';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // Trạng thái API
              Row(
                children: [
                  const Text('Trạng thái:'),
                  SizedBox(width: screenWidth * 0.02),
                  Switch(
                    value: _enabled,
                    onChanged: (value) {
                      setState(() {
                        _enabled = value;
                      });
                    },
                  ),
                  Text(_enabled ? 'Bật' : 'Tắt'),
                ],
              ),
              
              Divider(height: screenHeight * 0.04),
              
              // Cài đặt điều kiện
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Điều kiện gọi API',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Thêm điều kiện'),
                      onPressed: () => _addNewCondition(context),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              
              // Hướng dẫn về điều kiện
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hướng dẫn thiết lập điều kiện:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Điều kiện số: Kiểm tra số tiền trong nội dung giao dịch'),
                    Text('   Ví dụ: 1=5000 (Số tiền từ 1 đến 5000)'),
                    SizedBox(height: 4),
                    Text('2. Điều kiện từ khóa: Kiểm tra từ khóa trong nội dung giao dịch'),
                    Text('   Ví dụ: vip1, vip2, vip3 (Có chứa một trong các từ khóa này)'),
                    SizedBox(height: 8),
                    Text(
                      'Lưu ý: Tất cả điều kiện phải được thỏa mãn để API được gọi. Chỉ thêm các điều kiện cần thiết.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // Danh sách điều kiện
              if (_conditionsList.isEmpty)
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    'Chưa có điều kiện nào. API sẽ được gọi cho mọi giao dịch.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _conditionsList.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(_getReadableCondition(_conditionsList[index])),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeCondition(index),
                        ),
                      ),
                    );
                  },
                ),
              
              Divider(height: screenHeight * 0.04),
              
              // Cài đặt thông báo
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                child: Text(
                  'Cài đặt thông báo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              
              Container(
                width: double.infinity,
                child: const Text(
                  'Chọn loại giao dịch bạn muốn nhận thông báo:',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // Thông báo tiền vào
              Row(
                children: [
                  const Text('Thông báo tiền vào:'),
                  SizedBox(width: screenWidth * 0.02),
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
              SizedBox(height: screenHeight * 0.01),
              
              // Thông báo tiền ra
              Row(
                children: [
                  const Text('Thông báo tiền ra:'),
                  SizedBox(width: screenWidth * 0.02),
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
              
              Divider(height: screenHeight * 0.04),
              
              // Cài đặt thử lại
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                child: Text(
                  'Cài đặt thử lại',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              
              Container(
                width: double.infinity,
                child: const Text(
                  'Cấu hình thử lại khi gọi API thất bại:',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // Thử lại khi thất bại
              Row(
                children: [
                  const Text('Thử lại khi thất bại:'),
                  SizedBox(width: screenWidth * 0.02),
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
              SizedBox(height: screenHeight * 0.02),
              
              // Số lần thử lại tối đa
              TextFormField(
                controller: _maxRetriesController,
                decoration: const InputDecoration(
                  labelText: 'Số lần thử lại tối đa',
                  hintText: 'Nhập số lần thử lại (mặc định: 3)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: _retryOnFailure,
                validator: (value) {
                  if (_retryOnFailure) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập số lần thử lại';
                    }
                    try {
                      final int retries = int.parse(value);
                      if (retries < 0) {
                        return 'Số lần thử lại không được âm';
                      }
                    } catch (e) {
                      return 'Vui lòng nhập một số nguyên';
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // Thời gian giữa các lần thử
              TextFormField(
                controller: _retryDelayMsController,
                decoration: const InputDecoration(
                  labelText: 'Thời gian giữa các lần thử (ms)',
                  hintText: 'Nhập thời gian chờ (mặc định: 3000)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: _retryOnFailure,
                validator: (value) {
                  if (_retryOnFailure) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập thời gian chờ';
                    }
                    try {
                      final int delay = int.parse(value);
                      if (delay < 0) {
                        return 'Thời gian chờ không được âm';
                      }
                    } catch (e) {
                      return 'Vui lòng nhập một số nguyên';
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: screenHeight * 0.01),
              
              Container(
                width: double.infinity,
                child: const Text(
                  'Lưu ý: Thời gian được tính bằng mili giây (1000ms = 1 giây)',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12),
                ),
              ),
              
              
              SizedBox(height: screenHeight * 0.04),
              
              // Hướng dẫn định dạng API
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                child: Text(
                  'Thông tin về định dạng API',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              
              // Thông tin về định dạng request
              Container(
                width: double.infinity,
                child: Text(
                  'Định dạng JSON gửi đến API của bạn:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              
              Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: const Text(
                    '{\n  "gateway": "MBBank/Cake",\n  "content": "Nội dung giao dịch",\n  "transferAmount": 100000,\n  "transactionId": "uuid-tự-động-tạo"\n}',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // Thông tin về mã phản hồi
              Container(
                width: double.infinity,
                child: Text(
                  'Thông tin về mã phản hồi:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              
              Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('• Mã 200: Thành công - Hệ thống sẽ không thử lại'),
                    Text('• Mã 403: Cấm truy cập - Hệ thống sẽ không thử lại'),
                    Text('• Mã 404: Không tìm thấy - Hệ thống sẽ không thử lại'),
                    Text('• Các mã lỗi khác: Hệ thống sẽ thử lại theo cấu hình'),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // Cấu trúc phản hồi chuẩn
              Container(
                width: double.infinity,
                child: Text(
                  'Cấu trúc phản hồi chuẩn nên có:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              
              Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '{\n  "success": true/false,\n  "message": "Thông báo kết quả",\n  "data": { /* Dữ liệu bổ sung */ },\n  "transactionId": "uuid-nhận-được"\n}',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ),
              
              // Phần hướng dẫn điều kiện chi tiết
              SizedBox(height: screenHeight * 0.04),
              
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                child: Text(
                  'Hướng dẫn thiết lập điều kiện chi tiết',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Điều kiện số:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('- Định dạng: min=max (Ví dụ: 1=5000)'),
                    Text('- Ý nghĩa: Kiểm tra nếu có số nào trong nội dung giao dịch nằm trong khoảng từ min đến max'),
                    Text('- Ví dụ: Nếu nhập "1=5000", API sẽ được gọi khi nội dung giao dịch có số từ 1 đến 5000'),
                    SizedBox(height: 8),
                    
                    Text(
                      'Điều kiện từ khóa:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('- Định dạng: danh sách từ khóa cách nhau bởi dấu phẩy'),
                    Text('- Ý nghĩa: Kiểm tra nếu nội dung giao dịch có chứa bất kỳ từ khóa nào trong danh sách'),
                    Text('- Ví dụ: Nếu nhập "vip1, vip2, vip3", API sẽ được gọi khi nội dung giao dịch có chứa "vip1" hoặc "vip2" hoặc "vip3"'),
                    SizedBox(height: 8),
                    
                    Text(
                      'Lưu ý quan trọng:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700]),
                    ),
                    SizedBox(height: 4),
                    Text('1. Các điều kiện được xử lý theo thứ tự đã thêm'),
                    Text('2. Tất cả các điều kiện phải được thỏa mãn để API được gọi'),
                    Text('3. Nếu một trong các điều kiện không thỏa mãn, API sẽ không được gọi'),
                    Text('4. Chỉ nên thêm các điều kiện thực sự cần thiết'),
                    Text('5. Nếu không có điều kiện nào, API sẽ được gọi cho mọi giao dịch'),
                  ],
                ),
              ),
              
              // Ví dụ cụ thể
              SizedBox(height: screenHeight * 0.02),
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ví dụ thực tế:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Chỉ gọi API khi số tiền từ 100,000 đến 500,000 VND:'),
                    Text('   Thêm điều kiện số: 100000=500000'),
                    SizedBox(height: 6),
                    Text('2. Chỉ gọi API khi nội dung có chứa từ khóa nạp tiền:'),
                    Text('   Thêm điều kiện từ khóa: nạp tiền, nap tien, naptien'),
                    SizedBox(height: 6),
                    Text('3. Kết hợp cả hai điều kiện trên:'),
                    Text('   Thêm cả hai điều kiện, API chỉ được gọi khi ĐỒNG THỜI thỏa mãn cả hai điều kiện'),
                  ],
                ),
              ),
              
              SizedBox(height: screenHeight * 0.04),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.02,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: screenWidth * 0.44,
              height: screenHeight * 0.06,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                ),
                child: const Text('Hủy'),
              ),
            ),
            Container(
              width: screenWidth * 0.44,
              height: screenHeight * 0.06,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (isEditing ? _updateApi : _addApi),
                child: Text(isEditing ? 'Cập nhật' : 'Thêm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
