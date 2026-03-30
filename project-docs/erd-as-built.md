# ERD As-Built Của Ứng Dụng

## Mục tiêu

ERD này bám theo SQLAlchemy models hiện có trong backend. Nó không lặp lại toàn bộ bảng generic của boilerplate như `post`, `tier`, `rate_limit`, mà tập trung vào schema domain của smart parking.

## Cách đọc

- Phần 1 là ERD lõi cho các flow đang chi phối mobile app hiện tại.
- Phần 2 là ERD mở rộng cho subscription, notification, invoice và shift operations đã có schema.
- Nếu planning docs khác code, ưu tiên code hiện tại là nguồn chuẩn của tài liệu này.

## ERD lõi

```mermaid
erDiagram
  USER {
    int id PK
    string email
    string username
    string role
    boolean is_active
  }

  DRIVER {
    int id PK
    int user_id FK
    decimal wallet_balance
  }

  LOT_OWNER {
    int id PK
    int user_id FK
    string business_license
    datetime verified_at
  }

  LOT_OWNER_APPLICATION {
    int id PK
    int user_id FK
    string full_name
    string phone_number
    string business_license
    string document_reference
    string status
  }

  MANAGER {
    int id PK
    int user_id FK
    string business_license
    datetime verified_at
  }

  OPERATOR_APPLICATION {
    int id PK
    int user_id FK
    string full_name
    string phone_number
    string business_license
    string document_reference
    string status
  }

  ATTENDANT {
    int id PK
    int user_id FK
    int parking_lot_id FK
    date hired_at
  }

  VEHICLE {
    int id PK
    int driver_id FK
    string license_plate
    string vehicle_type
    boolean is_verified
  }

  PARKING_LOT {
    int id PK
    int lot_owner_id FK
    string name
    string address
    decimal latitude
    decimal longitude
    int current_available
    string status
  }

  PARKING_LOT_CONFIG {
    int id PK
    int parking_lot_id FK
    int set_by FK
    int total_capacity
    string vehicle_type
    time opening_time
    time closing_time
  }

  PRICING {
    int id PK
    int parking_lot_id FK
    decimal price_amount
    string vehicle_type
    string pricing_mode
  }

  SLOT {
    int id PK
    int parking_lot_id FK
    string slot_code
    string slot_type
    boolean is_occupied
  }

  BOOKING {
    int id PK
    int driver_id FK
    int parking_lot_id FK
    int vehicle_id FK
    int slot_id FK
    string status
    datetime expiration_time
  }

  PARKING_SESSION {
    int id PK
    int parking_lot_id FK
    int driver_id FK
    int slot_id FK
    int booking_id FK
    int subscription_id FK
    int attendant_checkin_id FK
    int attendant_checkout_id FK
    string license_plate
    string vehicle_type
    string status
  }

  SESSION_EDIT {
    int id PK
    int session_id FK
    int edited_by FK
    string field_changed
    string reason
  }

  LOT_LEASE {
    int id PK
    int parking_lot_id FK
    int manager_id FK
    decimal monthly_fee
    decimal revenue_share_percentage
    int term_months
    string status
  }

  LEASE_CONTRACT {
    int id PK
    int lease_id FK
    string contract_number
    int generated_by FK
    string status
  }

  PAYMENT {
    int id PK
    int payable_id
    int driver_id FK
    decimal amount
    decimal final_amount
    string payable_type
    string payment_method
    string payment_status
  }

  PARKING_LOT_ANNOUNCEMENT {
    int id PK
    int parking_lot_id FK
    int posted_by FK
    string title
    string announcement_type
  }

  USER ||--o| DRIVER : "public account of"
  USER ||--o| LOT_OWNER : "approved capability"
  USER ||--o| MANAGER : "approved capability"
  USER ||--o| ATTENDANT : "separate attendant account"
  USER ||--o{ LOT_OWNER_APPLICATION : submits
  USER ||--o{ OPERATOR_APPLICATION : submits

  DRIVER ||--o{ VEHICLE : owns
  DRIVER ||--o{ BOOKING : creates
  DRIVER ||--o{ PARKING_SESSION : may_have
  DRIVER ||--o{ PAYMENT : pays

  LOT_OWNER ||--o{ PARKING_LOT : registers
  MANAGER ||--o{ LOT_LEASE : leases
  MANAGER ||--o{ PARKING_LOT_CONFIG : configures
  MANAGER ||--o{ PARKING_LOT_ANNOUNCEMENT : posts

  PARKING_LOT ||--o{ PARKING_LOT_CONFIG : has
  PARKING_LOT ||--o{ PRICING : has
  PARKING_LOT ||--o{ SLOT : contains
  PARKING_LOT ||--o{ BOOKING : receives
  PARKING_LOT ||--o{ PARKING_SESSION : hosts
  PARKING_LOT ||--o{ LOT_LEASE : offered_in
  PARKING_LOT ||--o{ PARKING_LOT_ANNOUNCEMENT : publishes

  ATTENDANT ||--o{ PARKING_SESSION : checks_in_or_out
  ATTENDANT ||--o{ SESSION_EDIT : edits
  ATTENDANT }o--|| PARKING_LOT : assigned_to

  VEHICLE ||--o{ BOOKING : reserved_by
  SLOT ||--o{ BOOKING : optional_slot
  SLOT ||--o{ PARKING_SESSION : optional_slot

  BOOKING o|--o| PARKING_SESSION : consumed_into
  BOOKING }o--|| PAYMENT : booking_payment

  PARKING_SESSION ||--o{ SESSION_EDIT : audited_by
  PARKING_SESSION }o--|| PAYMENT : session_payment

  LOT_LEASE ||--|| LEASE_CONTRACT : generates
```

## ERD mở rộng

```mermaid
erDiagram
  SUBSCRIPTION {
    int id PK
    int driver_id FK
    int vehicle_id FK
    decimal price
    string subscription_type
    string status
  }

  SUBSCRIPTION_LOT {
    int id PK
    int subscription_id FK
    int parking_lot_id FK
  }

  INVOICE {
    int id PK
    int payment_id FK
    string invoice_number
    int issued_by FK
    int print_count
  }

  NOTIFICATION {
    int id PK
    int user_id FK
    int sender_id FK
    string notification_type
    string reference_type
    int reference_id
    boolean is_read
  }

  SHIFT {
    int id PK
    int parking_lot_id FK
    int attendant_id FK
    string status
    datetime started_at
    datetime ended_at
  }

  SHIFT_HANDOVER {
    int id PK
    int outgoing_shift_id FK
    int incoming_shift_id FK
    int incoming_attendant_id FK
    decimal expected_cash
    decimal actual_cash
  }

  SHIFT_CLOSE_OUT {
    int id PK
    int shift_id FK
    int parking_lot_id FK
    int attendant_id FK
    decimal expected_cash
    string status
  }

  DRIVER ||--o{ SUBSCRIPTION : purchases
  VEHICLE ||--o{ SUBSCRIPTION : optional_vehicle_scope
  SUBSCRIPTION ||--o{ SUBSCRIPTION_LOT : applies_to
  PARKING_LOT ||--o{ SUBSCRIPTION_LOT : accepts
  SUBSCRIPTION o|--o{ PARKING_SESSION : may_cover
  SUBSCRIPTION }o--|| PAYMENT : subscription_payment

  PAYMENT ||--o| INVOICE : may_issue

  USER ||--o{ NOTIFICATION : receives
  USER ||--o{ INVOICE : issues

  ATTENDANT ||--o{ SHIFT : works
  SHIFT ||--o| SHIFT_HANDOVER : outgoing
  SHIFT ||--o| SHIFT_CLOSE_OUT : closes
  ATTENDANT ||--o{ SHIFT_HANDOVER : incoming_actor
  PARKING_LOT ||--o{ SHIFT : operates
  PARKING_LOT ||--o{ SHIFT_CLOSE_OUT : close_out_context
  NOTIFICATION ||--o{ SHIFT_HANDOVER : operator_alert
  NOTIFICATION ||--o{ SHIFT_CLOSE_OUT : operator_alert
```

## Điểm khác với ERD cũ cần lưu ý

| Chủ đề | ERD cũ | As-built hiện tại |
|---|---|---|
| `ParkingLot.status` | Thường được diễn giải như `ACTIVE/SUSPENDED` ở doc nghiệp vụ | Enum model hiện tại là `PENDING`, `APPROVED`, `REJECTED`, `CLOSED` |
| `Booking.status` | Một số doc chỉ nêu `PENDING/CONFIRMED/EXPIRED` | Model hiện tại có `PENDING`, `CONFIRMED`, `CONSUMED`, `EXPIRED`, `CANCELLED` |
| `ParkingSession.status` | Tài liệu cũ có `CHECKED_IN/CHECKED_OUT` | Model hiện tại là `CHECKED_IN`, `CHECKED_OUT`, `TIMEOUT` |
| `PaymentMethod` | Tài liệu cũ mở rộng nhiều kiểu | Model hiện tại chỉ là `CASH` và `ONLINE` |
| Subscription | Bị xem là Phase 2 trong workflow docs | Schema đã có bảng `subscription` và `subscription_lot`, nhưng mobile MVP chưa dùng mạnh |
| Shift close-out | Chưa luôn xuất hiện trong ERD cũ | Schema và test backend đã có đủ `shift`, `shift_handover`, `shift_close_out` |

## Kết luận ngắn

- Nếu cần mô tả database đang tồn tại trong backend, hãy dùng ERD as-built này.
- Nếu cần mô tả phạm vi thesis demo hiện tại, hãy đọc thêm [workflow-truth-map](_bmad-output/planning-artifacts/workflow-truth-map.md) song song với ERD này để tách rõ phần có schema và phần thực sự được đưa vào flow chính.