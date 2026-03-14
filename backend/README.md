# LockedIn Backend (Hono + Bun)

## Run

```sh
bun install
bun run dev
```

Server starts on `http://localhost:3000`.

## Auth Mode (Dev-friendly)

Auth is optional by default for local development.

- `AUTH_MODE=optional` (default): no auth required; user defaults to `dev-user`.
- `AUTH_MODE=required`: requires `Authorization: Bearer ...` or `X-User-Id`.

## Test

```sh
bun test
```

## Type-check

```sh
bunx tsc --noEmit
```

## API v1

- `POST /v1/profile/onboarding`
- `GET /v1/profile`
- `PATCH /v1/profile`
- `POST /v1/chat`
- `POST /v1/checkins/weekly`
- `GET /v1/lifescore`
