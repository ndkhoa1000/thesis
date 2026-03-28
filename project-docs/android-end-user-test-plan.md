# Android End-User Test Plan

## Purpose

Tài liệu này chuẩn hóa môi trường test Android cho end user, danh sách tài khoản cố định, dữ liệu demo tối thiểu, và checklist theo epic trước khi chốt một story hay epic là chạy ổn.

## Environment Setup

1. Backend
   - Chạy backend và database từ thư mục `backend`.
   - Áp migration mới nhất trước khi seed dữ liệu.
   - Seed dữ liệu demo cố định bằng lệnh:

```bash
cd backend
python -m src.scripts.seed_android_demo_data
```

2. Mobile Android
   - Trong `mobile/.env`, cấu hình tối thiểu:

```env
API_BASE_URL=http://127.0.0.1:8000/api/v1
MAPBOX_ACCESS_TOKEN=<your-mapbox-token>
```

   - Nếu chạy trên thiết bị Android thật:

```bash
adb reverse tcp:8000 tcp:8000
cd mobile
flutter run -d <device-id>
```

3. Minimum Demo Dataset Expectations
   - Có một bãi đã được duyệt, đã lease cho operator, đã có config/pricing hiện hành để test Epic 4 và Epic 5.
   - Có một bãi đã lease cho operator nhưng chưa cấu hình hoàn chỉnh để test flow cấu hình Operator trên Android.
   - Có một attendant đã gắn vào bãi demo ready.
   - Có một driver và một vehicle mẫu.
   - Có lịch sử session đủ để màn lot details hiển thị peak-hours chart thật.

## Fixed Accounts

| Role | Email | Password | Notes |
| --- | --- | --- | --- |
| Admin | `admin.demo@parking.local` | `Admin123!` | Duyệt application, duyệt bãi, suspend/reopen lot |
| Driver | `driver.demo@parking.local` | `Driver123!` | Xem map, lot details, QR check-in |
| Lot Owner | `owner.demo@parking.local` | `Owner123!` | Tạo bãi, xem bãi sở hữu, gán operator thử nghiệm |
| Operator | `operator.demo@parking.local` | `Operator123!` | Cấu hình bãi được gán, tạo attendant |
| Attendant | `attendant.demo@parking.local` | `Attendant123!` | Quét QR check-in/check-out tại bãi demo ready |

## Seeded Demo Assets

1. `Bãi xe Demo Nguyễn Huệ`
   - `APPROVED`
   - Đã có `ACTIVE` lease cho operator demo
   - Đã có sức chứa, giờ hoạt động, giá hiện hành
   - Đã gắn attendant demo
   - Có session lịch sử để lot details hiển thị peak hours

2. `Bãi xe Demo Thiết Lập`
   - `CLOSED`
   - Đã có `ACTIVE` lease cho operator demo
   - Chưa có config/pricing hiện hành
   - Dùng riêng để test flow operator cấu hình bãi xe trên Android

## Epic Test Matrix

### Epic 1: User Identity & Profiles

Environment / Preconditions:
- Backend lên ổn định và seed xong tài khoản cố định.
- Thiết bị Android truy cập được API_BASE_URL.

Scenarios:
- Login bằng từng account cố định và xác nhận route đúng workspace.
- Driver logout rồi login lại với tùy chọn nhớ phiên và không nhớ phiên.
- Driver mở màn quản lý xe và xác nhận vehicle demo hiển thị được.

Edge Cases:
- Sai mật khẩu.
- API_BASE_URL sai hoặc backend tắt.
- Session đã lưu nhưng refresh token không còn hợp lệ.

### Epic 2: Platform Inventory & Approvals

Environment / Preconditions:
- Admin account hoạt động.
- Lot owner account đăng nhập được.

Scenarios:
- Lot owner tạo một hồ sơ bãi mới bằng cách chọn vị trí trên bản đồ.
- Admin duyệt hồ sơ bãi mới.
- Admin suspend rồi reopen một bãi đã duyệt.

Edge Cases:
- Lot owner chưa chọn vị trí nhưng bấm gửi.
- Admin thử duyệt lại hồ sơ đã xử lý.
- Bãi bị `CLOSED` không xuất hiện trên public map.

### Epic 3: Lot Operations Setup

Environment / Preconditions:
- `Bãi xe Demo Thiết Lập` đã tồn tại và đã có lease active cho operator demo.

Scenarios:
- Operator login và thấy bãi được gán trong workspace.
- Operator cấu hình sức chứa, giờ hoạt động, giá hiện hành cho bãi demo setup.
- Operator tạo attendant mới rồi thu hồi attendant đó.

Edge Cases:
- Nhập `7:00` thay vì `07:00` vẫn lưu được sau chuẩn hóa.
- Sức chứa mới nhỏ hơn số xe đang có trong bãi thì `current_available` không âm.
- Giờ đóng cửa trùng giờ mở cửa bị chặn.

### Epic 4: Core Parking Loop

Environment / Preconditions:
- `Bãi xe Demo Nguyễn Huệ` đã có config/pricing hiệu lực.
- Attendant demo đang gắn vào bãi demo ready.
- Driver demo có vehicle mẫu.

Scenarios:
- Driver tạo QR check-in.
- Attendant login, quét QR và tạo session thành công.
- Attendant preview checkout, finalize payment cash, rồi xác nhận session đóng đúng.

Edge Cases:
- Quét QR không hợp lệ hoặc QR hết hạn.
- Finalize checkout với quoted fee thiếu hoặc lệch.
- Session đã đóng nhưng attendant cố finalize lần nữa.

### Epic 5: Driver Discovery

Environment / Preconditions:
- `MAPBOX_ACCESS_TOKEN` đã cấu hình trong `mobile/.env` nếu cần test Mapbox thật.
- `Bãi xe Demo Nguyễn Huệ` vẫn ở trạng thái `APPROVED` và có current availability > 0.

Scenarios:
- Driver thấy marker/public lot trên bản đồ.
- Driver mở lot details bằng quick card rail.
- Driver mở lot details bằng cách tap trực tiếp marker trên map.
- Driver refresh lot details và thấy availability text/hours/pricing/peak hours.

Edge Cases:
- Không có Mapbox token: fallback canvas vẫn cho phép mở chi tiết từ danh sách và lot-owner vẫn có thể chọn vị trí bằng fallback picker.
- Lot thiếu dữ liệu lịch sử: lot details hiện empty-state trung thực, không tạo fake chart.
- Bản ghi pricing/config tương lai không được hiển thị sớm cho driver.

## Done Gate For Any Story/Epic

Trước khi chốt `review` hoặc `done`, cần ghi rõ:

1. Môi trường test Android đã dùng:
   - emulator hay thiết bị thật
   - API_BASE_URL nào
   - có hay không có Mapbox token

2. Preconditions đã thỏa:
   - account nào dùng
   - seed script version/ngày chạy
   - dữ liệu nào được tạo thêm thủ công nếu có

3. Kịch bản đã chạy:
   - happy path
   - ít nhất một edge case quan trọng
   - nếu story chạm auth hoặc pricing thì phải test logout/relogin hoặc dữ liệu hiệu lực hiện hành

4. Kết quả:
   - pass/fail theo từng scenario
   - bug còn mở
   - workaround tạm thời nếu chưa fix được

## Suggested Workflow For Future Stories

1. Cập nhật seed script nếu story cần thêm dữ liệu baseline mới cho Android demo.
2. Bổ sung scenario vào tài liệu này ngay khi story hoàn tất dev.
3. Chạy ít nhất một smoke test trực tiếp trên Android trước khi đổi story sang `done`.