import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ApiGuideAndTestScreen extends StatefulWidget {
  const ApiGuideAndTestScreen({Key? key}) : super(key: key);

  @override
  State<ApiGuideAndTestScreen> createState() => _ApiGuideAndTestScreenState();
}

class _ApiGuideAndTestScreenState extends State<ApiGuideAndTestScreen> {
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _contentController = TextEditingController(text: "Chuyen tien");
  final TextEditingController _amountController = TextEditingController(text: "20000");
  final TextEditingController _transactionIdController = TextEditingController(text: "12345678");
  
  String _responseText = '';
  bool _isLoading = false;
  String _selectedBank = 'MBBank';
  
  // Danh sách ngân hàng hỗ trợ
  final List<String> _banks = [
    'MBBank',
    'Vietcombank',
    'Techcombank',
    'BIDV',
    'VPBank',
    'TPBank',
    'ACB',
    'Sacombank',
    'VietinBank',
    'Agribank'
  ];
  
  // Khởi tạo MethodChannel để gọi đến native code
  static const platform = MethodChannel('com.x319.notifybank/bankapi');

  // Hàm tạo ID giao dịch ngẫu nhiên 8 số
  void _generateRandomId() {
    final random = Random();
    String randomId = '';
    for (int i = 0; i < 8; i++) {
      randomId += random.nextInt(10).toString();
    }
    _transactionIdController.text = randomId;
  }

  // Hàm tạo JSON từ dữ liệu nhập
  String _generateJsonData() {
    final data = {
      "gateway": _selectedBank,
      "content": _contentController.text,
      "transferAmount": int.tryParse(_amountController.text) ?? 0,
      "transactionId": _transactionIdController.text
    };
    return json.encode(data);
  }

  // Hiển thị dialog xác nhận và chi tiết request
  Future<void> _showConfirmationDialog() async {
    if (_apiUrlController.text.isEmpty || _apiKeyController.text.isEmpty) {
      _showErrorDialog('Vui lòng nhập đầy đủ URL API và API Key');
      return;
    }

    final jsonData = _generateJsonData();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận gửi request API'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chi tiết request:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              // URL API
              const Text(
                'URL API:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_apiUrlController.text),
              ),
              
              // Header Authorization
              const Text(
                'Header Authorization:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Authorization: Apikey ${_apiKeyController.text}'),
              ),
              
              // JSON Body
              const Text(
                'JSON Body:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(json.decode(jsonData)),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              
              // Giải thích quy trình
              const SizedBox(height: 12),
              const Text(
                'Quy trình gửi request:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Kết nối đến URL API được cung cấp'),
              const Text('2. Gửi API Key trong header để xác thực'),
              const Text('3. Gửi dữ liệu JSON trong body request'),
              const Text('4. Nhận phản hồi từ API và hiển thị kết quả'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận và gửi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _testApi(jsonData);
    }
  }

  // Hàm test API sử dụng MethodChannel
  Future<void> _testApi(String jsonBody) async {
    setState(() {
      _isLoading = true;
      _responseText = '';
    });

    try {
      // Gọi phương thức testApi thông qua channel
      final result = await platform.invokeMethod('testApi', {
        'apiUrl': _apiUrlController.text,
        'apiKey': _apiKeyController.text,
        'jsonBody': jsonBody,
      });
      
      // Phân tích kết quả
      final response = json.decode(result);
      
      setState(() {
        _isLoading = false;
        _responseText = 'Mã phản hồi: ${response['statusCode']}\n\n';
        
        if (response['body'].isNotEmpty) {
          try {
            // Thử phân tích JSON và hiển thị định dạng đẹp
            final jsonResponse = json.decode(response['body']);
            _responseText += const JsonEncoder.withIndent('  ').convert(jsonResponse);
          } catch (e) {
            // Nếu không phải JSON, hiển thị nguyên văn
            _responseText += response['body'];
          }
        } else {
          _responseText += 'Không có dữ liệu phản hồi';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _responseText = 'Lỗi: ${e.toString()}';
      });
    }
  }

  // Hiển thị dialog lỗi
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lỗi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // Sao chép văn bản vào clipboard
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép vào clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hướng dẫn và Test API'),
        elevation: 2,
      ),
      body: Column(
        children: [
          // Phần tiêu đề (10% màn hình)
          Container(
            height: screenHeight * 0.1,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: const Center(
              child: Text(
                'Hướng dẫn cấu hình và test API',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Phần nội dung (90% màn hình)
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Tab bar
                  TabBar(
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'HƯỚNG DẪN'),
                      Tab(text: 'TEST API'),
                    ],
                  ),
                  
                  // Tab content
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Hướng dẫn (40% màn hình)
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Phần 1: Giới thiệu
                              const Text(
                                'Giới thiệu',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Ứng dụng sẽ gửi thông tin giao dịch từ thông báo ngân hàng đến API của bạn. Bạn cần cấu hình API để nhận thông tin này.',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              
                              // Phần 2: Định dạng JSON
                              const Text(
                                'Định dạng JSON gửi đến API',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '{\n  "gateway": "MBBank/Vietcombank/...",\n  "content": "Nội dung giao dịch",\n  "transferAmount": 100000,\n  "transactionId": "ID giao dịch"\n}',
                                      style: TextStyle(fontFamily: 'monospace'),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.copy, size: 16),
                                          label: const Text('Sao chép'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            textStyle: const TextStyle(fontSize: 12),
                                          ),
                                          onPressed: () => _copyToClipboard('{\n  "gateway": "MBBank/Vietcombank/...",\n  "content": "Nội dung giao dịch",\n  "transferAmount": 100000,\n  "transactionId": "ID giao dịch"\n}'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Trong đó:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text('• gateway: Nguồn giao dịch (MBBank, Vietcombank, ...)'),
                              const Text('• content: Nội dung giao dịch đã được xử lý'),
                              const Text('• transferAmount: Số tiền giao dịch (đã chuyển thành số)'),
                              const Text('• transactionId: ID giao dịch để theo dõi'),
                              const SizedBox(height: 16),
                              
                              // Phần 3: Xác thực API
                              const Text(
                                'Xác thực API',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'API Key được gửi trong header của mỗi request:',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Authorization: Apikey YOUR_API_KEY',
                                  style: TextStyle(fontFamily: 'monospace'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Phần 4: Mã phản hồi
                              const Text(
                                'Mã phản hồi HTTP',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• Mã 200: Thành công - Không thử lại'),
                                    Text('• Mã 403: Cấm truy cập - Không thử lại'),
                                    Text('• Mã 404: Không tìm thấy - Không thử lại'),
                                    Text('• Các mã khác: Thử lại theo cấu hình'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Phần 5: Định dạng phản hồi
                              const Text(
                                'Định dạng phản hồi khuyến nghị',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '{\n  "success": true,\n  "message": "Giao dịch đã được xử lý",\n  "data": {\n    // Dữ liệu bổ sung\n  },\n  "transactionId": "ID giao dịch"\n}',
                                      style: TextStyle(fontFamily: 'monospace'),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.copy, size: 16),
                                          label: const Text('Sao chép'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            textStyle: const TextStyle(fontSize: 12),
                                          ),
                                          onPressed: () => _copyToClipboard('{\n  "success": true,\n  "message": "Giao dịch đã được xử lý",\n  "data": {\n    // Dữ liệu bổ sung\n  },\n  "transactionId": "ID giao dịch"\n}'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Phần 6: Cài đặt thử lại
                              const Text(
                                'Cài đặt thử lại',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Bạn có thể cấu hình các tùy chọn thử lại trong phần cài đặt API:',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• Bật/tắt thử lại khi thất bại'),
                                    Text('• Số lần thử lại tối đa'),
                                    Text('• Thời gian giữa các lần thử (ms)'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                        
                        // Tab 2: Test API
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Test API của bạn',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Bạn có thể test API của mình bên dưới hoặc thêm API và cấu hình trong phần quản lý API. Sau đó thử chuyển tiền vào tài khoản để xem kết quả hoặc test nhanh với mẫu chuyển tiền tùy chỉnh bên dưới.',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              
                              // URL API
                              TextField(
                                controller: _apiUrlController,
                                decoration: const InputDecoration(
                                  labelText: 'URL API',
                                  hintText: 'Nhập URL API của bạn',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.link),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // API Key
                              TextField(
                                controller: _apiKeyController,
                                decoration: const InputDecoration(
                                  labelText: 'API Key',
                                  hintText: 'Nhập API Key của bạn',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.vpn_key),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Mẫu JSON tùy chỉnh
                              const Text(
                                'Tùy chỉnh dữ liệu gửi đi:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              
                              // Container cho dữ liệu tùy chỉnh
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Chọn ngân hàng
                                    DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'Ngân hàng',
                                        border: OutlineInputBorder(),
                                      ),
                                      value: _selectedBank,
                                      items: _banks.map((bank) {
                                        return DropdownMenuItem<String>(
                                          value: bank,
                                          child: Text(bank),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedBank = value!;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Nội dung chuyển khoản
                                    TextField(
                                      controller: _contentController,
                                      decoration: const InputDecoration(
                                        labelText: 'Nội dung chuyển khoản',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Số tiền
                                    TextField(
                                      controller: _amountController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Số tiền',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // ID giao dịch
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _transactionIdController,
                                            decoration: const InputDecoration(
                                              labelText: 'ID giao dịch',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: _generateRandomId,
                                          child: const Text('Tạo ID'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Nút kiểm tra API
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: _isLoading 
                                      ? Container(
                                          width: 24,
                                          height: 24,
                                          padding: const EdgeInsets.all(2.0),
                                          child: const CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : const Icon(Icons.send),
                                  label: Text(_isLoading ? 'Đang kiểm tra...' : 'Kiểm tra API của tôi'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: _isLoading ? null : _showConfirmationDialog,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Kết quả phản hồi
                              if (_responseText.isNotEmpty) ...[
                                const Text(
                                  'Phản hồi từ API:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _responseText,
                                        style: const TextStyle(fontFamily: 'monospace'),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.copy, size: 16),
                                            label: const Text('Sao chép'),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              textStyle: const TextStyle(fontSize: 12),
                                            ),
                                            onPressed: () => _copyToClipboard(_responseText),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _contentController.dispose();
    _amountController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }
}
