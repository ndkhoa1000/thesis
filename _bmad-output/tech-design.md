# Tech Design — Smart Parking Management System

**Author:** Khoa
**Date:** 2026-03-20
**Based on:** [PRD](file:///d:/Code/thesis/_bmad-output/prd.md) · [Architecture](file:///d:/Code/thesis/_bmad-output/architecture.md) · [ERD](file:///d:/Code/thesis/doc/erd.md)

---

## 1. Database Migration

Use Supabase CLI: `supabase migration new init_schema`

### 1.1 Enums

```sql
-- Custom ENUM types
CREATE TYPE user_role AS ENUM ('DRIVER', 'ATTENDANT', 'MANAGER', 'LOT_OWNER', 'ADMIN');
CREATE TYPE vehicle_type AS ENUM ('MOTORBIKE', 'CAR');
CREATE TYPE vehicle_type_ext AS ENUM ('MOTORBIKE', 'CAR', 'ALL');
CREATE TYPE lot_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CLOSED');
CREATE TYPE feature_type AS ENUM ('CAMERA', 'IOT', 'SLOT_MANAGEMENT', 'BARRIER');
CREATE TYPE slot_type AS ENUM ('STANDARD', 'VIP', 'DISABLED');
CREATE TYPE pricing_mode AS ENUM ('SESSION', 'HOURLY', 'DAILY', 'MONTHLY', 'CUSTOM');
CREATE TYPE subscription_type AS ENUM ('WEEKLY', 'MONTHLY');
CREATE TYPE subscription_status AS ENUM ('ACTIVE', 'EXPIRED', 'CANCELLED');
CREATE TYPE booking_status AS ENUM ('PENDING', 'CONFIRMED', 'EXPIRED', 'CANCELLED', 'USED');
CREATE TYPE session_status AS ENUM ('CHECKED_IN', 'CHECKED_OUT');
CREATE TYPE payable_type AS ENUM ('SESSION', 'SUBSCRIPTION', 'BOOKING');
CREATE TYPE payment_method AS ENUM ('CASH', 'ONLINE');
CREATE TYPE payment_status AS ENUM ('PENDING', 'COMPLETED', 'FAILED');
CREATE TYPE lease_status AS ENUM ('PENDING', 'ACTIVE', 'EXPIRED', 'TERMINATED');
CREATE TYPE contract_status AS ENUM ('DRAFT', 'ACTIVE', 'EXPIRED');
CREATE TYPE announcement_type AS ENUM ('EVENT', 'TRAFFIC_ALERT', 'PEAK_HOURS', 'CLOSURE', 'GENERAL');
CREATE TYPE notification_type AS ENUM ('BOOKING_EXPIRING', 'SUBSCRIPTION_EXPIRING', 'PAYMENT_SUCCESS', 'LOT_CLOSING', 'SYSTEM_ALERT');
CREATE TYPE reference_type AS ENUM ('BOOKING', 'SESSION', 'SUBSCRIPTION', 'LOT');
```

### 1.2 Tables

```sql
-- 1. User (extends Supabase auth.users)
CREATE TABLE "user" (
  user_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  auth_uid      UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  username      VARCHAR(50),
  email         VARCHAR(100) UNIQUE NOT NULL,
  phone         VARCHAR(15),
  avatar        VARCHAR(255),
  role          user_role NOT NULL DEFAULT 'DRIVER',
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Driver
CREATE TABLE driver (
  driver_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       INT UNIQUE NOT NULL REFERENCES "user"(user_id) ON DELETE CASCADE,
  wallet_balance DECIMAL(12,2) NOT NULL DEFAULT 0.00
);

-- 3. LotOwner
CREATE TABLE lot_owner (
  lot_owner_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       INT UNIQUE NOT NULL REFERENCES "user"(user_id) ON DELETE CASCADE,
  business_license VARCHAR(100),
  verified_at   TIMESTAMPTZ
);

-- 4. Manager (= Operator in product terms)
CREATE TABLE manager (
  manager_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       INT UNIQUE NOT NULL REFERENCES "user"(user_id) ON DELETE CASCADE,
  business_license VARCHAR(100),
  verified_at   TIMESTAMPTZ
);

-- 5. Attendant
CREATE TABLE attendant (
  attendant_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       INT UNIQUE NOT NULL REFERENCES "user"(user_id) ON DELETE CASCADE,
  parking_lot_id INT NOT NULL, -- FK added after parking_lot table
  hired_at      DATE NOT NULL DEFAULT CURRENT_DATE
);

-- 6. Vehicle
CREATE TABLE vehicle (
  vehicle_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  driver_id     INT NOT NULL REFERENCES driver(driver_id) ON DELETE CASCADE,
  license_plate VARCHAR(15) UNIQUE NOT NULL,
  vehicle_type  vehicle_type NOT NULL,
  brand         VARCHAR(50),
  color         VARCHAR(20),
  front_image   VARCHAR(255),
  back_image    VARCHAR(255),
  is_verified   BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. ParkingLot
CREATE TABLE parking_lot (
  parking_lot_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lot_owner_id   INT NOT NULL REFERENCES lot_owner(lot_owner_id),
  name           VARCHAR(100) NOT NULL,
  address        VARCHAR(255) NOT NULL,
  latitude       DECIMAL(10,8) NOT NULL,
  longitude      DECIMAL(11,8) NOT NULL,
  current_available INT NOT NULL DEFAULT 0,
  status         lot_status NOT NULL DEFAULT 'PENDING',
  description    TEXT,
  cover_image    VARCHAR(255),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add FK for attendant → parking_lot
ALTER TABLE attendant
  ADD CONSTRAINT fk_attendant_lot FOREIGN KEY (parking_lot_id)
  REFERENCES parking_lot(parking_lot_id);

-- 8. ParkingLotConfig
CREATE TABLE parking_lot_config (
  config_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parking_lot_id INT NOT NULL REFERENCES parking_lot(parking_lot_id),
  set_by         INT NOT NULL REFERENCES manager(manager_id),
  vehicle_type   vehicle_type_ext NOT NULL DEFAULT 'ALL',
  total_capacity INT NOT NULL,
  opening_time   TIME NOT NULL,
  closing_time   TIME NOT NULL,
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to   DATE, -- NULL = currently active
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. LotLease
CREATE TABLE lot_lease (
  lease_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parking_lot_id INT NOT NULL REFERENCES parking_lot(parking_lot_id),
  manager_id     INT NOT NULL REFERENCES manager(manager_id),
  start_date     DATE NOT NULL,
  end_date       DATE NOT NULL,
  monthly_fee    DECIMAL(12,2) NOT NULL,
  status         lease_status NOT NULL DEFAULT 'PENDING',
  contract_file  VARCHAR(255),
  approved_by    INT REFERENCES "user"(user_id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 23. LeaseContract
CREATE TABLE lease_contract (
  contract_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lease_id       INT UNIQUE NOT NULL REFERENCES lot_lease(lease_id),
  contract_number VARCHAR(20) UNIQUE NOT NULL,
  content        TEXT NOT NULL,
  generated_by   INT NOT NULL REFERENCES "user"(user_id),
  generated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  status         contract_status NOT NULL DEFAULT 'DRAFT'
);

-- 10. ParkingLotFeature
CREATE TABLE parking_lot_feature (
  feature_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parking_lot_id INT NOT NULL REFERENCES parking_lot(parking_lot_id) ON DELETE CASCADE,
  feature_type   feature_type NOT NULL,
  config_data    JSONB DEFAULT '{}',
  enabled        BOOLEAN NOT NULL DEFAULT true
);

-- 11. ParkingLotTag
CREATE TABLE parking_lot_tag (
  tag_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parking_lot_id INT NOT NULL REFERENCES parking_lot(parking_lot_id) ON DELETE CASCADE,
  tag_name       VARCHAR(50) NOT NULL
);

-- 12. Slot (IoT / future scope — included for schema completeness)
CREATE TABLE slot (
  slot_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parking_lot_id INT NOT NULL REFERENCES parking_lot(parking_lot_id),
  slot_code      VARCHAR(10) NOT NULL,
  slot_type      slot_type NOT NULL DEFAULT 'STANDARD',
  is_occupied    BOOLEAN NOT NULL DEFAULT false,
  sensor_id      VARCHAR(50),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(parking_lot_id, slot_code)
);

-- 13. Pricing
CREATE TABLE pricing (
  pricing_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parking_lot_id INT NOT NULL REFERENCES parking_lot(parking_lot_id),
  vehicle_type   vehicle_type_ext NOT NULL DEFAULT 'ALL',
  pricing_mode   pricing_mode NOT NULL DEFAULT 'HOURLY',
  price_amount   DECIMAL(10,2) NOT NULL,
  note           VARCHAR(100),
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to   DATE -- NULL = currently active
);

-- 14. Subscription (Phase 2 — schema included)
CREATE TABLE subscription (
  subscription_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  driver_id       INT NOT NULL REFERENCES driver(driver_id),
  vehicle_id      INT REFERENCES vehicle(vehicle_id),
  vehicle_type    vehicle_type NOT NULL,
  subscription_type subscription_type NOT NULL,
  start_date      DATE NOT NULL,
  end_date        DATE NOT NULL,
  price           DECIMAL(10,2) NOT NULL,
  status          subscription_status NOT NULL DEFAULT 'ACTIVE',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 15. SubscriptionLot
CREATE TABLE subscription_lot (
  subscription_lot_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  subscription_id INT NOT NULL REFERENCES subscription(subscription_id) ON DELETE CASCADE,
  parking_lot_id  INT NOT NULL REFERENCES parking_lot(parking_lot_id),
  UNIQUE(subscription_id, parking_lot_id)
);

-- 16. Booking
CREATE TABLE booking (
  booking_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  driver_id      INT NOT NULL REFERENCES driver(driver_id),
  parking_lot_id INT NOT NULL REFERENCES parking_lot(parking_lot_id),
  slot_id        INT REFERENCES slot(slot_id),
  vehicle_id     INT NOT NULL REFERENCES vehicle(vehicle_id),
  booking_time   TIMESTAMPTZ NOT NULL DEFAULT now(),
  expected_arrival TIMESTAMPTZ NOT NULL,
  expiration_time TIMESTAMPTZ NOT NULL,
  status         booking_status NOT NULL DEFAULT 'CONFIRMED',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 17. ParkingSession
CREATE TABLE parking_session (
  session_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parking_lot_id INT NOT NULL REFERENCES parking_lot(parking_lot_id),
  driver_id      INT REFERENCES driver(driver_id),         -- NULL for walk-ins
  slot_id        INT REFERENCES slot(slot_id),
  booking_id     INT REFERENCES booking(booking_id),
  subscription_id INT REFERENCES subscription(subscription_id),
  attendant_checkin_id  INT REFERENCES attendant(attendant_id),
  attendant_checkout_id INT REFERENCES attendant(attendant_id),
  license_plate  VARCHAR(15),                              -- NULL for walk-ins (photo only)
  vehicle_type   vehicle_type NOT NULL,
  checkin_time   TIMESTAMPTZ NOT NULL DEFAULT now(),
  checkout_time  TIMESTAMPTZ,
  checkin_image  VARCHAR(255),
  checkout_image VARCHAR(255),
  qr_code        VARCHAR(100) UNIQUE NOT NULL,
  nfc_card_id    VARCHAR(50),
  status         session_status NOT NULL DEFAULT 'CHECKED_IN',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 18. SessionEdit
CREATE TABLE session_edit (
  edit_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id     INT NOT NULL REFERENCES parking_session(session_id),
  edited_by      INT NOT NULL REFERENCES attendant(attendant_id),
  field_changed  VARCHAR(50) NOT NULL,
  old_value      VARCHAR(255),
  new_value      VARCHAR(255),
  reason         VARCHAR(255) NOT NULL,
  edited_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 19. Payment
CREATE TABLE payment (
  payment_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payable_type   payable_type NOT NULL,
  payable_id     INT NOT NULL,
  driver_id      INT REFERENCES driver(driver_id),
  amount         DECIMAL(12,2) NOT NULL,
  discount       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  final_amount   DECIMAL(12,2) NOT NULL,
  payment_method payment_method NOT NULL,
  payment_status payment_status NOT NULL DEFAULT 'PENDING',
  processed_by   INT REFERENCES "user"(user_id),
  note           VARCHAR(255),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 20. Invoice
CREATE TABLE invoice (
  invoice_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payment_id     INT UNIQUE NOT NULL REFERENCES payment(payment_id),
  invoice_number VARCHAR(20) UNIQUE NOT NULL,
  issued_by      INT NOT NULL REFERENCES "user"(user_id),
  issued_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  print_count    INT NOT NULL DEFAULT 0
);

-- 21. ParkingLotAnnouncement
CREATE TABLE parking_lot_announcement (
  announcement_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parking_lot_id  INT NOT NULL REFERENCES parking_lot(parking_lot_id) ON DELETE CASCADE,
  posted_by       INT NOT NULL REFERENCES manager(manager_id),
  title           VARCHAR(100) NOT NULL,
  content         TEXT NOT NULL,
  announcement_type announcement_type NOT NULL DEFAULT 'GENERAL',
  visible_from    TIMESTAMPTZ NOT NULL DEFAULT now(),
  visible_until   TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 22. Notification
CREATE TABLE notification (
  notification_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id         INT NOT NULL REFERENCES "user"(user_id),
  sender_id       INT REFERENCES "user"(user_id),
  title           VARCHAR(100) NOT NULL,
  message         TEXT NOT NULL,
  notification_type notification_type NOT NULL,
  reference_type  reference_type,
  reference_id    INT,
  is_read         BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 1.3 Functions

```sql
-- Atomic availability adjustment (prevents negative values)
CREATE OR REPLACE FUNCTION adjust_available(p_lot_id INT, p_delta INT)
RETURNS VOID AS $$
BEGIN
  UPDATE parking_lot
  SET current_available = GREATEST(0, current_available + p_delta),
      updated_at = NOW()
  WHERE parking_lot_id = p_lot_id;
END;
$$ LANGUAGE plpgsql;

-- Auto-update updated_at on user table
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to sync auth.users to public.user automatically
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user (auth_uid, email, role, is_active)
  VALUES (new.id, new.email, 'DRIVER', true);
  RETURN new;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

CREATE TRIGGER trg_user_updated_at BEFORE UPDATE ON "user"
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_lot_updated_at BEFORE UPDATE ON parking_lot
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
```

### 1.4 Indexes

```sql
CREATE INDEX idx_lot_status ON parking_lot(status);
CREATE INDEX idx_lot_location ON parking_lot(latitude, longitude);
CREATE INDEX idx_session_lot ON parking_session(parking_lot_id, status);
CREATE INDEX idx_session_driver ON parking_session(driver_id, status);
CREATE INDEX idx_session_qr ON parking_session(qr_code);
CREATE INDEX idx_booking_driver ON booking(driver_id, status);
CREATE INDEX idx_booking_lot ON booking(parking_lot_id, status);
CREATE INDEX idx_booking_expiration ON booking(expiration_time) WHERE status = 'CONFIRMED';
CREATE INDEX idx_pricing_active ON pricing(parking_lot_id, vehicle_type)
  WHERE effective_to IS NULL;
CREATE INDEX idx_config_active ON parking_lot_config(parking_lot_id)
  WHERE effective_to IS NULL;
```

### 1.5 Booking Expiration (pg_cron)

```sql
-- Enable pg_cron (Supabase has it pre-installed)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Expire bookings every minute
SELECT cron.schedule(
  'expire-stale-bookings',
  '* * * * *', -- every minute
  $$
    WITH expired AS (
      UPDATE booking
      SET status = 'EXPIRED'
      WHERE status = 'CONFIRMED'
        AND expiration_time < now()
      RETURNING parking_lot_id
    )
    SELECT adjust_available(parking_lot_id, 1) FROM expired;
  $$
);
```

---

## 2. RLS Policies

Enable RLS on all tables, then apply policies. FastAPI uses **service key** (bypasses RLS). These protect against direct DB access.

```sql
-- Enable RLS on all tables
ALTER TABLE "user" ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver ENABLE ROW LEVEL SECURITY;
ALTER TABLE lot_owner ENABLE ROW LEVEL SECURITY;
ALTER TABLE manager ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendant ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_lot ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_lot_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE lot_lease ENABLE ROW LEVEL SECURITY;
ALTER TABLE lease_contract ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_lot_feature ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_lot_tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE slot ENABLE ROW LEVEL SECURITY;
ALTER TABLE pricing ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_lot ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_session ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_edit ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_lot_announcement ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification ENABLE ROW LEVEL SECURITY;

-- === USER ===
CREATE POLICY "users_read_own" ON "user"
  FOR SELECT USING (auth_uid = auth.uid());
CREATE POLICY "users_update_own" ON "user"
  FOR UPDATE USING (auth_uid = auth.uid());

-- === DRIVER / LOT_OWNER / MANAGER ===
CREATE POLICY "driver_read_own" ON driver
  FOR SELECT USING (user_id = (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()));
CREATE POLICY "lot_owner_read_own" ON lot_owner
  FOR SELECT USING (user_id = (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()));
CREATE POLICY "manager_read_own" ON manager
  FOR SELECT USING (user_id = (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()));

-- === VEHICLE ===
CREATE POLICY "vehicle_driver_crud" ON vehicle
  FOR ALL USING (
    driver_id = (SELECT driver_id FROM driver WHERE user_id =
      (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()))
  );

-- === PARKING LOT ===
CREATE POLICY "lot_public_read" ON parking_lot
  FOR SELECT USING (status = 'APPROVED');
CREATE POLICY "lot_owner_manage" ON parking_lot
  FOR ALL USING (
    lot_owner_id = (SELECT lot_owner_id FROM lot_owner WHERE user_id =
      (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()))
  );

-- === PARKING LOT CONFIG / PRICING / TAGS / FEATURES ===
CREATE POLICY "config_public_read" ON parking_lot_config
  FOR SELECT USING (
    parking_lot_id IN (SELECT parking_lot_id FROM parking_lot WHERE status = 'APPROVED')
  );
CREATE POLICY "pricing_public_read" ON pricing
  FOR SELECT USING (
    parking_lot_id IN (SELECT parking_lot_id FROM parking_lot WHERE status = 'APPROVED')
  );
CREATE POLICY "tag_public_read" ON parking_lot_tag
  FOR SELECT USING (true);
CREATE POLICY "feature_public_read" ON parking_lot_feature
  FOR SELECT USING (true);

-- === SESSIONS ===
CREATE POLICY "session_driver_read" ON parking_session
  FOR SELECT USING (
    driver_id = (SELECT driver_id FROM driver WHERE user_id =
      (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()))
  );
CREATE POLICY "session_attendant_manage" ON parking_session
  FOR ALL USING (
    parking_lot_id = (SELECT parking_lot_id FROM attendant WHERE user_id =
      (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()))
  );

-- === SESSION EDIT ===
CREATE POLICY "session_edit_attendant" ON session_edit
  FOR ALL USING (
    session_id IN (
      SELECT session_id FROM parking_session WHERE parking_lot_id =
        (SELECT parking_lot_id FROM attendant WHERE user_id =
          (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()))
    )
  );

-- === BOOKING ===
CREATE POLICY "booking_driver_crud" ON booking
  FOR ALL USING (
    driver_id = (SELECT driver_id FROM driver WHERE user_id =
      (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()))
  );

-- === PAYMENT ===
CREATE POLICY "payment_driver_read" ON payment
  FOR SELECT USING (
    driver_id = (SELECT driver_id FROM driver WHERE user_id =
      (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()))
  );

-- === LOT LEASE ===
CREATE POLICY "lease_owner_read" ON lot_lease
  FOR SELECT USING (
    parking_lot_id IN (
      SELECT parking_lot_id FROM parking_lot WHERE lot_owner_id =
        (SELECT lot_owner_id FROM lot_owner WHERE user_id =
          (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()))
    )
  );
CREATE POLICY "lease_manager_read" ON lot_lease
  FOR SELECT USING (
    manager_id = (SELECT manager_id FROM manager WHERE user_id =
      (SELECT user_id FROM "user" WHERE auth_uid = auth.uid()))
  );

-- === LEASE CONTRACT ===
CREATE POLICY "contract_parties_read" ON lease_contract
  FOR SELECT USING (
    lease_id IN (SELECT lease_id FROM lot_lease)  -- refined by lease policies
  );

-- === ANNOUNCEMENTS ===
CREATE POLICY "announcement_public_read" ON parking_lot_announcement
  FOR SELECT USING (
    parking_lot_id IN (SELECT parking_lot_id FROM parking_lot WHERE status = 'APPROVED')
    AND visible_from <= now()
    AND (visible_until IS NULL OR visible_until >= now())
  );

-- === NOTIFICATIONS ===
CREATE POLICY "notification_own" ON notification
  FOR SELECT USING (
    user_id = (SELECT user_id FROM "user" WHERE auth_uid = auth.uid())
  );
```

---

## 3. Error Code Catalog

Format: `PARK_XXXX` — grouped by domain.

| Code | HTTP | Message |
|------|------|---------|
| **Auth** | | |
| `PARK_401_01` | 401 | Invalid credentials |
| `PARK_401_02` | 401 | Token expired |
| `PARK_403_01` | 403 | Insufficient role permissions |
| `PARK_409_01` | 409 | Email already registered |
| **Sessions** | | |
| `PARK_400_01` | 400 | Invalid QR code data |
| `PARK_409_02` | 409 | Driver already has active session at this lot |
| `PARK_409_03` | 409 | Driver has active session at another lot |
| `PARK_409_04` | 409 | Lot is full — no available spots |
| `PARK_404_01` | 404 | No active session found for checkout |
| `PARK_409_05` | 409 | Session already checked out |
| `PARK_400_02` | 400 | Walk-in requires at least one photo |
| `PARK_404_02` | 404 | No active pricing for this lot + vehicle type |
| **Bookings** | | |
| `PARK_409_06` | 409 | No available spots to book |
| `PARK_409_07` | 409 | Active booking already exists at this lot |
| `PARK_410_01` | 410 | Booking has already expired |
| `PARK_404_03` | 404 | Booking not found or not owned by user |
| **Payments** | | |
| `PARK_409_08` | 409 | Payment already recorded for this session |
| `PARK_400_03` | 400 | Payment amount must be positive |
| `PARK_400_04` | 400 | Invalid payment method |
| **Lots** | | |
| `PARK_404_04` | 404 | Parking lot not found |
| `PARK_403_02` | 403 | Not authorized to manage this lot |
| `PARK_409_09` | 409 | Lot already has an active lease |
| **Leases** | | |
| `PARK_404_05` | 404 | Lease not found |
| `PARK_409_10` | 409 | Lease already approved |
| `PARK_403_03` | 403 | Only admin can approve leases |

**Response format:**
```json
{
  "data": null,
  "error": {
    "code": "PARK_2004",
    "message": "Lot is full — no available spots"
  },
  "status": 409
}
```

---

## 4. Pagination

**Strategy:** Offset-based with standard query params.

```
GET /api/v1/sessions?page=1&limit=20&sort=-checkin_time
```

| Param | Type | Default | Max |
|-------|------|---------|-----|
| `page` | int | 1 | — |
| `limit` | int | 20 | 100 |
| `sort` | string | `-created_at` | — |

**Response wrapper:**
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8
  },
  "status": 200
}
```

**FastAPI dependency:**
```python
class Pagination(BaseModel):
    page: int = Query(1, ge=1)
    limit: int = Query(20, ge=1, le=100)

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.limit
```

---

## 5. Realtime Forwarding

FastAPI subscribes to Supabase Realtime server-side and forwards to clients via WebSocket.

```python
# app/main.py
from fastapi import WebSocket, WebSocketDisconnect
import json

class AvailabilityManager:
    """Manages WebSocket connections for lot availability updates."""
    
    def __init__(self):
        self.connections: dict[int, list[WebSocket]] = {}  # lot_id → clients
    
    async def connect(self, ws: WebSocket, lot_ids: list[int]):
        await ws.accept()
        for lot_id in lot_ids:
            self.connections.setdefault(lot_id, []).append(ws)
    
    async def broadcast(self, lot_id: int, available: int):
        for ws in self.connections.get(lot_id, []):
            await ws.send_json({"lot_id": lot_id, "current_available": available})

manager = AvailabilityManager()

@app.websocket("/ws/availability")
async def ws_availability(websocket: WebSocket, lot_ids: str):
    ids = [int(x) for x in lot_ids.split(",")]
    await manager.connect(websocket, ids)
    try:
        while True:
            await websocket.receive_text()  # keep alive
    except WebSocketDisconnect:
        for lid in ids:
            manager.connections[lid].remove(websocket)
```

On the Supabase side, FastAPI subscribes on startup:

```python
# Triggered from adjust_available() → Supabase Realtime push
# FastAPI service listens to parking_lot UPDATE events and calls manager.broadcast()
```

---

## 6. Contract Template

Lease contracts are styled HTML, generated by `contract_service.py`:

```python
def generate_contract_html(lease: LotLease, lot: ParkingLot,
                           owner: LotOwner, operator: Manager) -> str:
    contract_number = f"HD-{lease.lease_id:06d}"
    return f"""
    <div class="contract">
      <h1>HỢP ĐỒNG CHO THUÊ BÃI XE</h1>
      <p>Số hợp đồng: <strong>{contract_number}</strong></p>
      <p>Ngày: {lease.approved_at.strftime('%d/%m/%Y')}</p>
      <hr/>
      <h2>BÊN A – Chủ bãi xe</h2>
      <p>Họ tên: {owner.username}</p>
      <p>Email: {owner.email}</p>
      <h2>BÊN B – Đơn vị vận hành</h2>
      <p>Họ tên: {operator.username}</p>
      <p>GPKD: {operator.business_license}</p>
      <hr/>
      <h2>ĐIỀU KHOẢN</h2>
      <p><strong>Bãi xe:</strong> {lot.name} — {lot.address}</p>
      <p><strong>Thời hạn:</strong> {lease.start_date} → {lease.end_date}</p>
      <p><strong>Phí thuê:</strong> {lease.monthly_fee:,.0f} VND/tháng</p>
      <hr/>
      <div class="signatures">
        <div>BÊN A ký</div><div>BÊN B ký</div>
      </div>
    </div>
    """
```

---

## 7. Map Clustering

Client-side clustering using `react-native-maps`:

```javascript
// Use Supercluster for clustering lot markers
import Supercluster from 'supercluster';

const cluster = new Supercluster({ radius: 60, maxZoom: 16 });
cluster.load(lots.map(lot => ({
  type: 'Feature',
  geometry: { type: 'Point', coordinates: [lot.longitude, lot.latitude] },
  properties: { lot_id: lot.parking_lot_id, available: lot.current_available }
})));

// On region change → getClusters(bbox, zoom)
```

---

## 8. Sprint Breakdown

Each task is self-contained and can be given to any AI code editor. Tasks are ordered by dependency. Format: `[Sprint].[Task] — Title (estimated size)`.

### Sprint 0 — Foundation

| Task | Description | Files | Depends |
|------|-------------|-------|---------|
| **S0.1** | Initialize Supabase project (`supabase init`) | `supabase/` | — |
| **S0.2** | Create migration: all ENUMs | `supabase/migrations/001_enums.sql` | S0.1 |
| **S0.3** | Create migration: all 23 tables | `supabase/migrations/002_tables.sql` | S0.2 |
| **S0.4** | Create migration: functions + triggers | `supabase/migrations/003_functions.sql` | S0.3 |
| **S0.5** | Create migration: indexes | `supabase/migrations/004_indexes.sql` | S0.3 |
| **S0.6** | Create migration: RLS policies | `supabase/migrations/005_rls.sql` | S0.3 |
| **S0.7** | Create migration: pg_cron booking expiry | `supabase/migrations/006_cron.sql` | S0.4 |
| **S0.8** | Initialize FastAPI project (`uv init`) | `backend/` | — |
| **S0.9** | Create Supabase client util | `backend/app/db/supabase.py`, `config.py` | S0.8 |
| **S0.10** | Create JWT security + `require_role()` | `backend/app/core/security.py`, `dependencies.py` | S0.9 |
| **S0.11** | Create Pydantic base schemas + pagination | `backend/app/models/schemas.py` | S0.8 |
| **S0.12** | Create error handling + error codes | `backend/app/core/errors.py` | S0.8 |
| **S0.13** | Initialize Expo/React Native project | `mobile/` | — |
| **S0.14** | Setup Axios client with JWT interceptor | `mobile/src/api/client.ts` | S0.13 |

### Sprint 1 — Auth + Users

| Task | Description | Files | Depends |
|------|-------------|-------|---------|
| **S1.1** | Auth router: register, login, Google, refresh, me | `backend/app/routers/auth.py` | S0.10 |
| **S1.2** | Users router: profile CRUD, avatar upload | `backend/app/routers/users.py` | S0.10 |
| **S1.3** | Vehicles router: CRUD + image upload | `backend/app/routers/users.py` (vehicles sub) | S1.2 |
| **S1.4** | Mobile: Login / Register screens | `mobile/src/screens/auth/` | S0.14 |
| **S1.5** | Mobile: Profile / Vehicle setup screens | `mobile/src/screens/profile/` | S1.4 |
| **S1.6** | Mobile: Auth state management (Zustand store) | `mobile/src/stores/auth.ts` | S1.4 |

### Sprint 2 — Lots + Map

| Task | Description | Files | Depends |
|------|-------------|-------|---------|
| **S2.1** | Lots router: list (with geo filter), detail, CRUD | `backend/app/routers/parking_lots.py` | S0.10 |
| **S2.2** | Lot config + pricing endpoints | `backend/app/routers/parking_lots.py` | S2.1 |
| **S2.3** | Tags + features endpoints | `backend/app/routers/parking_lots.py` | S2.1 |
| **S2.4** | Mobile: Map screen with Mapbox + markers | `mobile/src/screens/map/` | S0.14 |
| **S2.5** | Mobile: Lot detail screen | `mobile/src/screens/lots/` | S2.4 |
| **S2.6** | Mobile: Map Supercluster integration | `mobile/src/screens/map/` | S2.4 |
| **S2.7** | WebSocket: availability forwarding | `backend/app/main.py`, `mobile/src/api/ws.ts` | S2.1 |

### Sprint 3 — Sessions (Check-in / Check-out)

| Task | Description | Files | Depends |
|------|-------------|-------|---------|
| **S3.1** | QR service: generate + validate driver QR | `backend/app/services/qr_service.py` | S0.10 |
| **S3.2** | Parking service: `adjust_available()` wrapper | `backend/app/services/parking_service.py` | S0.9 |
| **S3.3** | Pricing service: fee calculation engine | `backend/app/services/pricing_service.py` | S0.9 |
| **S3.4** | Sessions router: check-in (app user + walk-in) | `backend/app/routers/sessions.py` | S3.1, S3.2 |
| **S3.5** | Sessions router: check-out + fee calc | `backend/app/routers/sessions.py` | S3.3, S3.4 |
| **S3.6** | Sessions router: edit + photo upload | `backend/app/routers/sessions.py` | S3.4 |
| **S3.7** | Mobile: Driver QR screen (state machine) | `mobile/src/screens/driver/QRScreen.tsx` | S1.4 |
| **S3.8** | Mobile: Attendant scanner + session dashboard | `mobile/src/screens/attendant/` | S1.4 |
| **S3.9** | Mobile: Walk-in photo capture flow | `mobile/src/screens/attendant/` | S3.8 |

### Sprint 4 — Bookings + Payments

## 9. Testing Strategy Hooks

### 9.1 Jest CSS Mocking (NativeWind v4)
To prevent `SyntaxError` in component tests targeting NativeWind, the `jest.config.js` MUST include a `moduleNameMapper` for CSS files:

```javascript
module.exports = {
  // ... existing config
  moduleNameMapper: {
    '\\.css$': '<rootDir>/__mocks__/styleMock.js',
  },
};
```

`__mocks__/styleMock.js` should be an empty export: `module.exports = {};`.

| Task | Description | Files | Depends |
|------|-------------|-------|---------|
| **S4.1** | Booking service: expiration, slot hold | `backend/app/services/booking_service.py` | S3.2 |
| **S4.2** | Bookings router: create, cancel, list | `backend/app/routers/bookings.py` | S4.1 |
| **S4.3** | Payments router: cash + mock online | `backend/app/routers/payments.py` | S3.5 |
| **S4.4** | Mobile: Booking flow (lot detail → confirm) | `mobile/src/screens/booking/` | S2.5 |
| **S4.5** | Mobile: Payment screen (cash/online) | `mobile/src/screens/payment/` | S3.8 |
| **S4.6** | Mobile: Parking history screen | `mobile/src/screens/history/` | S1.4 |

### Sprint 5 — Leases + Admin

| Task | Description | Files | Depends |
|------|-------------|-------|---------|
| **S5.1** | Leases router: register lot, list, lease apply | `backend/app/routers/leases.py` | S0.10 |
| **S5.2** | Contract service: HTML generation | `backend/app/services/contract_service.py` | S5.1 |
| **S5.3** | Admin router: approve lot, approve lease, user mgmt | `backend/app/routers/admin.py` | S5.2 |
| **S5.4** | Attendants router: CRUD by Operator | `backend/app/routers/attendants.py` | S0.10 |
| **S5.5** | Announcements router: CRUD | `backend/app/routers/announcements.py` | S0.10 |
| **S5.6** | Reports router: revenue, occupancy | `backend/app/routers/reports.py` | S3.5 |
| **S5.7** | Mobile: Operator screens (config, pricing, attendants) | `mobile/src/screens/operator/` | S1.4 |
| **S5.8** | Mobile: LotOwner screens (lots, leases, contracts) | `mobile/src/screens/lotowner/` | S1.4 |
| **S5.9** | Mobile: Admin screens (approvals, users) | `mobile/src/screens/admin/` | S1.4 |

### Sprint 6 — Polish + Integration Testing

| Task | Description | Files | Depends |
|------|-------------|-------|---------|
| **S6.1** | End-to-end: full check-in → checkout → payment flow | Test script | S3, S4 |
| **S6.2** | End-to-end: booking → arrival → session → payment | Test script | S4 |
| **S6.3** | End-to-end: lot registration → lease → contract | Test script | S5 |
| **S6.4** | Edge case testing: EC1-EC20 from PRD | Test script | All |
| **S6.5** | Mobile: UI polish, error handling, loading states | `mobile/` | All |

---

## 9. Task Prompt Format (for AI Code Editors)

Each task in the sprint breakdown can be given to an AI code editor with this prompt template:

```
Project: Smart Parking Management System
Tech stack: FastAPI + Supabase (Python), React Native + Expo (TypeScript)

References:
- PRD: _bmad-output/prd.md
- Architecture: _bmad-output/architecture.md
- Tech Design: _bmad-output/tech-design.md (see §[relevant section])
- ERD: doc/erd.md

Task: [S#.#] — [Description]
Files to create/modify: [file list]
Dependencies: [what must exist already]

Requirements: [copy relevant FRs and edge cases]
```

> **Tip:** Keep the `tech-design.md` in the project root-level `_bmad-output/` folder so any AI editor can reference it.
