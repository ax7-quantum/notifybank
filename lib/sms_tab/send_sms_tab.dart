
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'contact_manager.dart';

class SendSmsTab extends StatefulWidget {
  const SendSmsTab({Key? key}) : super(key: key);

  @override
  State<SendSmsTab> createState() => _SendSmsTabState();
}

class _SendSmsTabState extends State<SendSmsTab> {
  final MethodChannel _smsChannel = const MethodChannel('com.x319.notifybank/sms');
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _bulkPhoneNumberController = TextEditingController();
  final ContactManager _contactManager = ContactManager();
  bool _isSending = false;
  
  // Biến cho chế độ hiển thị
  int _currentMode = 0; // 0: Cá nhân, 1: Hàng loạt, 2: Cài đặt SIM
  
  // Biến cho cài đặt SIM
  bool _useSpecificSim = false;
  int _selectedSimId = -1;
  String _selectedSimName = "Chưa chọn";
  List<Map<String, dynamic>> _availableSims = [];
  List<String> _bulkPhoneNumbers = [];

  @override
  void initState() {
    super.initState();
    _loadSimSettings();
    _contactManager.checkContactsPermission();
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _messageController.dispose();
    _bulkPhoneNumberController.dispose();
    super.dispose();
  }

  // Tải cài đặt SIM
  Future<void> _loadSimSettings() async {
    try {
      // Lấy danh sách SIM có sẵn
      final String simsJson = await _smsChannel.invokeMethod('getAvailableSims');
      final List<dynamic> simsData = jsonDecode(simsJson);
      
      setState(() {
        _availableSims = simsData.map((sim) => Map<String, dynamic>.from(sim)).toList();
      });
      
      // Lấy cài đặt SIM hiện tại
      final bool useSpecificSim = await _smsChannel.invokeMethod('getUseSpecificSim');
      final int selectedSimId = await _smsChannel.invokeMethod('getSelectedSim');
      
      setState(() {
        _useSpecificSim = useSpecificSim;
        _selectedSimId = selectedSimId;
        
        // Tìm tên của SIM đã chọn
        if (_selectedSimId != -1) {
          final selectedSim = _availableSims.firstWhere(
            (sim) => sim['subscriptionId'] == _selectedSimId,
            orElse: () => {'displayName': 'Chưa chọn'},
          );
          _selectedSimName = selectedSim['displayName'].toString();
        }
      });
    } catch (e) {
      print("Lỗi khi tải cài đặt SIM: $e");
    }
  }

  // Gửi tin nhắn SMS đơn
  Future<void> _sendSms() async {
    // Kiểm tra nếu các trường nhập liệu trống
    if (_phoneNumberController.text.trim().isEmpty) {
      _showSnackBar('Vui lòng nhập số điện thoại');
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      _showSnackBar('Vui lòng nhập nội dung tin nhắn');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      bool success;
      
      // Sử dụng phương thức gửi tin nhắn thông minh
      success = await _smsChannel.invokeMethod('sendSmartSms', {
        "phoneNumber": _phoneNumberController.text.trim(),
        "message": _messageController.text.trim()
      });

      if (success) {
        _showSnackBar('Gửi tin nhắn thành công');
        _messageController.clear(); // Xóa nội dung tin nhắn sau khi gửi
      } else {
        _showSnackBar('Không thể gửi tin nhắn');
      }
    } on PlatformException catch (e) {
      print("Lỗi khi gửi SMS: ${e.message}");
      _showSnackBar('Lỗi: ${e.message}');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  // Gửi tin nhắn hàng loạt
  Future<void> _sendBulkSms() async {
    if (_bulkPhoneNumbers.isEmpty) {
      _showSnackBar('Vui lòng thêm ít nhất một số điện thoại');
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      _showSnackBar('Vui lòng nhập nội dung tin nhắn');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Sử dụng phương thức gửi tin nhắn hàng loạt thông minh
      final String resultsJson = await _smsChannel.invokeMethod('sendSmartBulkSms', {
        "phoneNumbers": _bulkPhoneNumbers,
        "message": _messageController.text.trim()
      });
      
      final Map<String, dynamic> results = jsonDecode(resultsJson);
      
      // Đếm số tin nhắn gửi thành công
      int successCount = 0;
      results.forEach((phone, success) {
        if (success == true) successCount++;
      });
      
      _showSnackBar('Đã gửi thành công $successCount/${_bulkPhoneNumbers.length} tin nhắn');
      _messageController.clear(); // Xóa nội dung tin nhắn sau khi gửi
      
    } on PlatformException catch (e) {
      print("Lỗi khi gửi SMS hàng loạt: ${e.message}");
      _showSnackBar('Lỗi: ${e.message}');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  // Thêm số điện thoại vào danh sách gửi hàng loạt
  void _addPhoneNumbers() {
    final input = _bulkPhoneNumberController.text.trim();
    if (input.isEmpty) return;
    
    final numbers = input.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    setState(() {
      _bulkPhoneNumbers.addAll(numbers);
      _bulkPhoneNumberController.clear();
    });
    
    _showSnackBar('Đã thêm ${numbers.length} số điện thoại');
  }

  // Thêm một số điện thoại vào danh sách gửi hàng loạt
  void _addSinglePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return;
    
    setState(() {
      if (!_bulkPhoneNumbers.contains(phoneNumber)) {
        _bulkPhoneNumbers.add(phoneNumber);
        _showSnackBar('Đã thêm số điện thoại: $phoneNumber');
      } else {
        _showSnackBar('Số điện thoại đã có trong danh sách');
      }
    });
  }

  // Xóa số điện thoại khỏi danh sách
  void _removePhoneNumber(int index) {
    setState(() {
      _bulkPhoneNumbers.removeAt(index);
    });
  }

  // Xóa tất cả số điện thoại
  void _clearPhoneNumbers() {
    setState(() {
      _bulkPhoneNumbers.clear();
    });
    _showSnackBar('Đã xóa tất cả số điện thoại');
  }

  // Hiển thị hộp thoại chọn SIM
  Future<void> _showSimSelectionDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn SIM'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Sử dụng SIM cụ thể'),
              value: _useSpecificSim,
              onChanged: (value) async {
                await _smsChannel.invokeMethod('setUseSpecificSim', {"enabled": value});
                Navigator.pop(context);
                _loadSimSettings();
              },
            ),
            const Divider(),
            ..._availableSims.map((sim) => ListTile(
              title: Text(sim['displayName'].toString()),
              subtitle: Text('${sim['carrierName']} (Slot ${sim['slotIndex'] + 1})'),
              selected: _selectedSimId == sim['subscriptionId'],
              onTap: () async {
                await _smsChannel.invokeMethod('setSelectedSim', {"subscriptionId": sim['subscriptionId']});
                await _smsChannel.invokeMethod('setUseSpecificSim', {"enabled": true});
                Navigator.pop(context);
                _loadSimSettings();
              },
            )),
          ],
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

  // Xử lý khi chọn liên hệ từ danh bạ (cho chế độ cá nhân)
  void _onContactSelected(Map<String, dynamic> contact) {
    final String phoneNumber = _contactManager.getPhoneNumberFromContact(contact);
    setState(() {
      _phoneNumberController.text = phoneNumber;
    });
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

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;
    
    return Column(
      children: [
        // Hàng nút chọn chế độ - 10% đầu tiên
        Container(
          height: screenHeight * 0.1,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildModeButton(0, 'Cá nhân', Icons.message),
              _buildModeButton(1, 'Hàng loạt', Icons.group),
              _buildModeButton(2, 'Cài đặt SIM', Icons.sim_card),
            ],
          ),
        ),
        
        // Nội dung chính
        Expanded(
          child: _buildContent(screenHeight, screenWidth),
        ),
      ],
    );
  }

  // Xây dựng nút chọn chế độ
  Widget _buildModeButton(int mode, String label, IconData icon) {
    bool isSelected = _currentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentMode = mode;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Xây dựng nội dung dựa trên chế độ hiện tại
  Widget _buildContent(double screenHeight, double screenWidth) {
    switch (_currentMode) {
      case 0:
        return _buildSingleSmsContent(screenHeight, screenWidth);
      case 1:
        return _buildBulkSmsContent(screenHeight, screenWidth);
      case 2:
        return _buildSimSettingsContent(screenHeight, screenWidth);
      default:
        return Container();
    }
  }

  // Nội dung gửi tin nhắn cá nhân
  Widget _buildSingleSmsContent(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trường nhập số điện thoại - 10%
          Container(
            height: screenHeight * 0.1,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneNumberController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Container(
                  height: screenHeight * 0.08,
                  width: screenWidth * 0.12,
                  child: ElevatedButton(
                    onPressed: () => _contactManager.openContactPicker(
                      context,
                      0, // Chế độ cá nhân
                      onContactSelected: _onContactSelected,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),

child: const Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(Icons.contacts, color: Colors.white),
    Text('Danh bạ', style: TextStyle(fontSize: 10, color: Colors.white)),
  ],
),

                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Hiển thị danh sách liên hệ yêu thích
          _contactManager.buildFavoritesListWidget(
            onContactSelected: _onContactSelected,
            height: screenHeight * 0.15,
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Hiển thị danh sách liên hệ gần đây
          _contactManager.buildRecentContactsWidget(
            onContactSelected: _onContactSelected,
            height: screenHeight * 0.15,
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Trường nhập nội dung tin nhắn - 10%
          Container(
            height: screenHeight * 0.1,
            child: TextField(
              controller: _messageController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                labelText: 'Nội dung tin nhắn',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
                alignLabelWithHint: true,
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Hiển thị thông tin SIM đang sử dụng
          Container(
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.sim_card, color: Colors.blue),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: Text(
                    _useSpecificSim 
                      ? 'Đang sử dụng SIM: $_selectedSimName' 
                      : 'Đang sử dụng SIM mặc định của hệ thống',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: _showSimSelectionDialog,
                )
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Nút gửi tin nhắn
          SizedBox(
            width: double.infinity,
            height: screenHeight * 0.06,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendSms,
              icon: _isSending 
                ? SizedBox(
                    width: screenWidth * 0.05, 
                    height: screenWidth * 0.05, 
                    child: const CircularProgressIndicator(strokeWidth: 2)
                  ) 
                : const Icon(Icons.send),
              label: Text(_isSending ? 'Đang gửi...' : 'Gửi tin nhắn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Nội dung gửi tin nhắn hàng loạt
  Widget _buildBulkSmsContent(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trường nhập số điện thoại hàng loạt
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bulkPhoneNumberController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nhập số điện thoại (cách nhau bằng dấu ,)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Container(
                height: screenHeight * 0.08,
                width: screenWidth * 0.12,
                child: ElevatedButton(
                  onPressed: () => _contactManager.openContactPicker(
                    context,
                    1, // Chế độ hàng loạt
                    onContactSelected: (_) {}, // Không dùng trong chế độ hàng loạt
                    onPhoneNumberAdded: _addSinglePhoneNumber,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),

child: const Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(Icons.contacts, color: Colors.white),
    Text('Danh bạ', style: TextStyle(fontSize: 10, color: Colors.white)),
  ],
),
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Container(
                height: screenHeight * 0.08,
                width: screenWidth * 0.12,
                child: ElevatedButton(
                  onPressed: _addPhoneNumbers,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Hiển thị danh sách số điện thoại đã thêm
          _contactManager.buildSelectedPhoneNumbersWidget(
            phoneNumbers: _bulkPhoneNumbers,
            onRemove: _removePhoneNumber,
            onClearAll: _clearPhoneNumbers,
            height: screenHeight * 0.2,
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Trường nhập nội dung tin nhắn
          Container(
            height: screenHeight * 0.1,
            child: TextField(
              controller: _messageController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                labelText: 'Nội dung tin nhắn',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
                alignLabelWithHint: true,
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Hiển thị thông tin SIM đang sử dụng
          Container(
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.sim_card, color: Colors.blue),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: Text(
                    _useSpecificSim 
                      ? 'Đang sử dụng SIM: $_selectedSimName' 
                      : 'Đang sử dụng SIM mặc định của hệ thống',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: _showSimSelectionDialog,
                )
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Nút gửi tin nhắn hàng loạt
          SizedBox(
            width: double.infinity,
            height: screenHeight * 0.06,
            child: ElevatedButton.icon(
              onPressed: _isSending || _bulkPhoneNumbers.isEmpty ? null : _sendBulkSms,
              icon: _isSending 
                ? SizedBox(
                    width: screenWidth * 0.05, 
                    height: screenWidth * 0.05, 
                    child: const CircularProgressIndicator(strokeWidth: 2)
                  ) 
                : const Icon(Icons.send),
              label: Text(_isSending ? 'Đang gửi...' : 'Gửi tin nhắn hàng loạt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Nội dung cài đặt SIM
  Widget _buildSimSettingsContent(double screenHeight, double screenWidth) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cài đặt SIM',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Tùy chọn sử dụng SIM cụ thể
          Container(
            height: screenHeight * 0.08,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: SwitchListTile(
              title: const Text('Sử dụng SIM cụ thể'),
              subtitle: const Text('Khi tắt, ứng dụng sẽ sử dụng SIM mặc định của hệ thống'),
              value: _useSpecificSim,
              onChanged: (value) async {
                await _smsChannel.invokeMethod('setUseSpecificSim', {"enabled": value});
                _loadSimSettings();
              },
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Danh sách SIM có sẵn
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn SIM để gửi tin nhắn',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                
                if (_availableSims.isEmpty)
                  Container(
                    height: screenHeight * 0.1,
                    alignment: Alignment.center,
                    child: const Text(
                      'Không tìm thấy SIM nào',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...(_availableSims.map((sim) => Container(
                    height: screenHeight * 0.08, // Chiều cao mỗi mục là 8% màn hình
                    margin: EdgeInsets.only(bottom: screenHeight * 0.01),
                    decoration: BoxDecoration(
                      color: _selectedSimId == sim['subscriptionId'] ? Colors.blue.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedSimId == sim['subscriptionId'] ? Colors.blue : Colors.grey.shade300,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 1,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () async {
                        await _smsChannel.invokeMethod('setSelectedSim', {"subscriptionId": sim['subscriptionId']});
                        await _smsChannel.invokeMethod('setUseSpecificSim', {"enabled": true});
                        _loadSimSettings();
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sim_card,
                              color: _selectedSimId == sim['subscriptionId'] ? Colors.blue : Colors.grey,
                              size: screenWidth * 0.08,
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    sim['displayName'].toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _selectedSimId == sim['subscriptionId'] ? Colors.blue : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    '${sim['carrierName']} (Slot ${sim['slotIndex'] + 1})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedSimId == sim['subscriptionId'] ? Colors.blue.shade700 : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedSimId == sim['subscriptionId'])
                              Icon(
                                Icons.check_circle,
                                color: Colors.blue,
                                size: screenWidth * 0.06,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ))),
              ],
            ),
          ),
          
          SizedBox(height: screenHeight * 0.02),
          
          // Thông tin bổ sung
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Lưu ý:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '- Một số thiết bị có thể không hỗ trợ chọn SIM để gửi tin nhắn',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  '- Nếu không chọn SIM cụ thể, ứng dụng sẽ sử dụng SIM mặc định của hệ thống',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
