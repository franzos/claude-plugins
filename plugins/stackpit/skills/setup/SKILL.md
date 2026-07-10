---
name: setup
description: Use to set up a new Stackpit deployment (the self-hosted, single-binary drop-in for Sentry event ingestion), with or without Docker and on SQLite or Postgres. Runs the init template, sets the load-bearing config (bind addresses, external URLs, admin token, master key, filter mode), points SDKs at the ingest listener, and verifies the instance boots and accepts events. Triggers: installing Stackpit, first-time setup, standing up Stackpit, getting Stackpit running, self-hosting Sentry replacement.
---

# Setting up Stackpit

Stackpit is a single Rust binary backed by one SQLite file (Postgres optional), with two HTTP listeners in one process: an **admin listener** (web UI + JSON API, default `127.0.0.1:3000`) and an **ingestion listener** (SDK traffic, default `0.0.0.0:3001`). Do not hardcode the schema from memory: `docs/operator-guide.md` and the `stackpit init` template are the source of truth. Read them from the deployment you are working on.

Work through these in order. Confirm the choice at each fork with the user rather than guessing.

## 1. Locate the deployment and pick a shape

Find what you are working with: a repo checkout (`docs/operator-guide.md`, `README.md`, `SCALING.md`), a package install (`cargo install stackpit`, Homebrew, `.deb`/`.rpm`, Guix), or a container image (`ghcr.io/franzos/stackpit`, or `-postgres`). Then pick the shape and confirm it:

- **Docker**: single multi-stage `Dockerfile`, backend chosen at build via `ARG DB_FEATURE=sqlite|postgres`; two published image variants (`:latest` SQLite, `:latest-postgres`). `EXPOSE 3000 3001`, healthcheck on `:3001/health`. There is **no `docker-compose.yml`** in the repo, only Dockerfile guidance; generating one is net-new, do it only if the user wants it.
- **Native**: install via package or `cargo build --release`. Backends are **mutually-exclusive cargo features** (`--no-default-features --features sqlite` or `--features postgres`; default is `sqlite`). Guix dev toolchain is `manifest.scm` + `.envrc`.

Read the install and first-boot sections of `README.md` and the config reference in `docs/operator-guide.md` before proceeding.

## 2. Provision the toolchain (native builds only)

If building from source, get a toolchain without touching the host: invoke the `provision-environment` skill (prefer the project `manifest.scm` via `guix shell`; Rust 1.88+). Skip for package or container installs.

## 3. Initialise the config

Run `stackpit init` to write `stackpit.toml` (default path; override with `-c/--config <path>`) with a random admin token. Set at minimum:

- `[server].bind` / `[server].ingest_bind` — admin binds loopback by default; in a container you must set `bind = "0.0.0.0:3000"` for the mapped admin port to be reachable. Keep ingest reachable by SDKs (`0.0.0.0:3001` is intended and public).
- `[server].external_url` / `external_ingest_url` — the URLs clients and SDKs actually reach (behind any proxy).
- `[server].admin_token` — min 16 chars, superuser/break-glass above all orgs. Generate a strong one (`openssl rand -hex 32`); do not ship the dev value.
- `[server].master_key` (or the `STACKPIT_MASTER_KEY` env var, which overrides it) — 32-byte hex key for at-rest secret encryption. **Required if you enable OAuth**; without it, integration secrets (Slack tokens, webhook URLs) fall back to plaintext in the DB with a warning. Keep it out of the DB's directory and backups.
- `[storage]` — `path` for SQLite, or `database_url` for Postgres (overrides `path`); `retention_days` (default 90; `0` never expires).
- `[filter].mode` — `open` auto-provisions projects on first ingest (convenient, permissive); `closed` requires pre-registration. For an exposed instance, prefer `closed` with `rate_limit` and `max_projects` bounds.
- `[email]` (optional) — provider (`lettermint`/`postmark`/`sendgrid`/`smtp`) and credentials for instance-wide mail.

For SSO, org mapping, and alerts, hand off to `stackpit:reconfigure` rather than wiring them here.

## 4. Boot and connect an SDK

Start with `stackpit serve` (or `serve --ingest-only` for an ingest-only node). Then point an existing Sentry SDK at the ingest URL using the Stackpit DSN (format in `docs/operator-guide.md` §Connecting SDKs).

## 5. Verify before declaring done

- Confirm health: `GET :3001/health`.
- Log in to the web UI on the admin listener with the admin token.
- Send a test event from an SDK (or `stackpit-bench`) and confirm it appears as an issue. Do not report setup as working without seeing an event land.

## 6. TLS and reverse proxy

Stackpit serves plain HTTP; terminate TLS at a reverse proxy (nginx/Caddy). If auth is enabled and the bind is non-loopback, set `[server].force_secure_cookies = true` and an `https://` `external_url`, or startup fails. Set `[server].trusted_proxies` to the proxy's IP/CIDR so `X-Forwarded-For` is trusted correctly (loopback is always trusted; misconfiguration enables rate-limiter IP spoofing).

For scaling the ingest path (Postgres, `ingest_writers`, `ingest_batch_size`), see `SCALING.md`.
