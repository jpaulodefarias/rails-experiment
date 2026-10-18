# ADR 002: User events in Kafka

**Status:** Accepted.

Creating, updating, and deleting users creates a record in `user_events` in the same transaction as the change. A separate process reads pending records and publishes JSON messages to the Kafka topic `user.events.v1`, using the user ID as the key. The local route that deletes the collection destroys each record to generate one event per user.

This outbox retains events when Kafka is unavailable and permits retries without rolling back a change already confirmed by the API. Failures are stored with an attempt count, error class, and next attempt time. Retry delays grow exponentially up to five minutes. A failed event remains pending, so later events for the same user wait while other users can progress. The dispatcher checks earlier pending events even when multiple workers run concurrently, preserving per-user order. Delivery is at least once: if Kafka acknowledges a message and the process fails before marking the record as published, the message may be sent again. The `eventId` field enables consumer deduplication.

The publisher must run continuously in production. Monitor pending events, attempt counts, retry times, and `user_event_stalled` logs. Writes to users must use Active Record operations that execute callbacks; bulk SQL operations do not create outbox events. Compose provides a single broker for local development only.
