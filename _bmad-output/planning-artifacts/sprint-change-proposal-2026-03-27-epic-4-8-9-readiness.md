# Sprint Change Proposal

Date: 2026-03-27
Project: thesis
Scope Classification: Minor
Status: Approved

## 1. Issue Summary

Epic 3 retrospective confirmed that the project has moved beyond a pure feature-delivery question for Operator workflows. The implemented contracts are sound, but three planning implications are now explicit:

- Epic 4 depends on Epic 3 setup data and on consistent inactive-account enforcement for attendant lifecycle integrity.
- Epic 8 is now a workflow-enablement epic, because proper lease lifecycle is required to make Operator features naturally reachable without bootstrap shortcuts.
- Epic 9 is now validated as a structural requirement, because public multi-capability users need explicit workspace routing and shell behavior.

The issue is not that Epics 4, 8, and 9 are wrongly defined. The issue is that their readiness assumptions were previously too implicit.

## 2. Impact Analysis

### Epic Impact

- Epic 4: no scope rewrite, but readiness notes must explicitly reference Epic 3 setup contracts and auth lifecycle integrity.
- Epic 8: no FR change, but planning should state that lease lifecycle work replaces the temporary UAT bootstrap path.
- Epic 9: no story rewrite, but planning should state that role-switching and workspace routing are now proven requirements.

### Story Impact

- Epic 4 stories should assume lot configuration and attendant provisioning exist, but should not silently depend on temporary bridge UX.
- Epic 8 Story 8.1 should be treated as the durable replacement for lease-bootstrap bridging.
- Epic 9 Story 9.1 and 9.4 should absorb the current temporary public workspace switch behavior into final routing and shell structure.

### Artifact Conflicts

- No conflict with the PRD was identified.
- `epics.md` needed explicit readiness notes so future implementation sessions do not rediscover the same dependencies through review.

## 3. Recommended Approach

Recommended path: Direct Adjustment.

Rationale:

- The epic ordering remains valid.
- The issue is planning clarity, not a product or architecture reversal.
- Explicit readiness notes reduce repeated scope confusion during future story execution and review.

## 4. Detailed Change Proposals

### Change A: Add Epic 4 readiness note

Artifact: `planning-artifacts/epics.md`

NEW:
- State that Epic 4 builds on Epic 3 leased-lot setup, lot-wide rules, and dedicated Attendant accounts.
- State that inactive-account enforcement is a hard gate-integrity prerequisite.

Rationale:

- Makes the operational dependency on Epic 3 explicit before check-in/check-out implementation expands.

### Change B: Add Epic 8 readiness note

Artifact: `planning-artifacts/epics.md`

NEW:
- State that Epic 8 replaces the temporary lease-bootstrap path with the proper contract lifecycle.

Rationale:

- Keeps the current bridge clearly temporary and prevents it from becoming accidental long-term architecture.

### Change C: Add Epic 9 readiness note

Artifact: `planning-artifacts/epics.md`

NEW:
- State that multi-capability workspace switching is now a demonstrated routing requirement.
- State that Epic 9 is workflow-validation infrastructure, not cosmetic polish.

Rationale:

- Aligns shell planning with proven implementation pressure from Epic 3.

## 5. Implementation Handoff

Handoff target: Future BMAD story execution for Epics 4, 8, and 9.

Immediate next actions:

1. Use the new Epic 4 note when creating or validating Story 4.1 so setup dependencies are explicit.
2. Use the Epic 8 note to keep lease bootstrap classified as an interim bridge, not final business flow.
3. Use the Epic 9 note when planning shell work so the current workspace switch bridge is deliberately absorbed and removed.

Success criteria:

- Future stories do not rediscover these dependencies through late review.
- Bridge behavior remains explicitly temporary.
- Epic 9 is treated as required workflow infrastructure in planning discussions.