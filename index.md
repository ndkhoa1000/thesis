# Smart Parking Management System — Project Index

## Core Documentation (BMAD Output)

- **[prd.md](./_bmad-output/prd.md)** - Core product requirements, user stories, and success metrics.
- **[architecture.md](./_bmad-output/architecture.md)** - High-level system design and technical stack overview.
- **[tech-design.md](./_bmad-output/tech-design.md)** - Technical specifications, database schema, and implementation roadmap.

## Supporting Documentation

- **[usecase.md](./project-docs/usecase.md)** - Functional use case diagrams and actor interactions (PlantUML).
- **[erd.md](./project-docs/erd.md)** - Detailed database entity-relationship diagrams and normalization rules.
- **[reference.md](./project-docs/reference.md)** - Vietnamese summary of application actors, journeys, and main flows.

## Current Technical Direction

- **Frontend:** Flutter mobile app.
- **Backend:** Existing FastAPI backend in `backend/`, managed with `uv` and used as the mandatory application server.
- **Database:** PostgreSQL.
- **Media storage:** Cloudinary.
- **Integration rule:** Mobile communicates only with FastAPI. Supabase is excluded from the project architecture.

## Current Delivery Status

- **Epic 0:** Foundation complete and runnable.
- **Mobile state:** Flutter app currently proves local map/bootstrap flow and still needs backend-auth and API integration work.
- **Next implementation focus:** Epic 1 (User Identity & Profiles).

---
*Generated via `bmad-index-docs`*
