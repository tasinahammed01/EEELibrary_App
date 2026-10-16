# Local infrastructure

The main development definition is ../compose.yaml so plain docker compose commands work at repository root.

- PostgreSQL 17 Alpine: loopback host port 5433, persistent eeelibrary_postgres_data named volume, pg_isready health check, 512 MiB memory ceiling, 64 MiB shared buffers, 50 connections.
- Redis 8 Alpine: loopback host port 6380, PING health check, 128 MiB container ceiling, 64 MiB maxmemory, noeviction. Redis is ephemeral in this phase (no snapshots/AOF); no session or security state depends on it.
- No Flutter/backend container and no application Redis connection.
- backend/.env is required. The Compose project name is eeelibrary. Do not print resolved Compose configuration containing credentials.

Both ports bind to 127.0.0.1. Containers retain their default private Compose network. Redis has no authentication in this isolated development configuration; it must not be used on a public/untrusted host or treated as production Redis.

Start: docker compose up -d --wait. Inspect: docker compose ps. Stop preserving data: docker compose stop. Never delete volumes to resolve a startup error; check Docker availability, port collisions and credential alignment first.

Versioned major image tags receive compatible updates; the Node dependency lockfile pins resolved packages. Production images should be digest-pinned and upgraded deliberately.
