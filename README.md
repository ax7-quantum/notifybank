# Ứng dụng Quản lý Thông báo và Tin nhắn Ngân hàng

<p align="center">
  <img src="https://via.placeholder.com/200x200?text=Bank+Notifications" alt="Bank Notifications Logo" width="200"/>
  <br>
  <em>Tự động hóa việc theo dõi giao dịch tài chính từ thông báo</em>
</p>

[![Phiên bản](https://img.shields.io/badge/phiên_bản-1.0.0-blue)](https://github.com/ax7-quantum/notifybank/releases)
[![Giấy phép](https://img.shields.io/badge/giấy_phép-GPL--3.0-green)](https://www.gnu.org/licenses/gpl-3.0.html)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blueviolet)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-2.18+-blue)](https://dart.dev/)

## Giải pháp tự động hóa xử lý giao dịch tài chính

Ứng dụng phân tích và đọc thông báo giao dịch từ các ứng dụng ngân hàng và tin nhắn SMS, tự động gửi thông báo đến API của bạn khi có giao dịch mới. Hoạt động hoàn toàn trong nền, ngay cả khi ứng dụng bị đóng hoặc thiết bị khởi động lại.

## Cài đặt ứng dụng

**Quan trọng:** Trước khi cài đặt ứng dụng này, vui lòng tắt tạm thời Google Play Protect bằng cách:
1. Mở Google Play Store
2. Nhấn vào ảnh hồ sơ của bạn ở góc phải trên cùng
3. Chọn "Play Protect"
4. Nhấn vào biểu tượng bánh răng (Cài đặt) ở góc phải trên cùng
5. Tắt tùy chọn "Quét ứng dụng bằng Play Protect"

Bạn có thể tải bản chính thức của ứng dụng [tại đây](https://github.com/ax7-quantum/notifybank/releases).

## Xác thực ứng dụng

Mã hash SHA của các bản phát hành chính thức được liệt kê trong phần releases. Kiểm tra file `keystore_info.txt` trong thư mục ứng dụng để xác minh tính xác thực.

## Tính năng chính

- **Xử lý đa luồng**: Mặc định chạy 8 luồng xử lý thông báo cùng lúc, có thể tăng giảm tùy theo nhu cầu
- **Hoạt động liên tục**: Vẫn hoạt động khi ứng dụng bị đóng hoặc thiết bị khởi động lại
- **Tự động hóa**: Gửi thông tin giao dịch đến API của bạn để xử lý tự động như:
  - Nạp tiền tự động cho người dùng trên trang web
  - Nâng cấp gói hội viên
  - Và nhiều tác vụ tự động khác theo nhu cầu

## Hiệu năng và tài nguyên

- **Tiêu thụ tài nguyên**: Cao hơn ứng dụng Facebook và các ứng dụng khác khoảng 30% nếu bật lưu tất cả thông báo trong phần cài đặt
- **Yêu cầu kết nối**: Cần kết nối internet để gửi thông báo lên server

## Hỗ trợ ngân hàng

Hiện tại ứng dụng đang trong giai đoạn phát triển, các ngân hàng sẽ không ngừng được bổ sung. Để thêm ngân hàng mới:

1. Cài đặt ứng dụng và cấp các quyền cần thiết cho thông báo
2. Xem cấu trúc thông báo của ngân hàng cần thêm
3. Thu thập và gửi vào nhánh phát triển để các nhà phát triển bổ sung

## Tính năng đang phát triển

Chúng tôi đang cân nhắc thêm các tính năng:
- Yêu cầu gửi SMS khi có lệnh gọi đến thiết bị
- Tạo mã xác thực cho hệ thống server của bạn

*Lưu ý: Do vấn đề triển khai mã nguồn mở, chúng tôi đã tạm dừng phát triển một số chức năng. Các nhà phát triển cá nhân có thể tự triển khai, vì chúng tôi đã triển khai phần lớn việc gửi SMS có trong ứng dụng.*

## Yêu cầu hệ thống

- Android 7.0 (API level 24) trở lên
- Cần cấp các quyền: đọc thông báo, SMS (đọc, gửi, nhận)
- Cần tắt tối ưu hóa pin và cấu hình cho phép tự khởi động

## Cài đặt và cấu hình cho nhà phát triển

```bash
# Clone repository
git clone https://github.com/ax7-quantum/notifybank.git

# Cài đặt dependencies
flutter pub get

# Chạy ứng dụng
flutter run

# Build 
flutter build apk --split-per-abi
Giấy phép
Dự án này được phân phối dưới Giấy phép Công cộng GNU v3.0 (GPL-3.0).
