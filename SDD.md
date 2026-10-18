# Software Design Document — Ruby on Rails REST API

**Status:** Draft  
**Version:** 0.1  
**Language:** Ruby  
**Framework:** Ruby on Rails (API mode)  
**Database:** PostgreSQL

---

# 1. Overview

This document describes the intended design of a REST API built with Ruby on Rails. The project remains in the design stage; this revision does not include implementation.

The project should prioritize maintainability, testability, clear business rules, predictable local development, observability, and production readiness. Rails conventions are the default. Additional layers and abstractions should be introduced only when a feature needs them.

The initial implementation will establish a Rails API, PostgreSQL integration, a health endpoint, automated tests, structured logging, and a Docker based development environment. A small User feature may serve as a reference vertical slice until the actual project domain is defined.

# 2. Goals

The initial version should provide:

- a JSON REST API using Rails API mode;
- PostgreSQL persistence through Active Record;
- dependency management with Bundler and a committed Gemfile.lock;
- database schema changes through Rails migrations;
- automated tests using Rails' default Minitest framework;
- a consistent JSON error format;
- request correlation and structured logging;
- GET /health;
- Docker Compose for local PostgreSQL;
- a VS Code Dev Container as the default development environment;
- a documented development and deployment workflow.

Business rules should be easy to test without HTTP requests. Controllers should coordinate requests and responses; domain behavior belongs in models or dedicated objects where complexity justifies them.

# 3. Non-goals

The first iteration will not include authentication, authorization, distributed tracing, Kafka, Redis, Kubernetes, service mesh, advanced caching, CQRS, event sourcing, or a generic dependency injection framework. These require separate design decisions when needed.

The reference User resource is not a commitment to a final business domain. No application code, configuration, migrations, or tests are part of this SDD revision.

# 4. Technology Stack

| Concern | Decision |
| --- | --- |
| Language and runtime | A supported stable Ruby version, pinned when implementation starts |
| Web framework | A supported stable Ruby on Rails version in API mode, pinned when implementation starts |
| HTTP server | The Rails generated server configuration, initially Puma |
| Persistence | PostgreSQL through Active Record and the pg gem |
| Dependencies | Bundler, Gemfile, and committed Gemfile.lock |
| Tests | Rails Minitest, including integration tests |
| Code style | RuboCop, with a small documented project configuration if needed |
| Local infrastructure | Docker Compose and a VS Code Dev Container |

Do not add gems when Rails or Ruby already provides a sufficient solution. Exact runtime, framework, and gem versions should be chosen and recorded at bootstrap.

# 5. Architecture

Use a pragmatic Rails architecture:

    HTTP request
        -> route
        -> controller
        -> model or application service
        -> Active Record
        -> PostgreSQL

Responsibilities:

- **Routes and controllers:** Parse requests, select permitted parameters, invoke application behavior, choose HTTP status codes, and render JSON.
- **Models:** Represent persisted data, validations, associations, and cohesive business behavior.
- **Application services:** Coordinate multi-step operations when a controller or model would otherwise become difficult to understand. Use plain Ruby objects and explicit constructor arguments for external collaborators when helpful.
- **Persistence:** Use Active Record queries, transactions, and migrations. Keep SQL out of controllers.
- **Serializers or presenters:** Add them when response mapping becomes substantial; simple responses may use explicit rendering initially.

Add repository interfaces, DTOs, or a separate domain model only when a concrete requirement justifies them. If a feature calls for isolation from Active Record or an external service, define the boundary around that requirement. Avoid placing business rules in controllers, callbacks that hide important behavior, or global mutable state.

# 6. Proposed Project Structure

Start with the standard Rails API layout and add directories when a feature needs them:

    .
    ├── .devcontainer/
    │   ├── devcontainer.json
    │   └── compose.yaml
    ├── app/
    │   ├── controllers/
    │   │   ├── application_controller.rb
    │   │   ├── health_controller.rb
    │   │   └── api/v1/
    │   ├── models/
    │   └── services/                 # when coordination logic warrants it
    ├── config/
    │   ├── database.yml
    │   └── routes.rb
    ├── db/
    │   └── migrate/
    ├── test/
    │   ├── integration/
    │   ├── models/
    │   └── services/                 # when services exist
    ├── Dockerfile
    ├── compose.yaml
    ├── Gemfile
    ├── Gemfile.lock
    ├── README.md
    └── SDD.md

Rails generated files and directories remain part of the application. This outline identifies the important locations; it is not a replacement for the generated structure.

# 7. Database and Migrations

PostgreSQL is the primary relational database. Configure connections through Rails and environment variables. Use Active Record migrations for every schema change and commit the resulting schema representation. Do not rely on automatic schema creation in production.

The reference User feature, if implemented, may use id, name, email, created_at, and updated_at. Use a unique database index for email if email uniqueness is a rule; model validation alone does not protect against concurrent writes. Decide whether UUID or Rails' default primary key best fits the actual domain before creating the first migration.

Use transactions for operations that must succeed or fail together. Surface database errors through application level handling without exposing SQL or connection details to API clients.

# 8. HTTP API

The initial required endpoint is GET /health. On success it returns 200 OK with:

    {"status":"UP"}

Once PostgreSQL is integrated, the health behavior should include a database connectivity check. If that check fails, return 503 Service Unavailable in the same JSON format, with status DOWN. Keep sensitive failure details in logs.

The optional reference resource is versioned under /api/v1/users:

| Method | Path | Intended result |
| --- | --- | --- |
| GET | /api/v1/users | List users, 200 |
| GET | /api/v1/users/:id | Show a user, 200 or 404 |
| POST | /api/v1/users | Create a user, 201 |
| PUT | /api/v1/users/:id | Update a user, 200 or 404 |
| DELETE | /api/v1/users/:id | Delete a user, 204 or 404 |
| DELETE | /api/v1/users | Delete all users, 204 |

The collection delete is destructive. It should be restricted to local or test use until an authorization design exists; it must not be exposed in production without that protection. A missing or already empty collection still returns 204 if the operation is enabled.

Use resource oriented routes and JSON requests and responses. Use 400 for malformed requests, 422 for validation failures, 404 for missing resources, and 409 for conflicts when appropriate. Choose one response shape for validation errors and document it with the first resource. Do not expose stack traces, SQL, filesystem paths, or secrets.

# 9. Error Format

Errors should use a consistent JSON object:

    {
      "code": "USER_NOT_FOUND",
      "message": "User was not found",
      "traceId": "..."
    }

code, message, and traceId are expected. details or fieldErrors may be added for safe, actionable validation information. Map exceptions centrally where possible, while keeping expected domain failures explicit. Rails request IDs can supply the correlation value exposed as traceId.

# 10. Logging and Configuration

Prefer Rails logging and request ID support before adding a logging gem. Logs should include timestamp, severity, message, request ID, method, path, status, and duration where available. Avoid recording sensitive request bodies or credentials.

Environment specific values include the HTTP port, database connection settings, and log level. Rails credentials or external secret injection may be used for secrets; secrets must not be committed. Configuration belongs in the normal Rails configuration files and environment, not hard coded in application behavior.

# 11. Testing and Code Quality

Use Rails Minitest conventions:

- model tests for validations and business behavior;
- service tests when application services exist;
- integration tests for routes, JSON responses, status codes, and error handling;
- database backed tests for queries, constraints, and transactions.

Prefer real test database behavior for persistence tests. Use test doubles for external services or a meaningful boundary, not for Active Record by default. Tests should describe observable behavior and cover failure cases that matter to API clients.

Use RuboCop for consistent formatting and static checks. Keep the configuration focused on readability and the project style.

# 12. Development Environment and Workflow

The default workflow uses VS Code with a Dev Container. The host needs VS Code and Docker. Ruby, Bundler, Rails, and the application test and style commands run inside the development container. Docker Compose starts PostgreSQL alongside it; database data should use a persistent volume. Development credentials are local only and must not be reused for deployment.

Once the application exists, the expected workflow is:

    bundle install
    bin/rails db:prepare
    bin/rails server
    bin/rails test
    bundle exec rubocop

The actual startup commands and Compose service names should be documented in README.md during bootstrap. Production image construction and deployment are separate decisions from the development container.

# 13. Implementation Phases

These phases describe future work. **Do not implement them as part of this documentation change.**

1. **Bootstrap:** Generate a Rails API application, pin Ruby and Rails versions, configure Bundler, PostgreSQL, Minitest, RuboCop, Docker Compose, and the Dev Container. Confirm the app starts and the empty test suite runs.
2. **Health endpoint:** Add GET /health, JSON success and failure responses, and a request test. Add the database check after PostgreSQL is connected.
3. **Persistence:** Configure database environments, migrations, and schema management.
4. **Reference slice:** If still useful, implement User creation first, then the remaining resource operations as needed. Keep controller logic small.
5. **Quality and documentation:** Add relevant model, service, and integration tests; document local setup, error conventions, logging, and deployment assumptions.

# 14. Definition of Done

A future feature is complete when its behavior is documented, relevant tests pass, code style checks pass, schema changes are migrated, HTTP errors follow the agreed format, and business behavior is located outside controllers. Any new infrastructure dependency should have a clear reason and be reflected in this document or an ADR.

# 15. Architectural Decisions

| ID | Decision | Reason |
| --- | --- | --- |
| ADR-001 | Use Ruby on Rails in API mode | Provides routing, JSON APIs, conventions, and a mature application ecosystem. |
| ADR-002 | Use Rails conventions with plain Ruby services when needed | Keeps the design simple while making complex behavior easier to test. |
| ADR-003 | Use PostgreSQL with Active Record migrations | Provides relational persistence and versioned schema changes. |
| ADR-004 | Use Bundler and commit the lockfile | Makes dependency installation reproducible. |
| ADR-005 | Use Rails Minitest | Uses the framework's standard testing support without an extra test stack. |
| ADR-006 | Use a VS Code Dev Container and Docker Compose | Keeps local tooling and PostgreSQL setup consistent. |

When implementation begins, record significant changes as ADRs under docs/adr/. Future decisions include authentication, authorization, OpenAPI, metrics, tracing, rate limiting, pagination, idempotency, secrets management, and production deployment.

# 16. Guiding Constraint

Build a maintainable Rails API that uses framework conventions deliberately. Keep request handling clear, business behavior testable, persistence changes explicit, and operational behavior observable. Add architectural boundaries in response to concrete needs.
