# Sprint Change Proposal — UX Shell & Navigation Foundation

Date: 2026-03-27
Project: thesis
Scope Classification: Moderate
Status: Approved

---

## 1. Issue Summary

### Trigger

Identified across multiple artifacts during Epic 1 retrospective and Epic 2 implementation:

- `deferred-work.md` (2026-03-27): *"Create a dedicated UX hardening story for public/admin shells to standardize navigation, reduce placeholder-first layouts, and finish Vietnamese localization for visible role/workspace labels."*
- `deferred-work.md` (2026-03-27): *"Prefer a shared shell/navigation pattern before Epic 3 expands the Operator workspace further, otherwise role-specific placeholders will continue to diverge."*
- `epic-1-retro-2026-03-27.md`: *"The mobile shell is still role-first and placeholder-heavy … it became a structural constraint once additive capabilities started to accumulate."*
- `1-5-apply-to-become-operator.md` (retro note 3): *"The request for a more standard app layout should be handled as a dedicated UX/story effort rather than folded into this capability-application patch set."*

### Core Problem

The app routes all 5 actor workspaces through a single `if/else` chain in `main.dart` (~450 lines), with:
- No `go_router` routing framework (contradicts `architecture.md`)
- No `ThemeData` split (the UX spec mandates a Divergent Dual-Context strategy: Dark for Attendant, Light for all others)
- Attendant and Operator workspaces are raw `_buildWorkspacePlaceholder(...)` calls — a single `Scaffold` with a text message
- LotOwner workspace lands directly in `ParkingLotRegistrationScreen` with no surrounding shell or navigation
- All workspace labels are mixed English/Vietnamese placeholder strings
- No shared `LoadingView`, `ErrorView`, `EmptyView` — every screen builds these ad hoc

### Evidence

| Workspace | Current implementation | Expected per UX spec |
|---|---|---|
| Driver | `MapScreen` + icon-bar actions (mixed) | Map-first shell, BottomNav: Map / History / Profile |
| Attendant | `_buildWorkspacePlaceholder("Attendant Workspace")` | Dark shell, edge-to-edge, no AppBar padding waste |
| Operator | `_buildWorkspacePlaceholder("Operator Workspace")` | Light shell, NavigationBar: Lots / Attendants / Revenue |
| Lot Owner | `ParkingLotRegistrationScreen` (no shell) | Light shell, NavigationBar: My Lots / Leases / Profile |
| Admin | `AdminApprovalsScreen` (no shell) | Light shell, structured: Approvals / Users / Lots |

The `ux-design-directions.html` mockup covers only 2 of 5 actors (Direction A: Attendant, Direction B: Driver). Operator, Lot Owner, and Admin have no layout prototype. The `ux-design-specification.md` addresses only Attendant and Driver layout explicitly under "Spacing & Layout Foundation".

---

## 2. Impact Analysis

### 2.1 Epic Impact

| Epic | Impact |
|---|---|
| Epic 2 (in-progress) | No scope change. Story 2-3 (Lot Suspension) can proceed as-is; it will be absorbed into correct Admin shell when Epic 9 runs. |
| Epic 3 (backlog) | Moderate risk: Operator workspace stories will build on a placeholder shell if UX shell delayed. Manageable since user confirmed logic-first order. |
| Epic 4 (backlog) | Attendant workspace stories need the Dark shell to implement gate UX correctly. Both can proceed in parallel; Epic 9 hardening is planned before thesis demo. |
| Epics 5–8 (backlog) | Driver and Operator workspace stories need correct shells. All develop against placeholder shell first; Epic 9 unifies. |
| Epic 9 Notifications (old, Phase 2) | Renumbered to Epic 10 to make room for new Epic 9. |

### 2.2 Story Impact

- No existing story acceptance criteria are invalidated.
- Future stories (Epics 3–8) should note: *"UI is implemented against the workspace placeholder shell; Epic 9 will apply the standard shell; functional logic must not depend on shell layout specifics."*
- deferred-work.md items resolved by this proposal.

### 2.3 Artifact Conflicts

| Artifact | Conflict | Resolution |
|---|---|---|
| `ux-design-specification.md` §Spacing & Layout Foundation | Only describes Attendant and Driver layouts. Operator, LotOwner, Admin have no layout direction. | Epic 9 stories serve as the layout specification for the missing 3 actors; no UX spec rewrite needed — stories are authoritative for those actors. |
| `ux-design-directions.html` | Only 2 of 5 direction mockups | No change needed; this file is a concept proof. Concrete layout is specified per story in Epic 9. |
| `architecture.md` navigation row | Lists `go_router` but current code does not use it | Epic 9 Story 9.1 implements this alignment. |
| `epics.md` | No UX Shell epic exists | Adding new Epic 9 (see Section 4). |
| `sprint-status.yaml` | No entries for new epic | Adding new entries (see Section 4). |

### 2.4 Technical Impact

- No backend changes required.
- No API contract changes.
- No new pub.dev dependencies required (go_router already listed in architecture; theme and widget work uses existing Flutter Material).
- Refactoring `main.dart` reduces file size from ~450 lines to ~80 lines; all functional logic stays identical.

---

## 3. Recommended Approach

**Direct Adjustment — Add New Epic, Logic-First Ordering.**

### Rationale

- The product direction is stable. All business logic is correctly planned in Epics 1–8.
- The UX standardization work is cross-cutting foundation, not a new feature. It does not block any Story from being implemented logically.
- Building logic first (Epics 1–8) against placeholder shells, then applying a polished UX shell (Epic 9) last, is the correct thesis-demo strategy: all features work first, then the app looks right.
- This mirrors the deferred-work.md intent: *"keep the deferred UX hardening work visible, but do not let shell standardization block the immediate approval workflows."*

### Ordering Principle

```
Epic 1 (done) → Epic 2 (in-progress) → Epic 3 → Epic 4 → Epic 5 → Epic 6 → Epic 7 → Epic 8
                                                                                       ↓
                                                                              Epic 9: UX Shell
                                                                                       ↓
                                                                     Epic 10: Notifications (Phase 2)
```

### Constraints

- **Each story in Epics 3–8** must not hardcode layout dimensions or shell structure. Workspace screens must be self-contained and accept a surrounding shell.
- **Epic 9 must run before the thesis demo** — it is not optional like Phase 2 notifications.

### Effort & Risk

| Item | Estimate | Risk |
|---|---|---|
| Routing & theme setup (9.1) | 1 day | Low — straightforward Flutter refactor |
| Driver shell (9.2) | 0.5 day | Low — wraps existing MapScreen |
| Attendant shell (9.3) | 1 day | Medium — edge-to-edge and dark theme |
| Management shells (9.4) | 1 day | Low — tabs with placeholder content |
| Admin shell (9.5) | 0.5 day | Low — extends existing screen |
| Shared components + localization (9.6) | 1 day | Low |
| **Total** | **~5 days** | **Low–Medium** |

---

## 4. Detailed Change Proposals

### Change A: Add Epic 9 — UX Shell & Navigation Foundation

Artifact: `planning-artifacts/epics.md`

Insert the following new epic block **after Epic 8 and before the existing Epic 9 (Notifications)**, and renumber existing Epic 9 to Epic 10.

```
### Epic 9: UX Shell & Navigation Foundation
Goal: Establish standardized workspace shells, routing, theme profiles, and shared components
for all 5 actor contexts, aligned with the Divergent Dual-Context UX strategy defined in
ux-design-specification.md.

FRs covered: (cross-cutting — no new FRs; supports all Epics 1–8 functional requirements)
UX Refs: ux-design-specification.md §Design System Foundation, §Spacing & Layout Foundation,
         §Design Direction Decision, §Component Strategy

Implementation constraint: This epic runs LAST before thesis demo, after all business logic
epics are complete. Epics 3–8 implement their screens as self-contained widgets; Epic 9
wraps them in correct shells. No story in Epics 3–8 should hardcode shell structure.
```

### Change B: Epic 9 Stories

**Story 9.1: App Routing Foundation & Dual Theme System**

```
As a developer,
I want a centralized routing system and two ThemeData profiles,
So that all workspace screens use correct themes and navigation structure from the start.

Acceptance Criteria:
* go_router is configured with named routes for all 5 workspace entry points
* AppTheme.light() — MD3, primary #1A73E8, standard MD3 paddings (Driver/Operator/LotOwner/Admin)
* AppTheme.dark() — oversized typography, dark surface #121212, high contrast (Attendant only)
* main.dart delegates app bootstrap to a dedicated app.dart; service factories initialized once
* MaterialApp uses Light theme by default; Attendant workspace overrides to Dark theme
* Routing is auth-aware: unauthenticated → AuthGate, authenticated → workspace by session role
```

**Story 9.2: Driver Workspace Shell**

```
As a Driver,
I want a consistent app shell with bottom navigation,
So that I can access all driving features predictably without hidden actions.

Acceptance Criteria:
* BottomNavigationBar with 3 tabs: Map (home), History, Profile
* All Driver screens use AppTheme.light()
* Primary actions anchored to bottom Thumb-Zone per UX spec (Single-Tap Full-Width Buttons)
* Existing MapScreen integrates as the Map tab without functional changes
* History tab shows EmptyView placeholder until Story 5.3 is implemented
* Profile tab shows vehicle management entry point and capability application shortcuts
* All tab labels in Vietnamese: Bản đồ, Lịch sử, Cá nhân
```

**Story 9.3: Attendant Workspace Shell**

```
As an Attendant,
I want a dedicated dark-mode interface shell optimized for gate operations,
So that the correct high-contrast, edge-to-edge Dark UI is in place for Epic 4 stories.

Acceptance Criteria:
* AttendantShell widget uses AppTheme.dark() with edge-to-edge Scaffold
* No wasted AppBar padding: status bar integrates into the dark header zone
* Screen body uses full available height via MediaQuery + SafeArea correctly
* Attendant workspace entry (currently placeholder) replaced with proper shell
* Shell reserves top half for camera viewfinder area and bottom half for interaction zone
  (proportional via Expanded/Flex, per UX spec §Responsive Strategy)
* Dark header label shows lot assignment when available ("BÃI XE — [Tên bãi]")
```

**Story 9.4: Management Workspace Shells (Operator & Lot Owner)**

```
As an Operator or Lot Owner,
I want a management workspace organized by function,
So that I can navigate between configuration, financial, and operational tasks.

Acceptance Criteria:
[Operator Shell]
* NavigationBar with tabs: Bãi xe, Nhân viên, Doanh thu
* Existing screens integrate as correct tab content without logic changes
* Empty tabs show EmptyView until respective Epic 3/6/8 stories are implemented

[Lot Owner Shell]
* NavigationBar with tabs: Bãi của tôi, Hợp đồng, Cá nhân
* Existing ParkingLotRegistrationScreen accessible from "Bãi của tôi" tab
* Other tabs show EmptyView until Epic 8 stories are implemented

[Both]
* Light theme applies consistently
* No feature logic changes; only shell structure added
```

**Story 9.5: Admin Workspace Shell**

```
As an Admin,
I want a clear workspace structure organized by administrative function,
So that approvals, user management, and lot suspension are navigable from one place.

Acceptance Criteria:
* Admin workspace has tab structure or drawer: Duyệt hồ sơ, Người dùng, Bãi xe
* Existing AdminApprovalsScreen integrates as the "Duyệt hồ sơ" tab with no functional changes
* "Người dùng" and "Bãi xe" tabs show EmptyView until Story 2.3 and later admin stories
* Light theme applies
* AdminApprovalsScreen removed as standalone entry; routed through AdminShell
```

**Story 9.6: Shared UI Components & Localization**

```
As any app user,
I want consistent loading, error, and empty states across all workspaces,
So that the UI feels coherent and polished at the thesis demo level.

Acceptance Criteria:
* LoadingView — centered CircularProgressIndicator, optional message, Light and Dark variants
* ErrorView — icon + message + optional retry action, accessible
* EmptyView — icon + message for "no items yet" states
* All workspace labels in Vietnamese:
  - Role display: Tài xế, Nhân viên, Vận hành viên, Chủ bãi xe, Quản trị viên
  - Navigation tabs: per story 9.2–9.5 acceptance criteria
  - Error messages: Vietnamese user-facing error strings
* All existing placeholder English strings removed from workspace entry points
* Shared widgets used by at least one screen per workspace to validate integration
```

---

### Change C: Rename old Epic 9 → Epic 10

Artifact: `planning-artifacts/epics.md`

```
OLD: ### Epic 9: Notifications (Phase 2)
NEW: ### Epic 10: Notifications (Phase 2)
```

No content change — only heading number.

### Change D: Update sprint-status.yaml

Add after `epic-8: backlog`:

```yaml
  epic-9: backlog
  9-1-app-routing-foundation-dual-theme: backlog
  9-2-driver-workspace-shell: backlog
  9-3-attendant-workspace-shell: backlog
  9-4-management-workspace-shells: backlog
  9-5-admin-workspace-shell: backlog
  9-6-shared-ui-components-localization: backlog
  epic-9-retrospective: optional
  epic-10: backlog
```

And rename existing:
```yaml
OLD: epic-9: backlog (if present)
NEW: epic-10: backlog
```

---

## 5. Implementation Handoff

**Handoff Classification:** Moderate — backlog insertion, no immediate dev work.

**Immediate next actions:**

1. SM (Bob): Update `epics.md` with new Epic 9 and renumber old Epic 9 → Epic 10.
2. SM (Bob): Update `sprint-status.yaml` with new epic-9 entries.
3. Dev (Amelia): Note that Epics 3–8 workspace screens must remain self-contained (no shell dependency).
4. PM (John): Epic 9 is mandatory before thesis demo — it is not Phase 2 scope.

**Implementation entry point:** Epic 9 begins after Story 8.3 (last business logic story) is marked done, or can be pulled earlier if a sprint has capacity after Epics 3–4 complete (Attendant shell in 9.3 can unblock Epic 4 gate UX stories).

**Success criteria:**
- [ ] All 5 workspaces route through correct shell with appropriate theme
- [ ] Attendant workspace uses Dark theme; all others use Light theme
- [ ] No workspace label in English on any user-facing screen
- [ ] `main.dart` reduced to bootstrap + service factory initialization only
- [ ] Shared LoadingView/ErrorView/EmptyView used across all workspaces
- [ ] go_router canonical routes match architecture.md specification
