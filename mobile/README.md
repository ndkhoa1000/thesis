# Mapbox Flutter Project on WSL

Dự án này là một ví dụ cơ bản để kiểm tra việc tích hợp Mapbox SDK trên Flutter và chạy từ môi trường WSL (Ubuntu) sang một thiết bị Android kết nối bên ngoài.

## 1. Kết nối điện thoại với WSL qua ADB

Do WSL chạy trong một máy ảo, bạn không thể kết nối trực tiếp thiết bị Android qua cổng USB của WSL một cách mặc định (trừ khi dùng usbipd). Cách dễ và ổn định nhất là sử dụng **ADB qua Wi-Fi** hoặc **cầu nối ADB từ Windows sang WSL**.

### Cách 1: Sử dụng ADB qua Wi-Fi (Khuyên dùng)
1. Kết nối điện thoại và máy tính Windows vào **cùng một mạng Wi-Fi**.
2. Trên thiết bị Android, bật **Developer Options** (Tùy chọn nhà phát triển) và bật **Wireless Debugging** (Gỡ lỗi không dây).
3. Trong menu Wireless Debugging trên điện thoại, chọn **Pair device with pairing code** (Ghép nối thiết bị bằng mã ghép nối). Nó sẽ hiện ra \`IP:PORT\` và Mã ghép nối.
4. Mở terminal WSL (Ubuntu) và chạy:
   ```bash
   adb pair <IP>:<PORT>
   ```
   (Nhập mã ghép nối khi được yêu cầu).
5. Sau khi pair thành công, kết nối adb với device bằng IP và cổng kết nối (không phải cổng pair):
   ```bash
   adb connect <IP>:<CONNECT_PORT>
   ```
6. Kiểm tra thiết bị đã nhận chưa:
   ```bash
   adb devices
   ```

### Cách 2: Dùng Windows ADB Server nối sang WSL
Nếu bạn cắm cáp USB vào Windows máy tính:
1. Trên **Windows**, mở Command Prompt / PowerShell và chạy:
   ```cmd
   adb kill-server
   adb -a nodaemon server start
   ```
2. Trên **WSL (Ubuntu)**, cấu hình ADB host trỏ về Windows:
   ```bash
   export ADB_SERVER_SOCKET=tcp:$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):5037
   adb devices
   ```

## 2. Cấu hình Mapbox
Để chạy ứng dụng Mapbox, bạn cần cung cấp một Access Token riêng của bạn (tạo miễn phí tại https://account.mapbox.com/).

### Chạy ứng dụng với Access Token

Tạo file `.env` trong thư mục `mobile/` và thêm token của bạn vào đó:
```env
ACCESS_TOKEN=pk.eyJ1I...
```

Khi đã kết nối điện thoại qua ADB thành công, chỉ cần chạy:
```bash
flutter run
```

## 3. Kết nối mobile auth tới backend local

Backend auth trong repo này chạy mặc định ở `http://127.0.0.1:8000/api/v1` từ máy dev. Flutter mobile cần `API_BASE_URL` phù hợp với môi trường chạy:

Tạo file `mobile/.env` như sau:
```env
ACCESS_TOKEN=pk.eyJ1I...
API_BASE_URL=http://10.0.2.2:8000/api/v1
```

- Android emulator: dùng `http://10.0.2.2:8000/api/v1`.
- Android thiết bị thật qua ADB: chạy `adb reverse tcp:8000 tcp:8000` rồi đặt `API_BASE_URL=http://127.0.0.1:8000/api/v1`.
- Thiết bị thật qua mạng LAN: đặt `API_BASE_URL` trỏ tới IP LAN có thể truy cập được của máy chạy backend.

Nếu backend đang chạy bằng Docker Compose trong `backend/`, hãy kiểm tra `backend-web-1` đang publish cổng `8000:8000` trước khi mở app.

> **Lưu ý nhỏ về Mapbox Android SDK:** Có thể bạn vẫn cần cấu hình file `~/.gradle/gradle.properties` chứa secret Mapbox token để tải thư viện SDK về.
> Hãy thêm dòng sau vào `~/.gradle/gradle.properties`:
> `MAPBOX_DOWNLOADS_TOKEN=sk.eyJ1I...`

---
Bây giờ bạn đã có một dự án Flutter hoàn thiện để kiểm tra Mapbox chạy qua WSL thẳng lên thiết bị thật!
