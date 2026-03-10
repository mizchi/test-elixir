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

For the browser-based Connect Four UI, open:

```text
http://localhost:4000/connect-four
```

Create a room in the lobby, then open the same room URL in a second browser
window with another `player_id`.

A third browser can join the same room as a spectator. Spectators receive live
updates but cannot drop tokens.

## API

Create a Connect Four room:

```bash
curl -X POST http://127.0.0.1:4000/api/connect-four/rooms
```

Then connect players to the returned topic over Phoenix Channels:

```text
ws://127.0.0.1:4000/socket/websocket?vsn=2.0.0&player_id=alice
```

Reconnect with the same `player_id` to reclaim the same seat after a disconnect.

Join topic:

```json
["1","1","connect_four:ROOM_ID","phx_join",{}]
```

Drop a token:

```json
["2","2","connect_four:ROOM_ID","drop_token",{"column":0}]
```

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
just docker-build
```

## Benchmark

Start the server in one shell:

```bash
just server
```

Then run k6 in another shell:

```bash
just bench-http
just bench-channel
just bench-game
just bench-spectator
just bench-soak
just bench-wasm
```

Both scripts accept k6-style environment overrides:

```bash
VUS=20 DURATION=30s just bench-http
VUS=50 DURATION=20s just bench-channel
VUS=10 DURATION=20s just bench-game
VUS=10 DURATION=20s just bench-spectator
just bench-soak
FIB_INPUT=20 BENCH_TIME_S=3 just bench-wasm
```

`bench-http` measures the landing page, LiveView lobby HTML, reminders API, and
Connect Four room creation. `bench-channel` measures room creation plus Phoenix
Channel join latency for Connect Four. `bench-game` creates a room, joins Alice
and Bob over separate WebSockets, and plays a fixed 7-move match until red
wins. `bench-spectator` adds Carol as a spectator, verifies that spectator
actions are rejected, and measures how quickly match updates fan out to the
spectator socket. `bench-soak` is a longer-running wrapper around
`bench-spectator` with defaults tuned for local soak runs.

The spectator benchmarks also emit soak-friendly counters in the default k6
summary:

- `rooms_created_total`
- `spectator_matches_completed_total`
- `spectator_state_updates_total`
- `spectator_rejections_total`
- `match_moves_sent_total`

`bench-wasm` compares two Elixir-side Wasm execution paths against the same
fixture module in `priv/wasm/sample.wat`:

- `Wasmex`, which embeds Wasmtime through a Rust NIF
- `Port + native wasmtime host`, which keeps Wasmtime in an external process

The first run builds the native host under `native/wasmtime_host/` with Cargo.
The benchmark prints two sections:

- `cold_add`: start runtime + one `add/2` call
- `hot_add` / `hot_fib`: repeated calls against already-started runtimes

## Deploy

This repository now includes both `Fly.io` and `Linode` deployment settings.
Both paths use the same release-oriented [Dockerfile](/Users/mz/sandbox/test-elixir/Dockerfile).

### Shared constraints

- `GET /healthz` is available for load balancer and platform health checks.
- The current reminders store and Connect Four rooms live in memory.
- Because of that, production should stay on a single app node unless you
  externalize state or add node-aware room routing.

### Fly.io

- Config file: [fly.toml](/Users/mz/sandbox/test-elixir/fly.toml)
- Release env hooks: [rel/env.sh.eex](/Users/mz/sandbox/test-elixir/rel/env.sh.eex)
- Default region: `nrt` (Tokyo)

Typical flow:

```bash
fly auth login
fly apps create mizchi-test-elixir
fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)"
fly deploy
```

You will probably want to change `app` and `PHX_HOST` in
[fly.toml](/Users/mz/sandbox/test-elixir/fly.toml) if `mizchi-test-elixir` is
already taken.

`ENABLE_DISTRIBUTED_ERLANG` is intentionally `false` by default. Turn it on
only after you externalize state or add node-aware room routing, and then set a
shared `RELEASE_COOKIE` secret.

### Linode

- Compose setup: [deploy/linode/compose.yaml](/Users/mz/sandbox/test-elixir/deploy/linode/compose.yaml)
- Env template: [deploy/linode/.env.example](/Users/mz/sandbox/test-elixir/deploy/linode/.env.example)
- Deployment notes: [deploy/linode/README.md](/Users/mz/sandbox/test-elixir/deploy/linode/README.md)

Typical flow:

```bash
cp deploy/linode/.env.example deploy/linode/.env
$EDITOR deploy/linode/.env
docker compose -f deploy/linode/compose.yaml up -d --build
```

For Linode NodeBalancer, point HTTP health checks at `/healthz`. TLS
termination can stay at the balancer while Phoenix serves plain HTTP on port
`4000`.

Keep `ENABLE_DISTRIBUTED_ERLANG=false` for the current single-node setup.
