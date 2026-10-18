# Agent guidelines

## Project and sources of truth

This repository contains a Rails 8.1.4 API-only application with Ruby 3.4.11, PostgreSQL 18.6, Kafka 4.2.2, Minitest, and Docker Compose. The current resource is `User`; the API also provides `GET /health`.

- See [README.md](README.md) for setup, execution, and local operation.
- See [openapi/v1/openapi.yaml](openapi/v1/openapi.yaml) for the published HTTP contract and [config/routes.rb](config/routes.rb) for the actual routes.
- See [SDD.md](SDD.md) and [docs/adr/](docs/adr/) for the initial design and decisions. The SDD is historical and describes plans made before implementation.
- Code and tests determine current behavior if documentation becomes outdated. Update the documentation when changing that behavior.
- Write all documentation in English, including README files, ADRs, OpenAPI prose, and documentation comments.

## Environment and commands

Use the Dev Container or Docker Compose; run Rails commands in the `app` container. Compose starts the `db` service automatically when needed. The Dev Container installs Ruby LSP and Rails Fast Nav through `customizations.vscode.extensions`; rebuild the container in VS Code after changing that configuration.

```sh
docker compose up -d --build app
docker compose run --rm app bin/rails db:prepare
docker compose run --rm app bin/rails test
docker compose run --rm app bundle exec rubocop
```

When changing `Gemfile`, run `bundle install` in the container, update `Gemfile.lock`, and rebuild the image. Use migrations for database changes and keep `db/schema.rb` consistent. Compose credentials are only for local development; do not commit secrets.

## API contract

- Keep API requests and responses in JSON. User POST and PUT requests contain a root `user` object.
- Preserve status codes and the error format (`code`, `message`, `traceId`, and `fieldErrors` for validation failures). Do not expose internal details in responses.
- `DELETE /api/v1/users` removes the entire collection and must only be routed in `development` and `test`. Do not expose it in production without an explicit authorization decision.
- `/health` checks PostgreSQL: it responds with `UP` and 200, or `DOWN` and 503. Log failure details only in the server logs.
- Avoid logging request bodies, credentials, or secrets. Structured logs must preserve the request ID for correlation.
- User changes must create events in `user_events` in the same transaction. The `event_dispatcher` publishes pending events to `user.events.v1`; preserve `eventId`, `action`, `occurredAt`, and the `user` snapshot. Delivery is at least once, so consumers must deduplicate by `eventId`.
- Deleting the collection must create one event per user. Invalid requests must not create events. When changing this flow, update model, integration, and publisher tests.

## Swagger / OpenAPI

The `rswag-api` and `rswag-ui` gems publish the UI at `/api-docs` and the specification at `/api-docs/v1/openapi.yaml`. The source file is [openapi/v1/openapi.yaml](openapi/v1/openapi.yaml). Keep examples, schemas, responses, and environment restrictions aligned with the routes and controllers. When changing the contract, also update [README.md](README.md) and the documentation integration test at [test/integration/api_docs_test.rb](test/integration/api_docs_test.rb).

## Implementation and verification

Follow Rails conventions. Keep controllers focused on input and responses; put validation and domain rules in the model or dedicated objects when complexity warrants them. Use Minitest model and integration tests for observable behavior, including relevant error cases. Before finishing code or contract changes, run the test suite and RuboCop.
