import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/BankApiManagerScreen.dart';

class MomoTransactionView extends StatefulWidget {
  const MomoTransactionView({Key? key}) : super(key: key);

  @override
  State<MomoTransactionView> createState() => _MomoTransactionViewState();
}

class _MomoTransactionViewState extends State<MomoTransactionView> {
  final MethodChannel _channel = const MethodChannel('com.x319.notifybank/notification');
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMomoTransactions();
  }

  // Tải danh sách giao dịch MoMo từ SharedPreferences
  Future<void> _loadMomoTransactions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final String transactionsJson = await _channel.invokeMethod('getMomoTransactions');
      
      // Xử lý chuỗi JSON nhận được
      List<dynamic> decodedList = [];
      try {
        decodedList = json.decode(transactionsJson) as List<dynamic>;
      } catch (e) {
        print("Lỗi khi parse JSON giao dịch MoMo: $e");
        print("JSON nhận được: $transactionsJson");
        decodedList = [];
      }
      
      setState(() {
        _transactions = decodedList;
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      print("Lỗi khi tải giao dịch MoMo: ${e.message}");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Xóa tất cả giao dịch MoMo
  Future<void> _clearMomoTransactions() async {
    try {
      await _channel.invokeMethod('clearMomoTransactions');
      _loadMomoTransactions();
    } on PlatformException catch (e) {
      print("Lỗi khi xóa giao dịch MoMo: ${e.message}");
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
    
    // Log để debug
    print("Số lượng giao dịch MoMo: ${_transactions.length}");
    if (_transactions.isNotEmpty) {
      print("Mẫu giao dịch đầu tiên: ${json.encode(_transactions[0])}");
    }
    
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Tiêu đề và nút xóa (5% chiều cao màn hình)
            Container(
              height: screenHeight * 0.05,
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Danh sách giao dịch MoMo (${_transactions.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_transactions.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clearMomoTransactions,
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Xóa tất cả'),
                    ),
                ],
              ),
            ),
            
            // API Management Banner (15% chiều cao màn hình)
            Container(
              height: screenHeight * 0.15,
              margin: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04, 
                vertical: screenHeight * 0.01
              ),
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.api, color: Colors.purple.shade700),
                        SizedBox(width: screenWidth * 0.02),
                        const Text(
                          'Nhận thông báo giao dịch MoMo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    const Text(
                      'Thêm API của bạn để tự động nhận thông báo khi có giao dịch MoMo mới. Hệ thống sẽ gửi thông tin chi tiết về giao dịch đến API của bạn.',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BankApiManagerScreen(
                              bankType: 'MOMO',
                              bankName: 'MoMo',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Quản lý API'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Transaction List (70% chiều cao màn hình)
            Container(
              height: screenHeight * 0.7,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                      ? const Center(
                          child: Text(
                            'Không có giao dịch MoMo nào',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadMomoTransactions,
                          child: ListView.builder(
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _transactions[index];
                              
                              // Xử lý thông tin giao dịch
                              final bool isIncrease = transaction['type'] == 'receive';
                              final String transactionType = isIncrease ? 'Tiền vào' : 'Tiền ra';
                              
                              // Định dạng số tiền
                              String rawAmount = transaction['amount']?.toString() ?? '0';
                              String formattedAmount = _formatCurrency(rawAmount);
                              
                              // Sử dụng trường description thay vì content
                              String content = transaction['description']?.toString() ?? 'Không có nội dung';
                              
                              // Định dạng thời gian
                              String formattedTime = transaction['formattedTime']?.toString() ?? 
                                                   'Không xác định';
                              
                              // Thêm mã giao dịch
                              String transactionId = transaction['transactionId']?.toString() ?? '';
                              
                              // Thêm mã giao dịch gốc (nếu có)
                              String? originalTransactionId = transaction['originalTransactionId']?.toString();
                              
                              // Thêm trạng thái xử lý API
                              bool processed = transaction['processed'] == true;
                              
                              // Thêm mã phản hồi API
                              int? responseCode = transaction['responseCode'] as int?;
                              
                              // Mỗi giao dịch chiếm 32% chiều cao màn hình
                              return Container(
                                height: screenHeight * 0.32,
                                margin: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenHeight * 0.01,
                                ),
                                child: Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // PHẦN 1: TIÊU ĐỀ (5% chiều cao màn hình)
                                      Container(
                                        height: screenHeight * 0.05,
                                        padding: EdgeInsets.all(screenWidth * 0.03),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: screenHeight * 0.015,
                                              backgroundColor: isIncrease ? Colors.green[700] : Colors.red[700],
                                              foregroundColor: Colors.white,
                                              child: Icon(
                                                isIncrease ? Icons.arrow_downward : Icons.arrow_upward,
                                                size: screenHeight * 0.018,
                                              ),
                                            ),
                                            SizedBox(width: screenWidth * 0.02),
                                            Expanded(
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: 8, 
                                                        vertical: 2
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isIncrease ? Colors.green[50] : Colors.red[50],
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                          color: isIncrease ? Colors.green[300]! : Colors.red[300]!,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        transactionType,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isIncrease ? Colors.green[700] : Colors.red[700],
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: screenWidth * 0.02),
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
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      Divider(height: 1, thickness: 1),
                                      
                                      // PHẦN 2: SỐ TIỀN (5% chiều cao màn hình)
                                      Container(
                                        height: screenHeight * 0.05,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenWidth * 0.03,
                                          vertical: screenHeight * 0.005,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  SingleChildScrollView(
                                                    scrollDirection: Axis.horizontal,
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          'Số tiền:',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        SizedBox(width: screenWidth * 0.02),
                                                        Text(
                                                          formattedAmount,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                            color: isIncrease ? Colors.green : Colors.red,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SingleChildScrollView(
                                                    scrollDirection: Axis.horizontal,
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          'Nguồn:',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey[700],
                                                          ),
                                                        ),
                                                        SizedBox(width: screenWidth * 0.02),
                                                        Container(
                                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.purple[50],
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(color: Colors.purple[200]!),
                                                          ),
                                                          child: Text(
                                                            'MoMo',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w500,
                                                              color: Colors.purple[700],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (transactionId.isNotEmpty)
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple[50],
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.purple[200]!),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Mã GD:',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.purple[700],
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      transactionId.length > 8 
                                                          ? '${transactionId.substring(0, 8)}...'
                                                          : transactionId,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.purple[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      
                                      Divider(height: 1, thickness: 1),
                                      
                                      // PHẦN 3: NỘI DUNG (10% chiều cao màn hình)
                                      Container(
                                        height: screenHeight * 0.10,
                                        padding: EdgeInsets.all(screenWidth * 0.03),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Nội dung giao dịch:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(height: screenHeight * 0.005),
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey[300]!),
                                                ),
                                                padding: EdgeInsets.all(8),
                                                child: SingleChildScrollView(
                                                  child: Text(
                                                    content,
                                                    style: TextStyle(fontSize: 13),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      Divider(height: 1, thickness: 1),
                                      
                                      // PHẦN 4: TRẠNG THÁI (5% chiều cao màn hình)
                                      Container(
                                        height: screenHeight * 0.05,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenWidth * 0.03,
                                          vertical: screenHeight * 0.005,
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: processed ? Colors.green[50] : Colors.orange[50],
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: processed ? Colors.green[300]! : Colors.orange[300]!,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      processed ? Icons.check_circle : Icons.pending,
                                                      color: processed ? Colors.green : Colors.orange,
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: screenWidth * 0.01),
                                                    Text(
                                                      processed ? 'Đã gọi API' : 'Chưa gọi API',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: processed ? Colors.green[700] : Colors.orange[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: screenWidth * 0.02),
                                              if (responseCode != null)
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: (responseCode >= 200 && responseCode < 300) 
                                                        ? Colors.green[50] 
                                                        : Colors.red[50],
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: (responseCode >= 200 && responseCode < 300)
                                                          ? Colors.green[300]!
                                                          : Colors.red[300]!,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        (responseCode >= 200 && responseCode < 300)
                                                            ? Icons.done_all
                                                            : Icons.error_outline,
                                                        color: (responseCode >= 200 && responseCode < 300)
                                                            ? Colors.green
                                                            : Colors.red,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: screenWidth * 0.01),
                                                      Text(
                                                        'Mã phản hồi: $responseCode',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                          color: (responseCode >= 200 && responseCode < 300)
                                                              ? Colors.green[700]
                                                              : Colors.red[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (originalTransactionId != null && originalTransactionId.isNotEmpty)
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  margin: EdgeInsets.only(left: screenWidth * 0.02),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[50],
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.blue[200]!),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.link,
                                                        color: Colors.blue[700],
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: screenWidth * 0.01),
                                                      Text(
                                                        'ShopeePay',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                          color: Colors.blue[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      
                                      Divider(height: 1, thickness: 1),
                                      
                                      // PHẦN 5: NÚT SAO CHÉP (5% chiều cao màn hình)
                                      Container(
                                        height: screenHeight * 0.05,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenWidth * 0.03,
                                          vertical: screenHeight * 0.005,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () => _copyNotificationToClipboard(transaction),
                                              icon: const Icon(Icons.copy, size: 16),
                                              label: const Text('Sao chép dữ liệu gốc'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.purple,
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                textStyle: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.more_vert),
                                              onPressed: () {
                                                // Hiển thị menu tùy chọn khác nếu cần
                                              },
                                            ),
                                          ],
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
      ),
    );
  }
  
  // Hàm định dạng số tiền với dấu phân cách hàng nghìn
  String _formatCurrency(String amount) {
    try {
      // Xử lý chuỗi số tiền
      String cleanAmount = amount.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanAmount.isEmpty) return amount;
      
      double value = double.parse(cleanAmount);
      
      // Định dạng với dấu phân cách hàng nghìn
      final formatter = RegExp(r'\B(?=(\d{3})+(?!\d))');
      String formattedValue = value.toStringAsFixed(0).replaceAllMapped(formatter, (Match m) => '.');
      
      // Thêm đơn vị tiền tệ nếu không có
      if (!amount.contains('đ')) {
        formattedValue += ' đ';
      }
      
      return formattedValue;
    } catch (e) {
      print("Lỗi định dạng số tiền: $e");
      return amount; // Trả về giá trị gốc nếu có lỗi
    }
  }
}