# Contracts

Contracts are the stable boundary between independently deployable components.
They are versioned independently from implementation packages.

## Compatibility

- Producers must continue emitting a supported version during migrations.
- Consumers must ignore unknown JSON properties.
- Removing or changing a required property requires a new major contract
  version.
- Every command carries an idempotency key.
- Every event carries correlation, causation, aggregate and schema identifiers.
- Payloads contain references to secrets, never secret values.

Schemas under `events/v1` describe immutable facts. Schemas under `commands/v1`
describe requested work that can be accepted or rejected.
