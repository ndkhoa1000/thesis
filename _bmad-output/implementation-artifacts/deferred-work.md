## Deferred from: code review of 1-4-apply-to-become-lot-owner (2026-03-27)

- Public capability routing is still role-first in the mobile shell, so future additive-capability stories will likely need explicit workspace switching instead of relying on a single `user.role` landing path.

## Deferred from: code review of 1-5-apply-to-become-operator (2026-03-27)

- Create a dedicated UX hardening story for public/admin shells to standardize navigation, reduce placeholder-first layouts, and finish Vietnamese localization for visible role/workspace labels.
- Prefer a shared shell/navigation pattern before Epic 3 expands the Operator workspace further, otherwise role-specific placeholders will continue to diverge.