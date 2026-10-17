# EEELibrary

- mobile/: existing Flutter educational book marketplace application.
- admin/: separate Next.js administrator workspace. See [admin setup and trusted provisioning](admin/README.md).
- backend/: NestJS + Prisma backend foundation. See [local setup](backend/README.md).
- compose.yaml: root-level local PostgreSQL/Redis infrastructure.
- infrastructure/: development infrastructure notes.
- docs/: backend schema/architecture contracts.

The backend provides Firebase identity/bootstrap, public catalog, protected purchases/payment review, entitlement-backed Library, and persisted-role admin APIs. GET /api/v1/health is public. The Flutter user app and Next.js admin app remain separate clients of the authoritative backend. See [Firebase authentication setup](docs/firebase-authentication.md).
