---
name: reconfigure
description: Use to change an existing Stackpit deployment toward a specific goal: enable OIDC/OAuth SSO (Ory Hydra, Keycloak, Authentik, Auth0), map organizations and roles from IdP claims, gate the MCP endpoint, enable or switch email, set up Slack/webhook alert integrations, tighten the event filter mode, migrate from SQLite to Postgres, or import from Sentry. Locates the live config, reads the relevant operator-guide section, makes the change in the right place, validates it, and tests the affected flow. Triggers: add SSO to Stackpit, configure OIDC login, map orgs from claims, add Slack alerts, switch Stackpit to Postgres, import from Sentry.
---

# Reconfiguring Stackpit

Reconfiguration is goal-driven: what does the user want to achieve? Some changes live in `stackpit.toml`, others in the web UI (Settings). Read the relevant `docs/operator-guide.md` section for current detail rather than working from memory, and validate before declaring done. Startup validation is strict, so an invalid change fails fast.

## 1. Establish the goal and the current state

Ask what the user wants to achieve if it is not already clear. Then locate the deployment: the active `stackpit.toml` (`-c/--config`), the storage backend (SQLite vs Postgres, which is a build-time cargo feature), whether OAuth is already on, and how it is run (native vs container, behind a proxy or not).

## 2. Dispatch by goal

### Enable OIDC / OAuth SSO

Set `[auth.oauth]` in `stackpit.toml`: `issuer_url`, `client_id`, `client_secret`, `redirect_uri` (`/web/auth/callback`), `post_logout_redirect_uri`, and `web_audience` (**mandatory when OAuth is enabled**; startup refuses without it). Works with any compliant IdP (Ory Hydra, Keycloak, Authentik, Auth0), Authorization Code + PKCE. Access tokens are validated as JWT via JWKS (recommended) or as opaque tokens via RFC 7662 introspection (`introspection_url`). Note that enabling OAuth **requires** `STACKPIT_MASTER_KEY` (or `[server].master_key`), or startup fails. The Hydra client-registration walkthrough is in operator-guide §Authentication.

### Map organizations and roles from the IdP

Grant the OAuth client an `orgs` scope (Forseti-style claim) so organizations and roles map on login; without it users get personal-orgs-only. Roles are `owner`/`member`; in open mode, auto-provisioned projects land in a system "Unassigned" org. See operator-guide §Organizations & Roles.

### Gate the MCP endpoint

Set `[auth.mcp]` (`audience`, `jwks_url` or `introspection_url`, cache TTLs, introspection client id/secret). Requires `[auth.oauth]`. The endpoint is `POST /mcp`; access tokens are RS256 JWT via JWKS or opaque via introspection.

### Enable or switch email

Instance-wide mail is `[email]` in `stackpit.toml` (`enabled`, `from_address`, `from_name`, `provider`, credentials; prefer env for secrets). Per-integration email, plus Slack and webhook alerts, are configured in the **web UI under Settings → Integrations** (Slack/webhook secrets are stored encrypted with the master key). Alert rules and digests are set via the UI or the JSON API (`/api/v1/alerts/rules`, `/api/v1/digests`).

### Tighten the event filter

`[filter]` in `stackpit.toml`: `mode` (`open` auto-provisions on first ingest, `closed` requires pre-registration), `rate_limit`, `max_projects`, `max_native_orgs_per_user`, `excluded_environments`, `blocked_user_agents`. For an exposed instance move to `closed` with sane bounds.

### Migrate from SQLite to Postgres

The backend is a **build-time cargo feature**, so this is a rebuild/reimage, not just a config edit: build or pull the Postgres variant (`--features postgres` / the `-postgres` image), stand up `postgres:17`, and set `[storage].database_url` (which overrides `path`). Postgres also unlocks `ingest_writers` for the batched write path (see `SCALING.md`). Plan the data migration deliberately; it is not automatic.

### Import from Sentry

`stackpit sync` reads `SENTRY_AUTH_TOKEN` (and `SENTRY_URL`/`SENTRY_ORG`/`SENTRY_PROJECT`). See operator-guide §Syncing from Sentry.

## 3. Validate and test

- Config changes are validated at startup; restart `stackpit serve` and confirm it boots (it fails fast on invalid auth/cookie/secret combinations).
- Exercise the changed flow end to end: an SSO login round-trip through `/web/auth/callback`, an org showing the mapped role, a test alert firing to Slack/webhook. Do not report the change as working without loading it.

For a full hardening pass rather than a single change, use the `stackpit:audit` skill.
