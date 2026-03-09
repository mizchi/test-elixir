# TestElixir

Phoenix-based JSON API for reminders, backed by a small in-memory OTP service.

## Design

- `TestElixir.Reminders` contains pure domain logic.
- `TestElixir.Reminders.Server` owns mutable state in a supervised `GenServer`.
- `TestElixirWeb` is the Phoenix boundary for routing, controllers, and JSON contracts.
- Tests are split into domain tests and HTTP contract tests.

## Setup

```bash
cd /Users/mz/sandbox/test-elixir
mix setup
```

With `just`:

```bash
just setup
```

## Start the server

```bash
mix phx.server
```

Or with IEx:

```bash
iex -S mix phx.server
```

The server listens on `http://localhost:4000`.

Opening `http://localhost:4000/` in a browser now shows a small landing page
with the available API routes.

## API

List reminders:

```bash
curl http://127.0.0.1:4000/api/reminders
```

Create a reminder:

```bash
curl -X POST http://127.0.0.1:4000/api/reminders \
  -H 'content-type: application/json' \
  -d '{"title":"Pay rent","due_on":"2026-03-15"}'
```

Complete a reminder:

```bash
curl -X PATCH http://127.0.0.1:4000/api/reminders/1/complete
```

## Quality

```bash
mix quality
```

The alias runs:

- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `mix test`

For static analysis with Dialyzer:

```bash
mix typecheck
```

The first run builds PLTs, so it is significantly slower than normal tests.

Task shortcuts via `just`:

```bash
just quality
just typecheck
just ci
```
