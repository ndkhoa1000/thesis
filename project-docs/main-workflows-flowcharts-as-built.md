# Flowchart Các Luồng Hoạt Động Chính

## Mục tiêu

Tài liệu này vẽ lại các luồng vận hành quan trọng nhất của app theo kiểu as-built: ưu tiên logic đang có trong backend/mobile hiện tại, đồng thời đánh dấu rõ những điểm vẫn còn gap hoặc placeholder trên UI.

## 1. Capability application và cấp workspace

```mermaid
flowchart TD
  Start[User đang ở public account] --> Choose[Chọn đăng ký Lot Owner hoặc Operator]
  Choose --> Submit[Submit application + document reference]
  Submit --> Pending[Application status = PENDING]
  Pending --> AdminReview{Admin duyệt?}
  AdminReview -->|Approve| Promote[Tạo capability row tương ứng]
  Promote --> RoleSwitch[Cập nhật role hoặc capability map]
  RoleSwitch --> Workspace[User đăng nhập lại hoặc đổi workspace]
  AdminReview -->|Reject| Rejected[Lưu rejection_reason]
  Rejected --> Retry[Cho phép nộp lại sau khi sửa hồ sơ]
```

Lưu ý:

- Capability không được gắn trực tiếp chỉ bằng field `role`; backend còn giữ riêng bảng `lot_owner`, `manager`, `lot_owner_application`, `operator_application`.
- Attendant và Admin là nhánh account riêng, không đi qua public capability flow này.

## 2. Chuỗi làm bãi xe đi vào trạng thái khai thác

```mermaid
flowchart TD
  OwnerApply[Lot Owner đã được duyệt capability] --> RegisterLot[Đăng ký bãi xe]
  RegisterLot --> LotPending[ParkingLot = PENDING]
  LotPending --> AdminLot{Admin duyệt bãi?}
  AdminLot -->|Reject| LotRejected[Bãi bị từ chối]
  AdminLot -->|Approve| LotApproved[ParkingLot = APPROVED]
  LotApproved --> LeaseOffer[Lot Owner tạo đề nghị cho thuê]
  LeaseOffer --> OperatorApply[Operator nộp yêu cầu thuê]
  OperatorApply --> LeasePending[LotLease = PENDING]
  LeasePending --> AdminLease{Admin duyệt lease?}
  AdminLease -->|Reject| LeaseRejected[Lease không kích hoạt]
  AdminLease -->|Approve| LeaseActive[LotLease = ACTIVE + sinh LeaseContract]
  LeaseActive --> Configure[Operator cấu hình capacity, giờ, pricing]
  Configure --> CreateAttendant[Tạo tài khoản attendant]
  CreateAttendant --> Discoverable[Lot sẵn sàng cho luồng driver và attendant]
```

Lưu ý:

- Workflow docs thường gọi trạng thái lot “live” là `ACTIVE`, nhưng enum `parking_lot.status` ở model hiện tại vẫn là `APPROVED/CLOSED`. Trạng thái “sẵn sàng vận hành” thực tế là kết quả tổng hợp của approval + lease active + config hiện hành.
- Mobile shell của Admin, Operator, Lot Owner hiện chưa hoàn thiện toàn bộ tab phụ, nên một phần thao tác vẫn thiên về screen chính hoặc backend contract hơn là full UI coverage.

## 3. Driver tìm bãi và đặt chỗ

```mermaid
flowchart TD
  OpenMap[Mở bản đồ] --> LoadLots[Load danh sách bãi đã duyệt]
  LoadLots --> SelectLot[Chọn bãi và xem chi tiết]
  SelectLot --> WantBooking{Driver đặt chỗ?}
  WantBooking -->|Không| Navigate[Đi thẳng đến bãi]
  WantBooking -->|Có| SelectVehicle[Chọn xe + ETA]
  SelectVehicle --> CapacityCheck{Còn chỗ?}
  CapacityCheck -->|Không| RejectFull[Từ chối booking]
  CapacityCheck -->|Có| CreateBooking[Tạo Booking + giữ chỗ]
  CreateBooking --> BookingConfirmed[Booking = CONFIRMED]
  BookingConfirmed --> Arrival{Đến bãi trước hạn?}
  Arrival -->|Có| CheckIn[Attendant check-in, booking được consume]
  Arrival -->|Không| Expire[Booking hết hạn, trả capacity]
```

Lưu ý:

- Availability trên map có luồng realtime qua WebSocket cho lot đang được quan tâm.
- Booking là biên giữ chỗ tạm thời, không phải `ParkingSession`. Session chỉ sinh ra khi attendant thực hiện check-in.

## 4. Core parking loop bằng QR

```mermaid
flowchart TD
  DriverSelectVehicle[Driver chọn xe] --> IssueQR[Backend ký QR check-in token]
  IssueQR --> ShowQR[Mobile hiển thị QR]
  ShowQR --> ScanIn[Attendant quét QR]
  ScanIn --> ValidateIn{Token hợp lệ và chưa có active session?}
  ValidateIn -->|Không| CheckInError[Từ chối check-in]
  ValidateIn -->|Có| CreateSession[Tạo ParkingSession + giảm current_available]
  CreateSession --> Active[Session = CHECKED_IN]
  Active --> DriverCheckoutQR[Driver lấy QR check-out]
  DriverCheckoutQR --> ScanOut[Attendant quét QR check-out]
  ScanOut --> Preview[Backend trả checkout preview]
  Preview --> Confirm{Xác nhận thanh toán?}
  Confirm -->|Không| Abort[Không mutate state]
  Confirm -->|Có| Finalize[Tạo Payment + cập nhật session CHECKED_OUT + tăng current_available]
  Finalize --> UndoWindow{Trong cửa sổ undo?}
  UndoWindow -->|Có| Undo[Reopen session nếu hoàn tác hợp lệ]
  UndoWindow -->|Hết hạn| Done[Kết thúc]
```

Lưu ý:

- Check-out preview và finalize là hai bước tách biệt. Preview không được mutate state.
- Finalize có logic chống double finalize, stale preview và rollback khi commit lỗi.

## 5. Attendant walk-in check-in

```mermaid
flowchart TD
  WalkIn[Khách không dùng app] --> CapturePhoto[Attendant chụp ảnh biển số / đầu xe]
  CapturePhoto --> ValidatePhoto{Có ảnh hợp lệ?}
  ValidatePhoto -->|Không| RejectPhoto[Từ chối tạo session]
  ValidatePhoto -->|Có| ValidateLot{Bãi còn chỗ?}
  ValidateLot -->|Không| RejectFull[Từ chối vì đầy chỗ]
  ValidateLot -->|Có| CreateWalkIn[Tạo ParkingSession walk-in + giảm current_available]
  CreateWalkIn --> PlaceholderPlate[Biển số có thể để placeholder hoặc plate manual]
  PlaceholderPlate --> Continue[Tiếp tục quản lý bằng attendant workspace]
```

Lưu ý:

- Walk-in check-in đã có backend contract và test.
- Walk-in check-out end-to-end vẫn là vùng cần chốt thêm trong demo scope; workflow-truth-map cũng đánh dấu đây là điểm chưa rõ của MVP.

## 6. Handover ca và close-out cuối ngày

```mermaid
flowchart TD
  EndShift[Attendant kết thúc ca] --> SumCash[Backend tính expected cash]
  SumCash --> IssueShiftQR[Phát shift handover token/QR]
  IssueShiftQR --> IncomingScan[Attendant ca sau quét QR]
  IncomingScan --> CountCash[Nhập actual cash]
  CountCash --> Match{Khớp expected cash?}
  Match -->|Có| LockShift[Khóa ca cũ và bàn giao]
  Match -->|Không| NeedReason{Có nhập lý do?}
  NeedReason -->|Không| Block[Chặn hoàn tất bàn giao]
  NeedReason -->|Có| AlertOperator[Khóa ca + tạo notification cho operator]
  LockShift --> DayEnd{Đóng ngày?}
  AlertOperator --> DayEnd
  DayEnd --> EmptyLot{Bãi đã hết session active?}
  EmptyLot -->|Không| RejectCloseOut[Không cho close-out]
  EmptyLot -->|Có| RequestCloseOut[Tạo yêu cầu close-out]
  RequestCloseOut --> OperatorConfirm[Operator xác nhận hoàn tất close-out]
```

Lưu ý:

- Shift handover và final close-out đã có schema và test backend.
- Đây là flow vận hành mạnh ở backend, nhưng không phải phần được thể hiện đầy đủ nhất trên mobile so với core check-in/out.

## Những gap nên giữ nguyên trong tài liệu demo

| Chủ đề | Trạng thái nên mô tả |
|---|---|
| Offline pending sync cho attendant | Chưa có trong flow chạy thật, không nên mô tả như đã triển khai |
| Walk-in check-out credential | Chưa chốt rõ end-to-end, nên đánh dấu là giới hạn MVP |
| Admin Users/Parking Lots tab | Có shell nhưng UI còn mỏng hoặc placeholder |
| Lot Owner contracts/profile tab | Có hướng nghiệp vụ nhưng UI chưa đầy đủ |
| Multi-lot picker cho operator | Cần giải thích như một điểm còn có thể mở rộng |