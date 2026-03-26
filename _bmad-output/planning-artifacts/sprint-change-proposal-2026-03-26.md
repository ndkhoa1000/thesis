# Sprint Change Proposal

Date: 2026-03-26
Project: thesis
Scope Classification: Minor

## 1. Issue Summary

The project foundation has stabilized, and Epic 0 is effectively complete. During implementation, the frontend direction changed from React Native/Expo to Flutter. Core planning documents already reflect Flutter, but some indexing and execution artifacts still lag behind the current codebase state.

The immediate issue is not a product-direction change. It is an execution-tracking and documentation-drift problem:

- planning artifacts do not clearly mark Epic 0 as complete
- there is no sprint tracking file for implementation workflows
- the project index still reports React Native/Expo as the frontend direction
- the mobile codebase remains at bootstrap/mock-map stage and is ready to move into backend-auth integration work

## 2. Impact Analysis

### Epic Impact

- Epic 0: status should be treated as complete
- Epic 1: becomes the next active delivery target
- Later epics: no scope change required at this time

### Story Impact

- No existing story needs to be rewritten
- Story 1.1 User Registration should become the next created story
- Story 1.2 User Login should follow immediately after Story 1.1 because both share the same backend-auth contract work

### Artifact Conflicts

- `index.md` still references React Native/Expo even though PRD and architecture now specify Flutter
- `epic-0.md` still reports Draft despite the user-confirmed completion state
- implementation tracking artifacts were missing entirely

### Technical Impact

- No architecture rollback is needed
- No PRD rewrite is needed
- Mobile bootstrap code still needs a later normalization pass for environment variable naming and backend API integration, but that is implementation work for Epic 1 rather than a planning blocker

## 3. Recommended Approach

Recommended path: Direct Adjustment.

Rationale:

- The product direction is stable
- The architecture already supports Flutter + FastAPI
- The mismatch is limited to tracking and stale documentation
- The next meaningful work item is implementation, not replanning

Effort and risk:

- Effort: low
- Risk: low
- Timeline impact: positive, because the team can move directly into Epic 1 with a clean sprint status baseline

## 4. Detailed Change Proposals

### Change A: Mark Epic 0 complete

Artifact: `planning-artifacts/epic-0.md`

OLD:
- `status: Draft`

NEW:
- `status: Done`
- add completion notes clarifying that backend scaffold and Flutter bootstrap are complete, and that Epic 1 starts the backend-auth integration phase

Rationale:

- This matches actual project status and prevents routing ambiguity in future BMad workflows.

### Change B: Align project index with Flutter

Artifact: `index.md`

OLD:
- Frontend listed as React Native mobile app with Expo

NEW:
- Frontend listed as Flutter mobile app
- add a short delivery-status section that states Epic 0 is complete and Epic 1 is next

Rationale:

- The index is the top-level routing document and should not contradict the PRD or architecture.

### Change C: Create sprint tracking baseline

Artifact: `implementation-artifacts/sprint-status.yaml`

OLD:
- file did not exist

NEW:
- full sprint status inventory for Epic 0 through Epic 9
- Epic 0 initialized as `done`
- all future stories initialized as `backlog`

Rationale:

- Implementation workflows need a shared tracking source before story creation and development work begin.

## 5. Implementation Handoff

Handoff target: Development workflow in BMad Method.

Immediate next actions:

1. Create Story for Story 1.1 User Registration
2. Validate Story 1.1 before development
3. Develop Story 1.1 with backend-auth contract as the primary deliverable
4. Follow with Story 1.2 User Login while reusing the same token/auth foundation

Success criteria:

- Sprint tracking is present and up to date
- Top-level docs no longer contradict the chosen frontend stack
- The next implementation session can begin directly from Epic 1 without re-deciding architecture