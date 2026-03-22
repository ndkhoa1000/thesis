@startuml
left to right direction
skinparam packageStyle rectangle
skinparam shadowing false

skinparam usecase {
    BackgroundColor White
    BorderColor DarkSlateGray
}

actor "Tài xế" as Driver
actor "Nhân viên giữ xe" as Attendant
actor "Quản lý bãi xe" as Operator
actor "Chủ cho thuê bãi xe" as LotOwner
actor "Admin hệ thống" as Admin

rectangle "Hệ thống Quản lý Bãi xe Thông minh" {

    package "Ứng dụng Tài xế" {
        usecase "Tìm & xem bãi xe trên bản đồ" as UC01
        usecase "Đặt chỗ trước" as UC02
        usecase "Mua vé tháng/tuần" as UC03
        usecase "Gửi xe (QR check-in)" as UC04
        usecase "Lấy xe (QR check-out)" as UC05
        usecase "Thanh toán" as UC06
        usecase "Thanh toán Online" as UC07
        usecase "Xem lịch sử gửi xe" as UC08
    }

    package "Ứng dụng Nhân viên" {
        usecase "Quét mã Vào" as UC09
        usecase "Quét mã Ra" as UC10
        usecase "Quét bằng thẻ NFC" as UC11
        usecase "Quét bằng mã QR" as UC12
        usecase "Chụp hình & ghi thông tin lần gửi" as UC13
        usecase "Thu tiền" as UC14
        usecase "Ghi nhận thanh toán tiền mặt" as UC15
        usecase "Thanh toán online cho khách" as UC16
        usecase "Xem thống kê xe trong bãi" as UC17
        usecase "Chỉnh sửa thông tin lần gửi xe" as UC18
    }

    package "Portal Quản lý Bãi xe" {
        usecase "Đăng ký thuê bãi xe" as UC19
        usecase "Cấu hình thông tin cố định bãi xe" as UC20
        usecase "Cấu hình thông tin tạm thời bãi xe" as UC21
        usecase "Đăng thông báo / sự kiện bãi xe" as UC22
        usecase "Xem báo cáo doanh thu" as UC23
    }

    package "Portal Chủ Cho Thuê Bãi Xe" {
        usecase "Đăng ký bãi xe sở hữu" as UC24
        usecase "Rao cho thuê bãi xe" as UC25
        usecase "Quản lý hợp đồng cho thuê" as UC26
    }

    package "Portal Admin" {
        usecase "Duyệt đăng ký bãi xe" as UC27
        usecase "Duyệt yêu cầu thuê bãi xe" as UC28
        usecase "Quản lý bãi xe" as UC29
        usecase "Quản lý người dùng" as UC30
        usecase "In hoá đơn khách hàng" as UC31
    }

    ' --- TÀI XẾ ---
    Driver -- UC01
    Driver -- UC04
    Driver -- UC05
    Driver -- UC08

    UC01 <.. UC02 : <<extend>>
    UC01 <.. UC03 : <<extend>>
    UC02 ..> UC07 : <<include>>
    UC03 ..> UC07 : <<include>>
    UC05 ..> UC06 : <<include>>
    UC06 <.. UC07 : <<extend>>

    ' --- NHÂN VIÊN ---
    Attendant -- UC09
    Attendant -- UC10
    Attendant -- UC14
    Attendant -- UC17
    Attendant -- UC18

    UC09 <.. UC11 : <<extend>>
    UC09 <.. UC12 : <<extend>>
    UC09 ..> UC13 : <<include>>
    UC10 <.. UC11 : <<extend>>
    UC10 <.. UC12 : <<extend>>
    UC10 ..> UC14 : <<include>>
    UC14 <.. UC15 : <<extend>>
    UC14 <.. UC16 : <<extend>>

    ' --- QUẢN LÝ BÃI XE ---
    Operator -- UC19
    Operator -- UC20
    Operator -- UC21
    Operator -- UC22
    Operator -- UC23

    UC19 ..> UC27 : <<include>>

    ' --- CHỦ CHO THUÊ BÃI XE ---
    LotOwner -- UC24
    LotOwner -- UC25
    LotOwner -- UC26

    UC24 ..> UC27 : <<include>>
    UC25 ..> UC28 : <<include>>

    ' --- ADMIN ---
    Admin -- UC27
    Admin -- UC28
    Admin -- UC29
    Admin -- UC30
    Admin -- UC31
}
@enduml