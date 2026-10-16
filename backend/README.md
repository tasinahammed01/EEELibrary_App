# EEELibrary backend

Initial NestJS modular monolith. The Flutter app is independent and unchanged.
GET /api/v1/health remains public. Phase 2A adds protected Firebase ID-token bootstrap and current-user endpoints; see [Firebase setup and API contract](../docs/firebase-authentication.md). Catalog, payments and reader APIs remain future work.

## Local workflow (PowerShell)

Requirements: Docker Desktop running, Node.js 22.13+ on the 22.x line or Node.js 24.x, npm, and available ports 3000, 5433, 6380.
Use npm.cmd/npx.cmd on Windows if execution policy blocks npm.ps1; other shells can use npm/npx.

1. From the repository root, configure the ignored local environment before starting Compose:

```powershell
cd "D:\ALL Projects\EEE_Library_Project\EEELibrary"
Copy-Item backend/.env.example backend/.env
```

Edit backend/.env. Replace the password placeholder with a unique local password and match it in DATABASE_URL. URL-encode the password in the URL (a random hex password needs no encoding). Never commit .env or print its contents. A configured ignored .env already exists in the current workspace; do not overwrite it unless intentionally changing local credentials.

2. Start infrastructure from the repository root:

```powershell
docker compose config --quiet
docker compose up -d --wait
docker compose ps
```

Plain docker compose config also works but prints resolved environment values; do not paste that output into logs or support messages. PostgreSQL is at 127.0.0.1:5433, Redis at 127.0.0.1:6380. Credentials come from backend/.env. See ../infrastructure/README.md.

3. Install and apply committed migrations:

```powershell
cd backend
npm.cmd install
npx.cmd prisma format
npx.cmd prisma validate
npx.cmd prisma generate
npx.cmd prisma migrate deploy
```

On repeat installs use npm.cmd ci for the exact lockfile. Generated client source is ignored and must be generated before build/test. Prisma 7 uses prisma.config.ts for its URL, the PostgreSQL driver adapter, and an explicit CommonJS client. Versions are locked; do not use an unpinned Prisma prerelease from npm latest.

For a future schema change in a disposable/local development database, use npx.cmd prisma migrate dev --name descriptive_change. Review SQL before applying. Never use db push, migrate reset, or delete volumes as a shortcut. Deployment uses migrate deploy with a separate migration role; the application production role must not be a superuser.

4. Validate and run:

```powershell
npm.cmd run format
npm.cmd run lint
npm.cmd test
npm.cmd run test:integration
npm.cmd run build
npm.cmd run start:dev
```

Unit/HTTP tests use fixture configuration and override or spy on database lifecycle methods: no running database or real secrets are required. Integration tests load the ignored local .env and require an already-migrated database. Original schema fixtures are rolled back; auth concurrency tests clean up only their exact randomly generated fixture UIDs. No reset/truncate is used. Never point integration tests at production.

5. In a separate terminal:

```powershell
Invoke-RestMethod http://127.0.0.1:3000/api/v1/health
```

Expected JSON: {"status":"ok"}. This is a process liveness endpoint, not dependency readiness; startup verifies PostgreSQL with one SELECT 1 but ongoing database/Redis availability is not polled by this endpoint. Redis is provisioned only and has no application client yet.

6. Stop the backend with Ctrl+C. From the repository root stop services safely:

```powershell
docker compose stop
```

PostgreSQL named-volume data persists. Do not use down -v, volume prune, or system prune. Changing POSTGRES_PASSWORD in .env does not rotate credentials in an initialized volume: perform an intentional database password rotation and update the URL together.

## Configuration and safety

All required values validate at startup without echoing their values. PORT defaults to 3000, NODE_ENV to development, and empty CORS_ORIGINS denies cross-origin browser access. Use a comma-separated list of exact origins with no trailing slash/path/wildcard. Production browser origins must use HTTPS. Native clients without Origin work normally. CORS is a browser policy, never authentication/authorization.

The HTTP server binds to loopback for local development, applies Helmet, 16 KiB JSON/form limits, strict DTO whitelisting without implicit conversion, and sanitized error responses. Application startup failures and unexpected request errors log generic messages rather than raw driver errors, bodies or environment values. New APIs must deliberately add safe actionable domain errors/structured redacted logging.

The Prisma provider is exported once from PrismaModule, with one pool (maximum 10 connections), bounded connection timeout, startup connection and shutdown disconnect. Import the module, not a new client per request. enableShutdownHooks handles graceful process signals supported by the host; Windows forced termination cannot guarantee hooks.

Firebase configuration is optional for infrastructure-only startup but required to enable authentication. Set the real FIREBASE_PROJECT_ID and configure ADC as documented above; no real Firebase credentials are required by tests.

For production, add TLS/reverse proxy, restricted application DB role, secret management, backups, deployment readiness, Redis ACL/TLS/durability, and rate limiting before exposing future endpoints. This development Compose stack is not a production deployment.

See ../docs/backend-architecture.md for schema invariants and the next phases. Dependencies follow the [official NestJS Prisma 7 integration](https://docs.nestjs.com/recipes/prisma).
