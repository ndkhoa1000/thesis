# Smart Parking System: UAT Test Cases & Seed Data

This document provides End-to-End (E2E) testing scenarios for User Acceptance Testing (UAT). It includes predefined test accounts (seed data) that should be pre-loaded into the database for rapid testing of core business flows (e.g., Check-in, lot configuration) without needing to configure a lot from scratch every time.

## 1. Test Accounts (Seed Data Requirements)

The backend database initialization (`seed.py` or equivalent Alembic data migration) must pre-populate the following active accounts with their respective capabilities and a default password (e.g., `Password123!`):

| Role / Capability | Email | Description |
| :--- | :--- | :--- |
| **Admin** | `admin@smartparking.local` | Has global approval access and system management. |
| **Lot Owner** | `owner@smartparking.local` | Has `lot_owner` capability. Owns "Bãi Xe Mẫu Quận 1" (ID: 1). |
| **Operator** | `operator@smartparking.local` | Has `manager` capability. Holds an ACTIVE lease for Lot ID 1. |
| **Attendant** | `attendant_demo@smartparking.local` | Dedicated Attendant credential assigned to Lot ID 1. |
| **Driver 1** | `driver_demo@smartparking.local` | Standard user with an approved vehicle profile (Plate: 59A-123.45). |

*(The backend must also ensure: Lot ID 1 is in an `ACTIVE` state, capacity = 50, pricing = 10k/hr, and Operating Hours = 06:00 - 22:00).*

---

## 2. UAT Scenarios (End-to-End Flows)

### Scenario A: Lot Configuration & Capacity Overflow (Focus on Epic 3 & 4)
**Goal:** Verify Operator's UI configuration standardization and the non-blocking "OVERFLOW" edge case.

1. **Login:** Log in as `operator@smartparking.local` on the Operator Workspace.
2. **Access Configuration:** Navigate to the Configuration / Settings tab for Lot ID 1.
3. **Verify Standard UI Components (Edge Case Fixed):**
   - Attempt to change the Operating Hours.
   - **Expected Result:** The UI forces the use of a native `TimePicker` dial. Manual text entry is disabled.
4. **Trigger Overflow:** 
   - Observe the `current_occupied_slots` (Assume it is currently 10).
   - Change the Lot's `total_capacity` to 5.
   - **Expected Result:** The system explicitly warns "Dung lượng nhỏ hơn số xe hiện tại. Bãi sẽ chuyển sang trạng thái QUÁ TẢI (OVERFLOW)". The change is saved successfully, but the UI shows an OVERFLOW warning flag.
5. **Verify Non-Blocking Checkout:** 
   - Log in as `attendant_demo@smartparking.local`.
   - Perform a Check-Out action for an existing vehicle.
   - **Expected Result:** The Check-Out succeeds normally without breaking, reducing occupancy to 9.

### Scenario B: Walk-in Check-in with Camera (Focus on Epic 4 5-sec SLA)
**Goal:** Verify Attendant can process walk-in vehicles without blocking the UI.

1. **Login:** Log in as `attendant_demo@smartparking.local`.
2. **Walk-in Trigger:** Select the option to scan a walk-in vehicle (no app) or tap "Nhập tay/Chụp ảnh".
3. **Capture Photo:** 
   - The app prompts to take a photo of the vehicle/plate.
   - **Expected Result:** The camera photo is taken successfully via an `ImagePicker/Camera` widget (not a text URL field).
4. **Verify SLA (Edge Case Fixed):** 
   - Submit the check-in.
   - **Expected Result:** The UI returns immediately to the "Ready to Scan" state (green flash) < 5 seconds. The photo upload to Cloudinary runs *asynchronously* in the background. If you completely turn off Wifi/4G right after capturing, the check-in is still saved locally and queues for sync later.

### Scenario C: Driver Storage & Map Fallback (Focus on Epic 1 & 5)
**Goal:** Verify proper Media upload logic and GPS fallbacks.

1. **Add Vehicle:** Log in as `driver_demo@smartparking.local`.
   - Go to Profile -> Add Vehicle.
   - **Expected Result:** The "Vehicle Photo" field opens a native gallery/camera picker. You cannot manually type a web link (e.g., "imgur.com/abc").
2. **Deny GPS (Map Edge Case Fixed):**
   - Go to App Settings -> Permissions -> Deny Location Access for the Parking App.
   - Open the app's Map/Home Tab.
   - **Expected Result:** A Toast or Banner message appears: "Không thể lấy vị trí. Một số tính năng bản đồ bị giới hạn." The app does not crash. The user is presented with a fallback view (e.g., a default city center map, or forced to use a manual Address Search bar) and can still select a lot and book parking.

### Scenario D: Lease Expiry Management (Focus on Epic 8)
**Goal:** Verify Lot Owner's manual control over an expired Operator.

1. **Trigger Expiry:** (Backend Admin) Set Operator's Lease End Date to yesterday.
2. **Verify Lot Owner Control:** 
   - Log in as `owner@smartparking.local`.
   - Navigate to Contracts.
   - **Expected Result:** The contract clearly shows an "EXPIRED" warning. The lot remains operational, but the Owner sees a red "Vô hiệu hóa Bãi Xe" (Disable Lot) button.
3. **Execute Disabling:**
   - The Owner clicks "Vô hiệu hóa Bãi Xe".
   - **Expected Result:** The Lot status changes to `SUSPENDED` / `DISABLED`. New drivers cannot check in, but existing parked vehicles can still check out.

### Scenario E: Price Change Conflict (Focus on Epic 3 & 4)
**Goal:** Ensure a parking session calculates correctly when prices change mid-session.

1. **Setup Session:** `attendant_demo` checks in `driver_demo` at 08:00 AM while the Lot pricing is **10,000 VND / Hour**.
2. **Change Price:** `operator@smartparking.local` edits the Pricing Rule to **20,000 VND / Hour** at 09:00 AM.
3. **Perform Checkout:** `attendant_demo` checks out `driver_demo` at 10:00 AM (2 hours parked).
4. **Expected Result:** The system checks the `effective_date` of rules. The driver is charged based on the price when they checked in (10,000 VND x 2 hrs = 20,000 VND total), NOT 40,000 VND. No invoice dispute occurs.

---
*QA Note: All file/image uploads mentioned above MUST integrate with Cloudinary via FastAPI correctly (Multipart form data). If you intercept the HTTP request, there should be no raw `URL` strings being sent by the mobile app during create calls, only binary media.*
