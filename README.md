# EEELibrary

- mobile/: existing Flutter educational book marketplace application.
- backend/: NestJS + Prisma backend foundation. See [local setup](backend/README.md).
- compose.yaml: root-level local PostgreSQL/Redis infrastructure.
- infrastructure/: development infrastructure notes.
- docs/: backend schema/architecture contracts.

The backend includes its foundation and Phase 2A Firebase identity/bootstrap. GET /api/v1/health is public; POST /api/v1/auth/bootstrap and GET /api/v1/auth/me are protected. The mobile application is unchanged. See [Firebase authentication setup](docs/firebase-authentication.md).
