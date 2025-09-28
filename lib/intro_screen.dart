
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({Key? key}) : super(key: key);

Future<void> _launchGitHub() async {
  const url = 'https://github.com/ax7-quantum/notifybank';
  try {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Không thể mở liên kết $url';
    }
  } catch (e) {
    debugPrint('Lỗi khi mở liên kết: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình để thiết kế responsive
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giới thiệu ứng dụng'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo và tiêu đề
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_active,
                    size: screenWidth * 0.2,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ứng dụng quản lý thông báo và tin nhắn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: screenHeight * 0.03),
            
            // Banner cảnh báo
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, 
                          color: Colors.amber.shade800, 
                          size: screenWidth * 0.06),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        child: Text(
                          'Lưu ý quan trọng về quyền',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: screenWidth * 0.045,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'Ứng dụng này yêu cầu các quyền nhạy cảm như đọc thông báo và tin nhắn SMS để xử lý thông tin thanh toán tự động. Chúng tôi tôn trọng quyền riêng tư của bạn và không lưu trữ hoặc chia sẻ dữ liệu cá nhân với bên thứ ba.',
                    style: TextStyle(fontSize: screenWidth * 0.04),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: screenHeight * 0.03),
            
            // Các phần giới thiệu
            _buildSection(
              context: context,
              icon: Icons.app_shortcut,
              title: 'Ứng dụng này là gì?',
              content: 'Đây là ứng dụng quản lý và xử lý thông báo, tin nhắn từ các ứng dụng ngân hàng và ví điện tử. Ứng dụng sẽ lắng nghe các thông báo hoặc tin nhắn và thực hiện các xử lý trên thiết bị của bạn. Nó sẽ chạy nền để đảm bảo không có bất cứ thông báo nào bị bỏ sót.',
            ),
            
            _buildSection(
              context: context,
              icon: Icons.work,
              title: 'Ứng dụng hoạt động như thế nào?',
              content: 'Khi nhận được thông báo từ ngân hàng hoặc tin nhắn SMS, ứng dụng sẽ phân tích nội dung và gửi thông tin biến động số dư đến API của bạn. Điều này cho phép bạn tự động hóa nhiều tác vụ như:\n\n• Cập nhật thanh toán trên trang web cho người dùng\n• Xử lý giao dịch mua sắm\n• Xử lý thanh toán trong game\n• Và nhiều ứng dụng khác tùy theo nhu cầu của bạn',
            ),
            
            _buildSection(
              context: context,
              icon: Icons.security,
              title: 'Ứng dụng này có an toàn không?',
              content: 'Ứng dụng này là mã nguồn mở và có sẵn trên GitHub. Bạn có thể tải ứng dụng chính thức từ đó và kiểm tra mã nguồn. Vì các quyền được cấp ở ứng dụng này rất nhạy cảm, nên hãy chắc chắn chỉ tải từ GitHub chính thức và kiểm tra kỹ mã nguồn trước khi sử dụng. Ứng dụng chỉ xử lý dữ liệu cần thiết và không lưu trữ thông tin nhạy cảm trên thiết bị.',
            ),
            
            // Phần quyền cần thiết - được cải thiện và chi tiết hơn
            _buildSection(
              context: context,
              icon: Icons.privacy_tip,
              title: 'Quyền cần thiết',
              content: 'Ứng dụng yêu cầu các quyền sau để hoạt động đúng:',
              isExpandable: true,
              children: [
                _buildPermissionItem(
                  context: context,
                  icon: Icons.notifications_active,
                  title: 'Quyền đọc thông báo',
                  description: 'Cho phép ứng dụng đọc thông báo từ các ứng dụng ngân hàng và ví điện tử để phân tích nội dung thanh toán. Ứng dụng chỉ đọc thông báo từ các ứng dụng tài chính được cấu hình và bỏ qua các thông báo khác.',
                ),
                
                _buildPermissionItem(
                  context: context,
                  icon: Icons.sms,
                  title: 'Quyền đọc và nhận SMS',
                  description: 'Cho phép ứng dụng đọc tin nhắn SMS từ ngân hàng để xử lý thông tin giao dịch. Ứng dụng chỉ đọc tin nhắn từ các số điện thoại ngân hàng đã được cấu hình và không đọc tin nhắn cá nhân.',
                ),
                
                _buildPermissionItem(
                  context: context,
                  icon: Icons.send,
                  title: 'Quyền gửi SMS',
                  description: 'Cho phép ứng dụng gửi tin nhắn SMS thông báo về trạng thái xử lý giao dịch (tùy chọn). Quyền này chỉ được sử dụng khi bạn cấu hình tính năng thông báo qua SMS.',
                ),
                
                _buildPermissionItem(
                  context: context,
                  icon: Icons.sim_card,
                  title: 'Quyền đọc trạng thái điện thoại',
                  description: 'Cho phép ứng dụng đọc thông tin SIM và số điện thoại để xác định thiết bị và cấu hình tự động. Thông tin này chỉ được sử dụng trong ứng dụng và không được chia sẻ.',
                ),
                
                _buildPermissionItem(
                  context: context,
                  icon: Icons.battery_alert,
                  title: 'Tắt tối ưu hóa pin',
                  description: 'Cho phép ứng dụng chạy trong nền mà không bị hệ thống tắt để đảm bảo không bỏ lỡ thông báo quan trọng. Điều này có thể ảnh hưởng nhỏ đến thời lượng pin nhưng cần thiết cho hoạt động liên tục.',
                ),
                
                _buildPermissionItem(
                  context: context,
                  icon: Icons.power_settings_new,
                  title: 'Quyền tự khởi động',
                  description: 'Cho phép ứng dụng tự khởi động khi thiết bị khởi động lại, đảm bảo dịch vụ luôn hoạt động mà không cần can thiệp thủ công. Quyền này cần được cấu hình trong cài đặt hệ thống trên một số thiết bị.',
                ),
                
                _buildPermissionItem(
                  context: context,
                  icon: Icons.notifications_active,
                  title: 'Dịch vụ lắng nghe thông báo',
                  description: 'Cho phép ứng dụng chạy một dịch vụ nền liên tục để lắng nghe và xử lý thông báo. Dịch vụ này được tối ưu để sử dụng ít tài nguyên nhất có thể.',
                ),
              ],
            ),
            
            _buildSection(
              context: context,
              icon: Icons.security_update_warning,
              title: 'Cách bảo vệ quyền riêng tư',
              content: 'Chúng tôi hiểu rằng các quyền được yêu cầu là nhạy cảm. Để bảo vệ quyền riêng tư của bạn:',
              isExpandable: true,
              children: [
                _buildBulletPoint(
                  context: context,
                  text: 'Ứng dụng chỉ đọc thông báo và SMS từ các nguồn đã được cấu hình (ngân hàng, ví điện tử)',
                ),
                _buildBulletPoint(
                  context: context,
                  text: 'Dữ liệu nhạy cảm như số thẻ, mật khẩu sẽ được lọc bỏ trước khi gửi đến API',
                ),
                _buildBulletPoint(
                  context: context,
                  text: 'Không lưu trữ lịch sử tin nhắn hoặc thông báo trên thiết bị',
                ),
                _buildBulletPoint(
                  context: context,
                  text: 'Mã nguồn mở và minh bạch, cho phép kiểm tra cách xử lý dữ liệu',
                ),
                _buildBulletPoint(
                  context: context,
                  text: 'Bạn có thể giới hạn phạm vi xử lý thông báo trong cài đặt',
                ),
                _buildBulletPoint(
                  context: context,
                  text: 'Có thể tắt dịch vụ bất cứ lúc nào trong ứng dụng',
                ),
              ],
            ),
            
            _buildSection(
              context: context,
              icon: Icons.settings,
              title: 'Cài đặt quan trọng',
              content: 'Để ứng dụng hoạt động ổn định, bạn cần thực hiện các cài đặt sau:',
              isExpandable: true,
              children: [
                _buildNumberedPoint(
                  context: context,
                  number: 1,
                  title: 'Tắt tối ưu hóa pin',
                  description: 'Vào Cài đặt > Pin > Tối ưu hóa pin > Tìm ứng dụng này > Chọn "Không tối ưu hóa"',
                ),
                _buildNumberedPoint(
                  context: context,
                  number: 2,
                  title: 'Cho phép tự khởi động',
                  description: 'Trên các thiết bị Xiaomi, Oppo, Vivo, Huawei: Vào Cài đặt > Quản lý ứng dụng > Tìm ứng dụng này > Tự khởi động > Bật',
                ),
                _buildNumberedPoint(
                  context: context,
                  number: 3,
                  title: 'Cấp quyền thông báo',
                  description: 'Vào Cài đặt > Ứng dụng > Quyền truy cập đặc biệt > Truy cập thông báo > Bật cho ứng dụng này',
                ),
                _buildNumberedPoint(
                  context: context,
                  number: 4,
                  title: 'Cấu hình nguồn thông báo',
                  description: 'Trong ứng dụng, vào phần Cài đặt > Nguồn thông báo > Chọn các ứng dụng ngân hàng và ví điện tử bạn muốn theo dõi',
                ),
              ],
            ),
            
            _buildSection(
              context: context,
              icon: Icons.speed,
              title: 'Hiệu suất và tài nguyên',
              content: 'Ứng dụng được tối ưu để sử dụng ít tài nguyên nhất có thể. Trung bình, ứng dụng chỉ tiêu thụ khoảng 30-50MB RAM khi chạy nền và ảnh hưởng không đáng kể đến thời lượng pin. Bạn có thể kiểm tra mức sử dụng tài nguyên trong phần cài đặt thông tin ứng dụng.',
            ),
            
            SizedBox(height: screenHeight * 0.03),
            
            // Nút xem mã nguồn
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.code),
                label: const Text('Xem mã nguồn trên GitHub'),
                onPressed: _launchGitHub,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05, 
                    vertical: screenHeight * 0.015
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: screenHeight * 0.02),
            
            // Nút tiếp tục
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.1, 
                    vertical: screenHeight * 0.015
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
                child: const Text(
                  'Đã hiểu và tiếp tục',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            
            SizedBox(height: screenHeight * 0.04),
            
            // Thông tin phiên bản
            Center(
              child: Text(
                'Phiên bản 1.0.0',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: screenWidth * 0.035,
                ),
              ),
            ),
            
            SizedBox(height: screenHeight * 0.02),
          ],
        ),
      ),
    );
  }

  // Widget xây dựng một phần thông tin
  Widget _buildSection({
    required BuildContext context,
    required String title, 
    required String content, 
    required IconData icon,
    bool isExpandable = false,
    List<Widget>? children,
  }) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: screenHeight * 0.025),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.01,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
          child: Text(
            content,
            style: TextStyle(fontSize: screenWidth * 0.04),
          ),
        ),
        if (children != null && children.isNotEmpty) ...[
          SizedBox(height: screenHeight * 0.01),
          ...children,
        ],
      ],
    );
  }

  // Widget xây dựng một mục quyền
  Widget _buildPermissionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    return Container(
      margin: EdgeInsets.only(
        left: screenWidth * 0.02,
        right: screenWidth * 0.02,
        bottom: screenHeight * 0.015,
      ),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.02),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: screenWidth * 0.05,
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
                SizedBox(height: screenHeight * 0.005),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget xây dựng một điểm đánh dấu
  Widget _buildBulletPoint({
    required BuildContext context,
    required String text,
  }) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    return Padding(
      padding: EdgeInsets.only(
        left: screenWidth * 0.04,
        right: screenWidth * 0.02,
        bottom: screenHeight * 0.01,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: screenWidth * 0.04),
            ),
          ),
        ],
      ),
    );
  }

  // Widget xây dựng một điểm đánh số
  Widget _buildNumberedPoint({
    required BuildContext context,
    required int number,
    required String title,
    required String description,
  }) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    return Padding(
      padding: EdgeInsets.only(
        left: screenWidth * 0.02,
        right: screenWidth * 0.02,
        bottom: screenHeight * 0.015,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: screenWidth * 0.07,
            height: screenWidth * 0.07,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.04,
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
                SizedBox(height: screenHeight * 0.005),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
