# Rails Experiment API

A REST API built with Rails 8.1, Ruby 3.4, and PostgreSQL 18. The original design and decisions are in [SDD.md](SDD.md).

## Development

Use VS Code with the Dev Containers extension and Docker Desktop. Open this folder in the Dev Container. Compose starts the application, PostgreSQL, Kafka, and the event dispatcher; the setup command prepares the database. The API is available at `http://localhost:3000`.

The Dev Container automatically installs **Ruby LSP** (analysis, navigation, formatting, and Rails support) and **Rails Fast Nav** (navigation between Rails files). After changing `.devcontainer/devcontainer.json`, run **Dev Containers: Rebuild Container** in VS Code to install the extensions. Ruby LSP may create a local `.ruby-lsp/` directory, which Git ignores.

From a terminal inside the container:

```sh
bundle install
bin/rails db:prepare
bin/rails server -b 0.0.0.0
bin/rails test
bundle exec rubocop
```

Without VS Code, run `docker compose run --build --rm app bundle install`, then `docker compose run --rm app bin/rails db:prepare`, and finally `docker compose up`. To run tests, use `docker compose run --rm app bin/rails test`. Local database data is stored in the `pgdata` volume. The `rails_local_only` password is for local development only.

When changing dependencies, run `bundle install` and include the updated `Gemfile.lock` in version control. The development and production images use this file for reproducible installs.

## User events in Kafka

Every successful user creation, meaningful update, or deletion writes an event to `user_events` in the same database transaction. An update that leaves the user's name and email unchanged creates no event. Deleting the entire collection writes one `deleted` event for each removed user. Invalid requests do not create events. A separate `event_dispatcher` process publishes pending events to the `user.events.v1` topic. The Kafka key is the user ID as a string, so events for the same user go to the same partition. User writes must use Active Record methods that run callbacks; bulk SQL methods bypass the outbox.

Example JSON message:

```json
{
  "eventId": "60db76d2-cf72-4ea2-94a2-997294407826",
  "action": "updated",
  "occurredAt": "2026-10-17T21:00:00.000Z",
  "user": {
    "id": 1,
    "name": "Ana",
    "email": "ana@example.com",
    "created_at": "2026-10-17T20:00:00.000Z",
    "updated_at": "2026-10-17T21:00:00.000Z"
  }
}
```

For `deleted` events, `user` contains the last values before deletion. An HTTP response confirms that the user change and its outgoing event were committed to PostgreSQL; it does not confirm Kafka delivery. Failed deliveries stay pending and are retried with exponential backoff, capped at five minutes. A failed event blocks later events for the same user until it succeeds, while other users continue. Delivery is **at least once**: a failure after Kafka acknowledges a message but before the event is marked as published can produce a duplicate. Consumers should deduplicate by `eventId`.

Compose creates the topic and keeps Kafka data in a local volume. To inspect events, run `docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic user.events.v1 --from-beginning --formatter-property print.key=true`. Outside Compose, configure the dispatcher with `KAFKA_BOOTSTRAP_SERVERS` and `KAFKA_TOPIC`. In production, create the topic in the managed cluster and run `bin/dispatch_user_events` as a separate process after migrations. Concurrent dispatchers preserve order per user. Monitor pending rows, `attempts`, `next_attempt_at`, and `last_error_class` in `user_events`, as well as `user_event_delivery_failed` and `user_event_stalled` log entries. An event remains pending until it succeeds; investigate stalled events rather than deleting them.

## HTTP contract

API routes use JSON. `GET /health` checks PostgreSQL and returns `{"status":"UP"}` with 200 or `{"status":"DOWN"}` with 503. Detailed failure information appears only in logs.

| Method | Route | Result |
| --- | --- | --- |
| GET | `/api/v1/users` | Up to 50 users by default; 200 or 400 |
| GET | `/api/v1/users/:id` | User; 200 or 404 |
| POST | `/api/v1/users` | Create a user; 201 or 422 |
| PUT | `/api/v1/users/:id` | Update the supplied fields; 200, 404, or 422 |
| DELETE | `/api/v1/users/:id` | Delete a user; 204 or 404 |
| DELETE | `/api/v1/users` | Delete all users; 204, only in development/test |

Use `GET /api/v1/users?limit=50&after_id=123` to page through users. `limit` accepts 1–100 and defaults to 50; `after_id` defaults to 0. The response remains an array ordered by `id`. Use the last returned ID as `after_id` for the next page; an empty array ends the scan. Invalid pagination values return 400. Send `{"user":{"name":"Ana","email":"ana@example.com"}}` with POST and PUT. Name and email are required on creation. Email is normalized to lowercase and must be valid and unique regardless of case. User responses contain `id`, `name`, `email`, `created_at`, and `updated_at`.

Errors use `{"code":"VALIDATION_FAILED","message":"User is invalid","traceId":"...","fieldErrors":{"email":["..."]}}`. `fieldErrors` appears for validation failures. Malformed JSON or a missing `user` object returns 400; a missing user or route returns 404; validation failures return 422; a conflict detected by the unique index returns 409; unexpected failures return 500 without internal details. `traceId` matches the Rails request ID.

## Configuration and operations

`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME` configure PostgreSQL. `PORT`, `RAILS_MAX_THREADS`, and `LOG_LEVEL` configure the application. In production, also inject `SECRET_KEY_BASE` securely. Compose supplies local credentials only.

JSON logs include time, severity, and message; HTTP events include request ID, method, path, status, and duration. Do not log request bodies or credentials. For a future deployment, provide managed PostgreSQL, run `bin/rails db:migrate` before serving traffic, and monitor `/health` and the logs. Platform selection, secret management, and publishing are outside this project scope.

## Swagger / OpenAPI

With the application running, open `http://localhost:3000/api-docs` to explore and test routes in Swagger UI. The OpenAPI 3.0 specification is in [openapi/v1/openapi.yaml](openapi/v1/openapi.yaml) and is also served at `http://localhost:3000/api-docs/v1/openapi.yaml`. The UI uses the application's own origin, so **Try it out** sends requests to the local API.

`DELETE /api/v1/users`, which removes the entire collection, exists only in `development` and `test`; in `production` it returns 404.
