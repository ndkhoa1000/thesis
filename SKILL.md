---
name: backend-implementation-map
description: Fast reference map for implementing backend features in the existing FastAPI boilerplate-based backend.
---

# Instructions

Use this file as the fastest orientation map when implementing or modifying backend features in this repository.

The backend is in [backend](backend). It is based on the Benav Labs FastAPI Boilerplate and already provides the runtime, configuration, auth primitives, database integration pattern, CRUD conventions, and deployment setup. New parking-system features should adapt that structure rather than bypass it.

## Core Rule

For backend feature work in this repo:

1. Start from the existing backend structure in [backend/src/app](backend/src/app).
2. Use the docs in [backend/docs](backend/docs) as the implementation map.
3. Prefer extending the boilerplate patterns over inventing new ones.

## Backend Mental Model

The backend layers are:

1. API routes in [backend/src/app/api](backend/src/app/api)
2. Shared dependencies and configuration in [backend/src/app/core](backend/src/app/core)
3. Database models in [backend/src/app/models](backend/src/app/models)
4. Pydantic schemas in [backend/src/app/schemas](backend/src/app/schemas)
5. CRUD data access in [backend/src/app/crud](backend/src/app/crud)
6. Migrations in [backend/src/migrations](backend/src/migrations)
7. Tests in [backend/tests](backend/tests)

## Fast Lookup Table

### When adding a new domain feature

Read first:

- [backend/docs/user-guide/project-structure.md](backend/docs/user-guide/project-structure.md)
- [backend/docs/user-guide/development.md](backend/docs/user-guide/development.md)
- [backend/docs/user-guide/api/endpoints.md](backend/docs/user-guide/api/endpoints.md)
- [backend/docs/user-guide/database/index.md](backend/docs/user-guide/database/index.md)

Then touch these code areas in order:

1. model in [backend/src/app/models](backend/src/app/models)
2. schema in [backend/src/app/schemas](backend/src/app/schemas)
3. CRUD module in [backend/src/app/crud](backend/src/app/crud)
4. route module in [backend/src/app/api/v1](backend/src/app/api/v1)
5. router registration in [backend/src/app/api/v1/__init__.py](backend/src/app/api/v1/__init__.py)
6. migration in [backend/src/migrations](backend/src/migrations)
7. tests in [backend/tests](backend/tests)

### When changing configuration or environment variables

Read:

- [backend/docs/user-guide/configuration/index.md](backend/docs/user-guide/configuration/index.md)
- [backend/docs/user-guide/configuration/environment-variables.md](backend/docs/user-guide/configuration/environment-variables.md)
- [backend/docs/user-guide/configuration/settings-classes.md](backend/docs/user-guide/configuration/settings-classes.md)
- [backend/docs/user-guide/configuration/docker-setup.md](backend/docs/user-guide/configuration/docker-setup.md)

Check code:

- [backend/src/app/core/config.py](backend/src/app/core/config.py)
- [backend/docker-compose.yml](backend/docker-compose.yml)
- [backend/src/.env](backend/src/.env)

### When adding authentication or authorization logic

Read:

- [backend/docs/user-guide/authentication/index.md](backend/docs/user-guide/authentication/index.md)
- [backend/docs/user-guide/authentication/jwt-tokens.md](backend/docs/user-guide/authentication/jwt-tokens.md)
- [backend/docs/user-guide/authentication/user-management.md](backend/docs/user-guide/authentication/user-management.md)
- [backend/docs/user-guide/authentication/permissions.md](backend/docs/user-guide/authentication/permissions.md)

Check code:

- [backend/src/app/api/dependencies.py](backend/src/app/api/dependencies.py)
- [backend/src/app/core/security.py](backend/src/app/core/security.py)
- [backend/src/app/api/v1/login.py](backend/src/app/api/v1/login.py)
- [backend/src/app/api/v1/logout.py](backend/src/app/api/v1/logout.py)
- [backend/src/app/api/v1/users.py](backend/src/app/api/v1/users.py)

### When adding or changing database models

Read:

- [backend/docs/user-guide/database/models.md](backend/docs/user-guide/database/models.md)
- [backend/docs/user-guide/database/schemas.md](backend/docs/user-guide/database/schemas.md)
- [backend/docs/user-guide/database/crud.md](backend/docs/user-guide/database/crud.md)
- [backend/docs/user-guide/database/migrations.md](backend/docs/user-guide/database/migrations.md)

Check code:

- [backend/src/app/core/db/database.py](backend/src/app/core/db/database.py)
- [backend/src/app/core/db/models.py](backend/src/app/core/db/models.py)
- [backend/src/app/models](backend/src/app/models)
- [backend/src/app/schemas](backend/src/app/schemas)
- [backend/src/app/crud](backend/src/app/crud)

### When creating API endpoints

Read:

- [backend/docs/user-guide/api/index.md](backend/docs/user-guide/api/index.md)
- [backend/docs/user-guide/api/endpoints.md](backend/docs/user-guide/api/endpoints.md)
- [backend/docs/user-guide/api/pagination.md](backend/docs/user-guide/api/pagination.md)
- [backend/docs/user-guide/api/exceptions.md](backend/docs/user-guide/api/exceptions.md)

Check code:

- [backend/src/app/api/v1](backend/src/app/api/v1)
- [backend/src/app/core/exceptions/http_exceptions.py](backend/src/app/core/exceptions/http_exceptions.py)

### When adding background jobs or scheduled work

Read:

- [backend/docs/user-guide/background-tasks/index.md](backend/docs/user-guide/background-tasks/index.md)

Check code:

- [backend/src/app/core/worker/functions.py](backend/src/app/core/worker/functions.py)
- [backend/src/app/core/worker/settings.py](backend/src/app/core/worker/settings.py)
- [backend/src/app/core/utils/queue.py](backend/src/app/core/utils/queue.py)
- [backend/src/app/api/v1/tasks.py](backend/src/app/api/v1/tasks.py)

### When adding caching

Read:

- [backend/docs/user-guide/caching/index.md](backend/docs/user-guide/caching/index.md)
- [backend/docs/user-guide/caching/redis-cache.md](backend/docs/user-guide/caching/redis-cache.md)
- [backend/docs/user-guide/caching/client-cache.md](backend/docs/user-guide/caching/client-cache.md)
- [backend/docs/user-guide/caching/cache-strategies.md](backend/docs/user-guide/caching/cache-strategies.md)

Check code:

- [backend/src/app/core/utils/cache.py](backend/src/app/core/utils/cache.py)
- [backend/src/app/middleware/client_cache_middleware.py](backend/src/app/middleware/client_cache_middleware.py)

### When writing tests

Read:

- [backend/docs/user-guide/testing.md](backend/docs/user-guide/testing.md)

Check code:

- [backend/tests/conftest.py](backend/tests/conftest.py)
- [backend/tests/test_user.py](backend/tests/test_user.py)
- [backend/tests/helpers/generators.py](backend/tests/helpers/generators.py)
- [backend/tests/helpers/mocks.py](backend/tests/helpers/mocks.py)

## Recommended Implementation Sequence

For a new parking-domain backend feature, work in this order:

1. Confirm the target behavior from [_bmad-output/prd.md](_bmad-output/prd.md), [_bmad-output/architecture.md](_bmad-output/architecture.md), and [_bmad-output/tech-design.md](_bmad-output/tech-design.md)
2. Read the relevant backend docs from [backend/docs](backend/docs)
3. Create or update the SQLAlchemy model
4. Create or update Pydantic schemas
5. Add CRUD access logic
6. Add or update route handlers and dependencies
7. Register the router
8. Generate and apply Alembic migration
9. Add or update tests
10. Run errors or tests before moving on

## Repo-Specific Adaptation Notes

This repo is moving from boilerplate examples to the parking domain.

That means:

- generic modules like posts, tiers, and rate limits are reference patterns, not the target business domain
- new parking features should follow their structure, then replace them over time
- auth remains backend-owned
- PostgreSQL is the database of record
- Cloudinary should be integrated as a backend service, not called directly from the mobile app with privileged credentials

## Task-to-Doc Map

| Task | Primary docs |
|------|--------------|
| Add entity | `project-structure.md`, `development.md`, `database/models.md`, `database/schemas.md`, `database/crud.md`, `database/migrations.md` |
| Add endpoint | `api/endpoints.md`, `api/exceptions.md`, `api/pagination.md` |
| Add auth rule | `authentication/index.md`, `authentication/jwt-tokens.md`, `authentication/permissions.md` |
| Add config | `configuration/index.md`, `environment-variables.md`, `settings-classes.md` |
| Add background job | `background-tasks/index.md` |
| Add cache | `caching/index.md`, `cache-strategies.md` |
| Add tests | `testing.md` |

## Minimal Working Checklist

Before calling a backend feature done, verify:

1. route exists and is registered
2. request and response schemas exist
3. model or persistence path exists
4. migration exists if schema changed
5. auth and permission checks are correct
6. tests cover the happy path and key failure path
7. docs or comments are updated only where needed
