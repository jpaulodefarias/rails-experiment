# ADR 001: API technical foundation

**Status:** Accepted for the initial setup.

The application uses Rails 8.1.4 in API-only mode, Ruby 3.4.11, Active Record with PostgreSQL 18.6, Minitest, and RuboCop. User primary keys use Rails' default integer type. The local environment uses Docker Compose and a VS Code Dev Container. The user resource serves as a reference until the final domain is defined.

Rails handles routes, controllers, models, migrations, and HTTP error handling. Service objects will be introduced when rule coordination becomes complex enough to warrant them. The route that deletes the entire collection exists only in the `development` and `test` environments.
