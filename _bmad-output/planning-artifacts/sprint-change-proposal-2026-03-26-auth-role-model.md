# Sprint Change Proposal

Date: 2026-03-26
Project: thesis
Scope Classification: Moderate

## 1. Issue Summary

During Epic 1 planning, the product team clarified the intended account model for authentication and role access:

- Public signup always creates a Driver account by default.
- A public account can later gain LotOwner capability or Operator capability through separate application and approval flows.
- Attendant is not a role switch inside the public account model. It is a separate account created by an Operator.
- Admin is also a separate privileged account and is never created through the public signup path.

This reveals a mismatch between the current PRD/epics and the desired product behavior. Existing documents imply a simpler role-switch model and do not clearly distinguish capability expansion from separate-account login.

## 2. Impact Analysis

### Epic Impact

- Epic 1 is directly affected because registration and login rules need clarification.
- Epic 2 is indirectly affected because parking-lot registration assumes an already-approved LotOwner capability.
- Epic 3 is directly affected because attendant management must be modeled as account provisioning, not in-account role switching.

### Story Impact

- Story 1.1 remains valid, but must stay scoped to default Driver registration only.
- Story 1.2 must clarify login behavior for public accounts versus separate Attendant/Admin accounts.
- New identity stories are needed for applying to become LotOwner and Operator.
- Story 3.3 must change from assigning an existing user as Attendant to creating/provisioning a dedicated Attendant account.

### Artifact Conflicts

- The PRD does not yet define the account model clearly.
- The epic breakdown does not currently include role-application stories for LotOwner or Operator.
- The current attendant story implies a role grant on an existing account, which conflicts with the clarified requirement.

## 3. Recommended Approach

Recommended path: Direct Adjustment.

Rationale:

- The MVP direction is still valid.
- The issue is a requirements-definition correction, not a platform or architecture reset.
- Existing implementation planning can continue once the account model is made explicit in PRD and epics.

Effort and risk:

- Effort: medium
- Risk: medium
- Timeline impact: manageable, because the changes mainly affect planning artifacts before deep implementation begins

## 4. Detailed Change Proposals

### Change A: Add explicit account model to PRD

Artifact: `prd.md`

NEW:
- Add a dedicated Roles & Account Model section.
- Clarify that Driver/LotOwner/Operator are capabilities reachable from the same public account lifecycle.
- Clarify that Attendant and Admin are separate accounts with separate login.

Rationale:

- This becomes the source of truth for auth, RBAC, and future UI flow decisions.

### Change B: Update PRD functional requirements and journeys

Artifact: `prd.md`

NEW:
- Registration defaults to Driver.
- LotOwner and Operator require application/approval.
- Operator creates Attendant accounts.
- Attendant must log in with dedicated credentials.

Rationale:

- Removes ambiguity before Epic 1 and Epic 3 implementation.

### Change C: Update epic breakdown

Artifact: `planning-artifacts/epics.md`

NEW:
- Keep Story 1.1 focused on default Driver registration.
- Clarify Story 1.2 login behavior.
- Add Story 1.4 Apply to Become Lot Owner.
- Add Story 1.5 Apply to Become Operator.
- Replace Story 3.3 Assign Attendants with Create Attendant Account.

Rationale:

- Epic sequencing remains stable while missing role-transition behavior is captured explicitly.

### Change D: Update sprint tracking

Artifact: `implementation-artifacts/sprint-status.yaml`

NEW:
- Add backlog entries for Stories 1.4 and 1.5.

Rationale:

- Keeps implementation tracking aligned with the updated epic list.

## 5. Implementation Handoff

Handoff target: Product planning artifacts now, then Epic 1 implementation.

Immediate next actions:

1. Finalize PRD wording for the account model.
2. Finalize Epic 1 and Epic 3 story updates.
3. Continue with Story 1.1 implementation under the clarified rule that public signup creates a Driver account only.
4. Plan later work for LotOwner/Operator application flows and dedicated Attendant provisioning.

Success criteria:

- PRD and epics describe one consistent account model.
- Story 1.1 is not overloaded with later role-transition logic.
- Attendant and Admin are treated as separate-account auth flows in all planning artifacts.