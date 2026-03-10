# Linode deploy

This repository ships a container-first Linode setup in `deploy/linode/`.

## Assumptions

- Run a single application node by default.
- TLS is terminated at Linode NodeBalancer or another edge proxy.
- The app keeps reminders and Connect Four rooms in memory, so active-active
  multi-node routing is not safe yet.

## Files

- `compose.yaml`: builds and runs the Phoenix release with Docker Compose
- `.env.example`: required runtime environment variables

## Quick start

```bash
cd /path/to/test-elixir
cp deploy/linode/.env.example deploy/linode/.env
$EDITOR deploy/linode/.env
docker compose -f deploy/linode/compose.yaml up -d --build
```

## Health checks

Use `GET /healthz` for NodeBalancer HTTP health checks.

## Multi-node note

If you want multiple app nodes later, first move room/reminder state out of the
current in-memory processes or add node-aware room routing.
