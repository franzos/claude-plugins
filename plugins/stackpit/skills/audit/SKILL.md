---
name: audit
description: Use to review an existing Stackpit deployment against best practice and surface what to harden. Checks the live config against Stackpit's own startup validation rules and the operator-guide security checklist (no-auth posture, admin-token strength, secure cookies, master-key separation, OIDC audience/TTL binding, trusted proxies, admin-port exposure, filter mode, retention), and produces a ranked, numbered punch-list the user can pick fixes from. Triggers: audit Stackpit, review the Stackpit setup, harden Stackpit, security review of the config, best-practice check.
---

# Auditing a Stackpit deployment

Produce a ranked findings list, not a lecture. Check the live `stackpit.toml` against the rules Stackpit already enforces at startup and the operator guide, rank by severity, and let the user choose what to fix. Read the config that is actually deployed; do not assume the example or init-generated file.

## 1. Locate the config and the deployment shape

Find the active `stackpit.toml` (`-c/--config`), the storage backend (SQLite vs Postgres), the bind addresses, whether auth is enabled, and whether it sits behind a TLS proxy. Stackpit enforces most of these rules at startup; rationale is in `docs/operator-guide.md`.

## 2. Try booting under the real rules

Stackpit fails closed on many misconfigurations at startup, so a `stackpit serve` (or a config parse) against the live file surfaces the enforced findings directly. Fold any startup error or warning into the punch-list.

## 3. Walk the checklist

For each item, record pass/fail and severity. Highest-severity items first:

- **No-auth posture (critical).** Stackpit refuses to start with no `admin_token` and no OAuth unless bound to loopback and `no_auth_loopback_acknowledged = true`. Flag any `no_auth_loopback_acknowledged = true`, or a non-loopback bind with no auth.
- **Admin token strength.** `[server].admin_token` present, ≥16 chars, not a placeholder or weak string. Recommend `openssl rand -hex 32`. Confirm the admin token, any `client_secret`, and SMTP credentials are production values, not ones carried over from an example config.
- **Secure cookies over HTTP.** With auth on and a non-loopback bind, `[server].force_secure_cookies` must be `true` (startup fails otherwise) and `external_url` must be `https://` behind the TLS proxy.
- **Master key and secret separation.** `STACKPIT_MASTER_KEY` (or `[server].master_key`) set, especially with OAuth (required). Confirm the key is not stored in the same directory or backup as the DB; env var override lets it live in a secrets manager / systemd `EnvironmentFile`. Without the key and without OAuth, integration secrets sit in plaintext in the DB.
- **OIDC confused-deputy hardening.** `web_audience` present (mandatory when OAuth enabled); cross-origin `post_logout_redirect_uri` only with explicit opt-in; redirect URIs absolute http(s); `refresh_token_max_ttl_secs` within the 90-day cap; introspection cache TTL ≤ 300s; JWKS TTL ≥ 60s. Confirm audience/scope binding and any `email_verified` reliance.
- **Trusted proxies.** `[server].trusted_proxies` set to the actual proxy IP/CIDR (loopback always trusted). Misconfiguration lets clients spoof `X-Forwarded-For`/`X-Real-IP` and bypass the rate limiter.
- **Admin-port exposure.** The admin listener (web UI + JSON API) firewalled or proxy-restricted, especially when `bind` is widened to `0.0.0.0` for a container. The ingest listener (`:3001`) is intended to be public; the admin one is not.
- **SMTP over plaintext.** `[email]` `user` set with `tls = "none"` is refused at startup; `tls = "none"` only for a loopback sink.
- **Filter mode.** `open` auto-provisions projects/keys on first ingest; for an exposed instance recommend `closed` plus `rate_limit` and `max_projects`/`max_native_orgs_per_user` bounds.
- **Body-size limits.** `max_body_size` and `max_compressed_body_size` left at sane values (decompression-bomb guard).
- **Retention.** `[storage].retention_days = 0` keeps data forever (startup warns); confirm it is intentional.
- **Commercial metrics.** If `/metrics` is used, it is license-gated and needs `STACKPIT_METRICS_TOKEN`; keep the admin port network-restricted even though the token is the real gate (fails closed: 404 without license/token, 401 on mismatch).

## 4. Report

Present a numbered, severity-ranked punch-list (critical first), one line per finding with the offending file/key and the fix, in the style of the `rust:review` / `security:review` skills. Then offer to apply the fixes the user selects. Do not change config as part of the audit itself unless asked.
