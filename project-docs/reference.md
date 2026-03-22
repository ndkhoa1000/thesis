# Tóm Tắt Ứng Dụng — Hệ thống Quản lý Bãi xe Thông minh

## 1. Tổng Quan

Ứng dụng là một **nền tảng trung gian** kết nối chủ sở hữu bãi xe, người vận hành kinh doanh, nhân viên giữ xe và tài xế trong một hệ sinh thái thống nhất. Mô hình hoạt động áp dụng cho lĩnh vực bãi đỗ xe: **chủ sở hữu bất động sản** rao cho thuê diện tích bãi xe, **quản lý kinh doanh** thuê lại và điều hành, **tài xế** sử dụng dịch vụ thông qua ứng dụng di động.

### Vấn đề giải quyết
- Tài xế khó tìm bãi xe, không biết bãi còn chỗ hay không theo thời gian thực.
- Bãi xe nhỏ lẻ thiếu công cụ số hóa để quản lý vận hành và thu tiền.
- Chủ bất động sản có diện tích bãi xe nhàn rỗi không có kênh để khai thác.
- Thiếu tính minh bạch trong giao dịch và lịch sử gửi xe.

---

## 2. Các Đối Tượng Sử Dụng (Actors)

### 2.1 Tài xế (Driver) — *Đối tượng chính*
Người sử dụng ứng dụng di động để tìm bãi xe, gửi/lấy xe bằng QR code, đặt trước và mua vé tháng.

### 2.2 Nhân viên giữ xe (Attendant)
Nhân viên tại bãi, sử dụng ứng dụng để quét mã check-in/check-out, chụp hình xe, thu tiền và quản lý danh sách xe trong bãi.

### 2.3 Quản lý bãi xe (Operator/Manager)
Đơn vị kinh doanh dịch vụ gửi xe. Thuê bãi từ chủ cho thuê, thiết lập vận hành (giá, giờ, nhân sự), đăng thông báo và theo dõi doanh thu.

### 2.4 Chủ cho thuê bãi xe (Lot Owner/Lessor)
Sở hữu diện tích bãi xe vật lý. Đăng ký bãi lên hệ thống, rao cho thuê và quản lý hợp đồng với các Operator.

### 2.5 Admin hệ thống
Duyệt bãi xe mới, duyệt yêu cầu thuê bãi, quản lý toàn bộ người dùng và xuất hoá đơn khi cần.

---

## 3. Luồng Hoạt Động Chính

```
LotOwner đăng ký bãi
       ↓
Admin duyệt bãi
       ↓
Operator đăng ký thuê bãi → Admin duyệt hợp đồng
       ↓
Operator cấu hình bãi (giá, giờ, nhân viên)
       ↓
Tài xế tìm thấy bãi → Đặt trước / Đến trực tiếp
       ↓
Nhân viên quét QR check-in → chụp hình, ghi nhận
       ↓
Nhân viên quét QR check-out → tính tiền → thu tiền
       ↓
Tài xế / Nhân viên nhận biên lai
```

---

## 4. Phân Loại Thông Tin Bãi Xe

| Loại | Thuộc tính | Ai thay đổi |
|------|-----------|-------------|
| Cố định | Địa chỉ, toạ độ, hình ảnh, mô tả, loại xe | Operator |
| Tạm thời | Giá theo giờ, sức chứa, giờ mở/đóng cửa | Operator (theo thời điểm) |
| Thông báo | Sự kiện gần đó, kẹt xe, giờ cao điểm, đóng cửa tạm | Operator |
| Trạng thái | Số chỗ trống, xe đang đậu | Hệ thống (realtime) |

---

## 5. User Stories

### 5.1 Tài xế

| ID | User Story | Điều kiện chấp nhận |
|----|-----------|---------------------|
| US-D01 | Là tài xế, tôi muốn **tìm bãi xe gần vị trí của mình trên bản đồ** để biết chỗ nào còn trống. | Hiển thị danh sách/map bãi xe trong bán kính, có chỉ số chỗ trống realtime. |
| US-D02 | Là tài xế, tôi muốn **xem chi tiết bãi xe** (giá, giờ mở, ảnh, tính năng) trước khi quyết định đến. | Màn hình chi tiết đầy đủ thông tin, hình ảnh, thông báo hiện tại của bãi. |
| US-D03 | Là tài xế, tôi muốn **đặt chỗ trước** để chắc chắn có chỗ khi đến. | Đặt chỗ thành công → hệ thống tạm giữ 1 slot và thanh toán đặt cọc. Tự hủy nếu không đến đúng giờ. |
| US-D04 | Là tài xế, tôi muốn **mua vé tháng/tuần** để tiết kiệm chi phí khi đậu thường xuyên. | Chọn bãi, chọn gói, thanh toán → nhận vé với ngày bắt đầu/kết thúc. |
| US-D05 | Là tài xế, tôi muốn **tự quét mã QR để gửi xe** mà không cần chờ nhân viên. | App hiển thị màn hình quét QR, quét thành công → check-in, hệ thống ghi nhận giờ vào. |
| US-D06 | Là tài xế, tôi muốn **tự quét mã QR để lấy xe** và xem số tiền cần trả. | Quét QR tại cổng ra → hiển thị tổng thời gian, số tiền → chọn phương thức thanh toán. |
| US-D07 | Là tài xế, tôi muốn **thanh toán phí gửi xe online** qua ví/thẻ để không cần tiền mặt. | Tích hợp cổng thanh toán, thanh toán thành công → xuất biên lai kỹ thuật số. |
| US-D08 | Là tài xế, tôi muốn **xem lịch sử các lần gửi xe** để kiểm tra chi phí và thời gian. | Danh sách lịch sử có ngày, bãi xe, thời gian, số tiền, trạng thái. |

### 5.2 Nhân viên giữ xe

| ID | User Story | Điều kiện chấp nhận |
|----|-----------|---------------------|
| US-A01 | Là nhân viên, tôi muốn **quét mã QR / thẻ NFC để check-in xe** nhanh chóng. | Quét thành công → mở phiên gửi xe mới, hiển thị thông tin xe/tài xế nếu có. |
| US-A02 | Là nhân viên, tôi muốn **chụp ảnh xe khi nhận gửi** để lưu bằng chứng tình trạng xe. | Sau check-in, bắt buộc hoặc tuỳ chọn chụp ảnh mặt trước/sau. Ảnh lưu vào phiên. |
| US-A03 | Là nhân viên, tôi muốn **ghi nhận biển số xe** khi tài xế gửi không qua app. | Nhập biển số thủ công khi không quét được mã, hệ thống tạo phiên gửi xe thủ công. |
| US-A04 | Là nhân viên, tôi muốn **quét mã QR / thẻ NFC để check-out** và tính ra số tiền. | Quét thành công → hiển thị tổng thời gian, áp dụng bảng giá hiện hành, hiện số tiền. |
| US-A05 | Là nhân viên, tôi muốn **ghi nhận thanh toán tiền mặt** để hệ thống cập nhật trạng thái. | Nút "Xác nhận thu tiền mặt" → cập nhật payment_status = COMPLETED, phương thức = CASH. |
| US-A06 | Là nhân viên, tôi muốn **hỗ trợ tài xế thanh toán online** ngay tại quầy. | Hiển thị QR thanh toán hoặc nhập số tiền vào cổng thanh toán thay tài xế. |
| US-A07 | Là nhân viên, tôi muốn **xem danh sách xe đang trong bãi** theo thời gian thực. | Màn hình thống kê: tổng chỗ, đang có xe, còn trống, phân theo loại xe. |
| US-A08 | Là nhân viên, tôi muốn **chỉnh sửa thông tin phiên gửi xe** khi có nhập liệu sai. | Chọn phiên → chỉnh biển số / slot / loại xe → lưu kèm lý do → ghi vào SessionEdit. |

### 5.3 Quản lý bãi xe (Operator)

| ID | User Story | Điều kiện chấp nhận |
|----|-----------|---------------------|
| US-O01 | Là Operator, tôi muốn **đăng ký thuê một bãi xe** đang rao cho thuê để kinh doanh. | Chọn bãi → điền thông tin hợp đồng → gửi yêu cầu → chờ Admin duyệt. |
| US-O02 | Là Operator, tôi muốn **cập nhật thông tin cố định của bãi** (địa chỉ, mô tả, hình ảnh). | Form chỉnh sửa, lưu → cập nhật ngay trên app tài xế. |
| US-O03 | Là Operator, tôi muốn **cấu hình giá theo giờ** cho từng loại xe và từng khung giờ. | Tạo bản giá có thời hạn hiệu lực, nhiều mức giá cho MOTORBIKE / CAR. |
| US-O04 | Là Operator, tôi muốn **điều chỉnh sức chứa và giờ mở/đóng cửa** linh hoạt theo thời điểm. | Thay đổi `total_capacity`, `opening_time`, `closing_time` có ngày hiệu lực. |
| US-O05 | Là Operator, tôi muốn **đăng thông báo về bãi xe** (sự kiện nearby, cảnh báo kẹt xe, giờ cao điểm). | Tạo thông báo có loại, nội dung, thời gian hiển thị → hiện trên app tài xế khi xem bãi. |
| US-O06 | Là Operator, tôi muốn **xem báo cáo doanh thu** theo ngày/tuần/tháng. | Dashboard biểu đồ doanh thu, số lượt gửi, xe vào/ra, tỷ lệ lấp đầy. |

### 5.4 Chủ cho thuê bãi xe (Lot Owner)

| ID | User Story | Điều kiện chấp nhận |
|----|-----------|---------------------|
| US-L01 | Là Lot Owner, tôi muốn **đăng ký bãi xe tôi sở hữu** lên hệ thống để hợp lệ hoá. | Điền thông tin bãi, tải giấy tờ sở hữu → gửi yêu cầu → Admin duyệt. |
| US-L02 | Là Lot Owner, tôi muốn **rao cho thuê bãi xe** với giá và điều kiện cụ thể. | Cấu hình giá thuê/tháng, điều kiện → đăng lên marketplace nội bộ cho Operator tìm. |
| US-L03 | Là Lot Owner, tôi muốn **quản lý các hợp đồng thuê** đang hoạt động. | Xem danh sách hợp đồng: trạng thái, Operator, thời hạn, khả năng gia hạn/huỷ. |

### 5.5 Admin hệ thống

| ID | User Story | Điều kiện chấp nhận |
|----|-----------|---------------------|
| US-AD01 | Là Admin, tôi muốn **duyệt hoặc từ chối đăng ký bãi xe** của Lot Owner. | Xem thông tin bãi + giấy tờ → Approve/Reject kèm lý do → Lot Owner nhận thông báo. |
| US-AD02 | Là Admin, tôi muốn **duyệt yêu cầu thuê bãi** của Operator. | Xem thông tin hợp đồng đề xuất → Approve tạo `LotLease` ACTIVE / Reject kèm lý do. |
| US-AD03 | Là Admin, tôi muốn **quản lý toàn bộ người dùng** (khoá, mở, thay đổi role). | Tìm kiếm user, xem chi tiết, bật/tắt `is_active`, đổi role khi cần. |
| US-AD04 | Là Admin, tôi muốn **in hoá đơn cho khách hàng** khi được yêu cầu. | Tra cứu payment → tạo Invoice nếu chưa có → xuất PDF. |

---

## 6. Các Luồng Quan Trọng

### Luồng gửi xe (Walk-in, không đặt trước)
1. Tài xế đến bãi xe.
2. Nhân viên quét mã QR trên xe hoặc thẻ NFC.
3. Hệ thống tạo `ParkingSession` mới, ghi `checkin_time`.
4. Nhân viên chụp ảnh xe (tuỳ chọn hoặc bắt buộc).
5. Tài xế được phép vào.

### Luồng lấy xe và thanh toán
1. Tài xế báo lấy xe — nhân viên quét mã ra.
2. Hệ thống tính tiền theo `Pricing` hiện hành × thời gian.
3. Áp dụng giảm giá nếu có vé tháng / đặt trước.
4. Tài xế chọn thanh toán tiền mặt hoặc online.
5. Hệ thống tạo `Payment` → cập nhật `ParkingSession.status = CHECKED_OUT`.
6. `ParkingLot.current_available` tăng lên.

### Luồng đặt trước bãi xe
1. Tài xế tìm bãi → chọn "Đặt chỗ".
2. Chọn giờ đến, loại xe → xác nhận → thanh toán đặt cọc online.
3. Hệ thống tạo `Booking` (PENDING → CONFIRMED), giảm `current_available` tạm.
4. Khi tài xế đến và check-in, `Booking` được liên kết vào `ParkingSession`.
5. Nếu không đến trước `expiration_time`, booking tự hủy → hoàn chỗ.

### Luồng mua vé tháng
1. Tài xế chọn bãi → "Mua vé tháng/tuần".
2. Chọn gói (tuần/tháng, loại xe) → thanh toán online.
3. Hệ thống tạo `Subscription` + `SubscriptionLot`.
4. Trong thời hạn vé, khi check-out: hệ thống nhận diện vé còn hiệu lực → miễn phí hoặc giảm giá.

---
