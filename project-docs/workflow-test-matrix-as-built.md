# Test Matrix Và Edge Cases Theo Từng Flow

## Mục tiêu

Các bảng dưới đây không chỉ liệt kê happy path mà còn nêu rõ edge case hệ thống đang kỳ vọng xử lý như thế nào. Bảng được dựng từ workflow truth map và các test backend hiện có, nên có thể dùng như tài liệu kiểm thử mức nghiệp vụ.

## 1. Capability application và cấp quyền workspace

| Case ID | Tình huống | Kỳ vọng backend | Kỳ vọng UI / hệ thống | Chứng cứ hiện có |
|---|---|---|---|---|
| CAP-01 | User nộp hồ sơ Lot Owner hợp lệ | Tạo `lot_owner_application` với `PENDING` | Hiện thông báo gửi hồ sơ thành công | `backend/tests/test_lot_owner_applications.py::test_create_application_success` |
| CAP-02 | User đã có hồ sơ Lot Owner đang pending | Từ chối tạo mới, tránh duplicate | UI phải báo đã có hồ sơ đang chờ duyệt | `backend/tests/test_lot_owner_applications.py::test_pending_application_raises_duplicate` |
| CAP-03 | Hồ sơ Lot Owner bị reject trước đó và nộp lại | Cho phép resubmit | UI có thể cho nộp lại sau khi sửa hồ sơ | `backend/tests/test_lot_owner_applications.py::test_rejected_application_can_be_resubmitted` |
| CAP-04 | Admin duyệt hồ sơ Lot Owner | Tạo row `lot_owner`, cập nhật capability/role phù hợp | User thấy workspace tương ứng sau lần đăng nhập tiếp theo | `backend/tests/test_lot_owner_applications.py::test_approve_application_creates_lot_owner_capability` |
| CAP-05 | Admin reject mà không có lý do | Từ chối thao tác review | UI admin phải bắt buộc nhập lý do reject | `backend/tests/test_lot_owner_applications.py::test_reject_application_requires_reason` |
| CAP-06 | Operator application được duyệt cho user đang là Lot Owner | Promote đúng sang manager capability mà không phá public account | Shell điều hướng được sang workspace operator | `backend/tests/test_operator_applications.py::test_approve_application_promotes_lot_owner_workspace_to_manager` |

## 2. Lease chain và trạng thái khai thác bãi xe

| Case ID | Tình huống | Kỳ vọng backend | Kỳ vọng UI / hệ thống | Chứng cứ hiện có |
|---|---|---|---|---|
| LOT-01 | Lot Owner tạo lease contract lần đầu | Tạo `lot_lease` pending/open path hợp lệ | Lot xuất hiện trong luồng hợp đồng phù hợp | `backend/tests/test_leases.py::test_create_owner_lease_contract_success` |
| LOT-02 | Cố tạo lease mới khi đã có open lease | Từ chối tạo lease chồng lấn | UI phải báo đã có hợp đồng đang mở | `backend/tests/test_leases.py::test_create_owner_lease_contract_rejects_existing_open_lease` |
| LOT-03 | Admin/operator accept lease contract hợp lệ | Lease chuyển trạng thái chấp nhận, contract kích hoạt | Operator nhìn thấy lot đã thuê | `backend/tests/test_leases.py::test_accept_operator_lease_contract_success` |
| LOT-04 | Accept lease nhưng thiếu contract | Từ chối thao tác | UI phải báo lỗi dữ liệu hợp đồng | `backend/tests/test_leases.py::test_accept_operator_lease_contract_rejects_missing_contract` |
| LOT-05 | Operator đọc danh sách lot đang quản lý | Chỉ trả các lot có lease active/hợp lệ theo thời điểm | Màn hình operator chỉ hiện lot đang được phép thao tác | `backend/tests/test_operator_lot_management.py::test_read_operator_parking_lots_returns_active_leased_lots` |
| LOT-06 | Lease hết hạn sau refresh | Lot không còn hiện trong danh sách active managed lots | UI không cho thao tác như lot đang active | `backend/tests/test_operator_lot_management.py::test_read_operator_parking_lots_skips_expired_leases_after_refresh` |
| LOT-07 | Operator patch config cho lot pending hoặc không có active lease | Từ chối với not found / bad request đúng ngữ cảnh | UI phải chặn sửa lot chưa đủ điều kiện | `backend/tests/test_operator_lot_management.py::test_patch_operator_parking_lot_raises_not_found_without_active_lease`, `backend/tests/test_operator_lot_management.py::test_patch_operator_parking_lot_rejects_pending_lot` |

## 3. Driver booking flow

| Case ID | Tình huống | Kỳ vọng backend | Kỳ vọng UI / hệ thống | Chứng cứ hiện có |
|---|---|---|---|---|
| BOOK-01 | Booking hợp lệ khi lot còn chỗ | Tạo `booking`, giữ capacity, tạo payment/token liên quan | UI nhận booking confirmed | `backend/tests/test_bookings.py::test_create_booking_holds_capacity_records_payment_and_returns_signed_token` |
| BOOK-02 | Driver cố tạo booking active trùng tại cùng lot | Từ chối duplicate active booking | UI báo đang có booking hoạt động | `backend/tests/test_bookings.py::test_rejects_duplicate_active_booking_at_same_lot` |
| BOOK-03 | Lot đầy | Từ chối booking ngay tại backend | UI báo hết chỗ, không giữ capacity sai | `backend/tests/test_bookings.py::test_rejects_booking_when_lot_is_full` |
| BOOK-04 | Booking đến hạn timeout | Chuyển booking sang expired và trả capacity đúng 1 lần | UI đọc lại thấy trạng thái expired | `backend/tests/test_bookings.py::test_reads_expired_booking_state_and_releases_capacity_when_latest_booking_times_out` |
| BOOK-05 | Booking bị cancel rồi đọc trạng thái | Không lộ booking expired cũ gây hiểu nhầm | UI luôn thấy trạng thái mới nhất đúng ngữ cảnh | `backend/tests/test_bookings.py::test_does_not_surface_older_expired_booking_when_latest_booking_is_cancelled` |
| BOOK-06 | Cancel booking nhiều lần | Chỉ restore capacity đúng 1 lần | UI vẫn nhất quán, không tăng capacity ảo | `backend/tests/test_bookings.py::test_cancel_booking_restores_capacity_exactly_once` |

## 4. QR parking loop: check-in, preview, finalize, undo

| Case ID | Tình huống | Kỳ vọng backend | Kỳ vọng UI / hệ thống | Chứng cứ hiện có |
|---|---|---|---|---|
| QR-01 | Driver xin check-in QR cho xe của chính mình | Phát hành backend-signed token có TTL | Mobile render QR, chưa tạo session | `backend/tests/test_driver_check_in_qr.py::test_issues_backend_signed_token_for_owned_vehicle` |
| QR-02 | Driver dùng vehicle không thuộc mình | Từ chối tạo token | UI báo không hợp lệ | `backend/tests/test_driver_check_in_qr.py::test_rejects_vehicle_that_belongs_to_another_driver` |
| QR-03 | Driver đã có active session mà vẫn xin QR check-in mới | Từ chối | UI phải chuyển sang trạng thái active session thay vì cấp QR mới | `backend/tests/test_driver_check_in_qr.py::test_rejects_when_driver_has_active_session` |
| QR-04 | Attendant check-in QR hợp lệ | Tạo `parking_session`, giảm `current_available`, publish availability event | UI attendant hiện kết quả check-in thành công | `backend/tests/test_attendant_check_in.py::test_creates_session_and_updates_availability` |
| QR-05 | Token malformed hoặc account không phải attendant | Từ chối check-in | UI attendant hiện lỗi scan/quyền | `backend/tests/test_attendant_check_in.py::test_rejects_malformed_token`, `backend/tests/test_attendant_check_in.py::test_rejects_non_attendant_account` |
| QR-06 | Preview checkout cho session hợp lệ | Chỉ trả tiền dự kiến, không mutate session/payment | UI cho người dùng xem phí trước khi xác nhận | `backend/tests/test_attendant_check_out_preview.py::test_returns_checkout_preview_without_mutating_state` |
| QR-07 | Preview checkout khi khác lot, thiếu pricing, session đã đóng hoặc không còn active session | Từ chối đúng lỗi nghiệp vụ | UI báo lỗi thay vì cho finalize | `backend/tests/test_attendant_check_out_preview.py::test_rejects_when_session_belongs_to_different_lot`, `backend/tests/test_attendant_check_out_preview.py::test_rejects_when_active_pricing_is_missing`, `backend/tests/test_attendant_check_out_preview.py::test_rejects_when_session_already_checked_out`, `backend/tests/test_attendant_check_out_preview.py::test_rejects_when_no_active_session_exists` |
| QR-08 | Finalize checkout hợp lệ | Tạo payment, đóng session, tăng capacity atomically | UI xác nhận thanh toán thành công | `backend/tests/test_attendant_check_out_finalize.py::test_finalizes_checkout_and_creates_payment_atomically` |
| QR-09 | Double finalize hoặc preview cũ không còn khớp | Từ chối để tránh sai tiền/sai trạng thái | UI buộc refresh preview hoặc dừng thao tác | `backend/tests/test_attendant_check_out_finalize.py::test_rejects_duplicate_finalization_when_completed_payment_exists`, `backend/tests/test_attendant_check_out_finalize.py::test_rejects_stale_preview_when_authoritative_fee_changes` |
| QR-10 | Lỗi commit khi finalize | Rollback local mutations | UI không được hiển thị checkout thành công giả | `backend/tests/test_attendant_check_out_finalize.py::test_rolls_back_local_mutations_when_commit_fails` |
| QR-11 | Undo trong recovery window | Reopen session và đảo trạng thái phù hợp | UI cho phép hoàn tác ngắn hạn | `backend/tests/test_attendant_check_out_finalize.py::test_undo_reopens_recent_checkout_within_recovery_window` |
| QR-12 | Undo sau khi quá recovery window | Từ chối undo | UI phải báo hết thời gian hoàn tác | `backend/tests/test_attendant_check_out_finalize.py::test_rejects_undo_after_recovery_window_expires` |

## 5. Walk-in check-in flow

| Case ID | Tình huống | Kỳ vọng backend | Kỳ vọng UI / hệ thống | Chứng cứ hiện có |
|---|---|---|---|---|
| WALK-01 | Walk-in check-in hợp lệ | Tạo session walk-in và giảm availability | UI attendant reset về standby sau khi tạo thành công | `backend/tests/test_walk_in_check_in.py::test_creates_walk_in_session_and_updates_availability` |
| WALK-02 | Không có plate photo | Từ chối request | UI phải bắt buộc có ảnh | `backend/tests/test_walk_in_check_in.py::test_rejects_missing_plate_photo` |
| WALK-03 | Upload không phải image | Từ chối request | UI phải chặn hoặc báo file không hợp lệ | `backend/tests/test_walk_in_check_in.py::test_rejects_non_image_upload` |
| WALK-04 | Lot đầy | Từ chối tạo session | UI báo bãi đã đầy | `backend/tests/test_walk_in_check_in.py::test_rejects_when_lot_is_full` |
| WALK-05 | User không phải attendant | Từ chối thao tác | Flow walk-in chỉ mở cho workspace attendant | `backend/tests/test_walk_in_check_in.py::test_rejects_non_attendant_account` |

## 6. Shift handover và final close-out

| Case ID | Tình huống | Kỳ vọng backend | Kỳ vọng UI / hệ thống | Chứng cứ hiện có |
|---|---|---|---|---|
| SHIFT-01 | Chuẩn bị bàn giao ca khi có ca đang mở | Tính expected cash và tạo payload/QR bàn giao | UI attendant ca trước nhận QR handover | `backend/tests/test_shift_handover.py::test_prepares_qr_payload_from_open_shift_cash_total` |
| SHIFT-02 | Không có active shift mà vẫn bàn giao | Từ chối | UI không cho khởi tạo handover | `backend/tests/test_shift_handover.py::test_rejects_handover_without_active_shift` |
| SHIFT-03 | Tiền kiểm kê lệch mà không có lý do | Chặn hoàn tất bàn giao | UI bắt buộc nhập discrepancy reason | `backend/tests/test_shift_handover.py::test_blocks_mismatch_without_reason` |
| SHIFT-04 | Tiền lệch nhưng có lý do | Khóa ca và tạo alert cho operator | UI/operator thấy thông báo để xử lý | `backend/tests/test_shift_handover.py::test_locks_shift_and_creates_operator_alert_on_discrepancy` |
| SHIFT-05 | Incoming attendant đang có pending shift hoặc token handover hết hạn | Từ chối bàn giao | UI báo không thể tiếp nhận ca | `backend/tests/test_shift_handover.py::test_rejects_incoming_attendant_with_pending_shift`, `backend/tests/test_shift_handover.py::test_rejects_expired_shift_handover_token` |
| SHIFT-06 | Đóng ngày khi bãi đã hết xe | Tạo close-out request hợp lệ | UI gửi yêu cầu close-out để operator confirm | `backend/tests/test_shift_close_out.py::test_requests_final_close_out_when_lot_is_empty` |
| SHIFT-07 | Còn active sessions mà đòi close-out | Chặn close-out | UI báo phải xử lý hết session trước | `backend/tests/test_shift_close_out.py::test_blocks_final_close_out_when_active_sessions_remain` |
| SHIFT-08 | Operator hoàn tất close-out yêu cầu trước đó | Đánh dấu close-out hoàn thành | UI/operator xác nhận đóng ngày xong | `backend/tests/test_shift_close_out.py::test_operator_completes_requested_close_out` |
| SHIFT-09 | Close-out đang pending mà attendant vẫn cố check-in xe mới | Chặn check-in | UI attendant phải bị block cho tới khi close-out xong | `backend/tests/test_shift_close_out.py::test_blocks_attendant_check_in_while_close_out_is_pending` |

## Coverage gaps nên giữ rõ trong tài liệu kiểm thử

| Gap | Ý nghĩa |
|---|---|
| Walk-in check-out end-to-end | Chưa có đường đi rõ như QR flow, không nên viết test expectation như thể đã chốt |
| Offline sync của attendant | Chưa có backend/mobile flow hoàn chỉnh |
| User management đầy đủ ở admin mobile shell | Chưa phải khu vực coverage mạnh của UI hiện tại |
| Lot Owner contracts/profile UI | Có nghiệp vụ nhưng chưa đủ bằng chứng UI flow hoàn chỉnh |
| Online payment UX cuối cùng | Backend có `ONLINE`, nhưng trải nghiệm mobile đầy đủ vẫn nên coi là đang tối giản cho MVP/demo |