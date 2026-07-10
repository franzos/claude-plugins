---
name: setup
description: Use to set up a new Forseti deployment (the web UI and OIDC front-end for the Ory Kratos + Hydra stack), with or without Docker. Brings up the Ory stack and Postgres, generates secure Kratos/Hydra/Forseti config with fresh secrets, wires the mandatory keys (audit webhook token, cookie secret, admin allowlist, service URLs), seeds an admin, and verifies the instance boots and the login flow works. Triggers: installing Forseti, first-time setup, standing up the Ory stack, getting Forseti running.
---

# Setting up Forseti

Forseti is a single Rust binary that fronts Ory Kratos (identity) and Ory Hydra (OAuth2/OIDC) and turns them into a drop-in OIDC provider plus an admin console. A full deployment is: Forseti + Kratos + Hydra + Postgres, and a mail provider. Do not hardcode the schema from memory: the operator guide and the shipped example configs are the source of truth. Read them from the deployment you are working on.

Work through these in order. Confirm the choice at each fork with the user rather than guessing.

## 1. Locate the deployment and pick a shape

Find what you are working with: a repo checkout (`docs/operator-guide.md`, `config.example.toml`, `infra/`), a release tarball, or a container image (`ghcr.io/franzos/forseti`). Then pick the runtime shape and confirm it:

- **Docker playground stack** (fastest): `infra/docker-compose.yml` brings up Postgres, Kratos (+migrate), Hydra (+migrate), and a mail sink; Forseti itself runs on the host and Kratos reaches it via `host.docker.internal:8081`. Driven by the `Makefile` (`make stack-up`, `stack-up-saml`).
- **Native**: prebuilt tarball (`cp config.example.toml config.toml`, edit, `./forseti`; runtime dep `libpq5`), a Cargo build (`make build`/`make run`), or a Guix build against `manifest.scm`. Kratos, Hydra, and Postgres are provided separately.

Read the prerequisites and topology sections of `docs/operator-guide.md` before proceeding, and `docs/operator-guide-proxy.md` if this sits behind a reverse proxy.

## 2. Provision the toolchain (native builds only)

If building from source, get a toolchain without touching the host: invoke the `provision-environment` skill (prefer the project `manifest.scm` via `guix shell`). Skip for tarball or container installs.

## 3. Bring up the dependencies

Stand up Postgres, Kratos, and Hydra. With the playground: `make stack-up` (init DB + migrations are wired in). Otherwise deploy Kratos and Hydra yourself and point them at Postgres. Generate their config securely rather than copying dev files verbatim:

- Prefer `forseti config-init` to emit Kratos/Hydra config with fresh CSPRNG secrets.
- If starting from `infra/kratos/kratos.yml` and `infra/hydra/hydra.yml`, rotate **every** placeholder: Hydra `secrets.system` and the pairwise salt; Kratos `secrets.cookie` and `secrets.cipher` (exactly 32 chars). Never reuse a value from an example or playground config; treat every secret, audit token, and OAuth `client_secret` in them as a placeholder to replace.
- All Kratos flow `ui_url`s and Hydra login/consent/logout URLs must point at the Forseti instance.

## 4. Write Forseti's config

Copy `config.example.toml` to `config.toml` (path overridable via `$FORSETI_CONFIG_PATH`; every key also has a `FORSETI_`-prefixed env override). Set at minimum:

- `[kratos]` / `[hydra]` — `public_url` + `admin_url` for each.
- `[self]` — Forseti's external `url` and public `bind` (default `:3000`).
- `[security].cookie_secret` — set a stable ≥32-byte secret. If empty, Forseti uses an ephemeral per-boot key and cookies churn on every restart (and break multi-instance).
- `[audit].webhook_token` — **mandatory; Forseti refuses to boot if empty**. It must match the bearer token in every `web_hook` in `kratos.yml`.
- `[internal].bind` — keep on loopback (default `127.0.0.1:8081`). It carries the audit receiver and the POSIX resolver; never expose it publicly.
- `[admin].allowed_emails` — the operator allowlist. Empty means the admin surface is closed; set the intended operators.
- `[database].url` — `sqlite://./forseti.db` for single-instance, or `postgres://…` for HA.
- `[email]` — provider (`lettermint`/`postmark`/`sendgrid`/`smtp`) and credentials for Forseti's own mailer.
- `[brand]` — `name`, `support_email`, and the `operator_trust_anchor` anti-phishing string.

The Ed25519 webhook signing key (`data/webhook-signing-key.pem`) is auto-generated `0600` on first boot if absent.

## 5. Seed an admin and boot

Seed the first admin identity (`make seed-admin` / `infra/seed-admin.sh`). Then start Forseti (`make run` or `./forseti`).

## 6. Verify before declaring done

- Lint the Ory config: `forseti config-check` (add `--strict`).
- Confirm the instance is healthy at `/admin/status` (it warns on SQLite-with-multi-instance and other footguns).
- Exercise the actual login flow in a browser: a Kratos self-service login through Forseti, and one OAuth authorize round-trip if a downstream client exists. Do not report setup as working without loading it.

## 7. TLS and reverse proxy

Terminate TLS at a reverse proxy and pass `X-Forwarded-Proto: https` and `X-Forwarded-Host`, or Ory emits `http://` URLs and non-`Secure` cookies. Only set `[proxy].trust_forwarded_for = true` behind a proxy that strips inbound forwarded-for headers. See `docs/operator-guide-proxy.md` for path-prefix vs subdomain vs port topologies.

When the deployment goal is more specific than a fresh install (add a login provider, enable Linux login, register a client), hand off to the `forseti:reconfigure` skill.
