# Smart Parking System: UAT Test Cases & Seed Data

This document is the current manual-test baseline for the local Android demo environment. It is aligned with the Docker-backed seed script, the completed stories through Epic 5 Story 5.4, and the verified operator first-time setup fix.

## 1. Environment Prerequisites

1. Start backend dependencies from the `backend` directory and apply the latest migrations.
2. Seed the demo dataset from Docker Compose, not the host virtualenv:

```bash
cd backend
docker compose run --rm pytest python -m src.scripts.seed_android_demo_data
```

3. Configure `mobile/.env`:

```env
API_BASE_URL=http://127.0.0.1:8000/api/v1
MAPBOX_ACCESS_TOKEN=<your-mapbox-token>
```

4. For a real Android device, reverse the backend port before launching the app:

```bash
adb reverse tcp:8000 tcp:8000
cd mobile
flutter run -d <device-id>
```

5. For an Android emulator, use `API_BASE_URL=http://10.0.2.2:8000/api/v1`.

## 2. Fixed Demo Accounts

| Role | Email | Password | Primary use |
| :--- | :--- | :--- | :--- |
| Admin | `admin.demo@parking.local` | `Admin123!` | Approvals, lot suspension and reopen checks |
| Driver | `driver.demo@parking.local` | `Driver123!` | Map discovery, lot details, parking history, QR flows |
| Lot Owner | `owner.demo@parking.local` | `Owner123!` | Registering lots and owner-side smoke tests |
| Operator | `operator.demo@parking.local` | `Operator123!` | Assigned-lot setup, pricing/config changes, attendant management |
| Attendant | `attendant.demo@parking.local` | `Attendant123!` | QR scan, walk-in check-in, checkout preview/finalize |

## 3. Seeded Demo Assets

### Ready Lot: `Bãi xe Demo Nguyễn Huệ`

- Status starts as `APPROVED`.
- Has an active lease for the demo operator.
- Has current config, pricing, tags, features, historical sessions, and one active checked-in session.
- Is the primary lot for Epic 4 and Epic 5 verification.

### Setup Lot: `Bãi xe Demo Thiết Lập`

- Status starts as `CLOSED`.
- Has an active lease for the demo operator.
- Has no current config or pricing after reseed.
- Is reserved for testing the operator first-time setup flow.
- Expected behavior: after a valid first-time setup, the lot transitions to `APPROVED`.

## 4. UAT Scenarios

### Scenario A: Operator First-Time Setup Reopens Assigned Lot

**Goal:** Verify the assigned setup lot can be configured on Android and automatically reopens only for the first-time setup path.

1. Log in as `operator.demo@parking.local`.
2. Open the assigned lot list and select `Bãi xe Demo Thiết Lập`.
3. Enter total capacity, operating hours, and pricing, then save.
4. Expected result: the save succeeds and the lot status changes from `CLOSED` to `APPROVED`.
5. Reopen the screen or refresh the lot list.
6. Expected result: the configured values persist and the lot stays visible as an active assigned lot.

### Scenario B: Admin Suspension Remains Authoritative

**Goal:** Verify the first-time setup fix does not accidentally reopen a previously configured lot that an admin intentionally closed.

1. Use the ready lot or a manually preconfigured lot.
2. Log in as `admin.demo@parking.local` and close the lot.
3. Log back in as `operator.demo@parking.local` and update pricing or operating hours.
4. Expected result: the update may persist, but the lot does not auto-transition back to `APPROVED`.

### Scenario C: QR Check-In and Checkout Core Loop

**Goal:** Verify the Epic 4 happy path on the ready lot.

1. Log in as `driver.demo@parking.local` and generate a check-in QR.
2. Log in as `attendant.demo@parking.local` and scan the QR at `Bãi xe Demo Nguyễn Huệ`.
3. Expected result: a parking session is created and availability decreases.
4. Generate a driver checkout QR, preview checkout as the attendant, then finalize payment.
5. Expected result: the session closes successfully and availability increases.

### Scenario D: Walk-In Check-In With Plate Photo

**Goal:** Verify the attendant walk-in flow still works against the seeded ready lot.

1. Log in as `attendant.demo@parking.local`.
2. Start a walk-in check-in and capture the vehicle or plate image.
3. Complete the check-in.
4. Expected result: the session is created, the app returns to the scan-ready state quickly, and lot availability decreases.

### Scenario E: Driver Discovery, Lot Details, and En-Route Advisory

**Goal:** Verify the Epic 5 flow, including Story 5.4 realtime capacity advisory.

1. Log in as `driver.demo@parking.local`.
2. Open the map or fallback discovery view.
3. Open `Bãi xe Demo Nguyễn Huệ` from the marker or quick card.
4. Expected result: lot details show current availability, operating hours, pricing, and peak-hours data from seeded history.
5. Tap `Dẫn đường` for the selected lot.
6. While the driver remains focused on that lot, trigger enough attendant check-ins or capacity changes so the lot becomes full.
7. Expected result: the driver receives a temporary advisory alert for the watched lot, without being rerouted automatically.

### Scenario F: Map Fallback Without Token or Location

**Goal:** Verify driver and owner flows degrade safely when full Mapbox behavior is unavailable.

1. Remove the Mapbox token or deny location permission.
2. Launch the app and open the map-related flows.
3. Expected result: the app does not crash and still exposes a usable fallback discovery/list experience.
4. Log in as `owner.demo@parking.local` and open parking-lot registration.
5. Expected result: the owner can still choose a location through the current picker fallback path and submit the lot form.

## 5. Execution Notes

1. Record whether the run used a real Android device or emulator.
2. Record the exact `API_BASE_URL` and whether a Mapbox token was present.
3. Reseed before each full manual regression if any tester has already configured the setup lot.
4. When closing a story or epic, capture pass or fail per scenario, open defects, and any temporary workaround.
