---
name: audit
description: Use to review an existing Forseti deployment against best practice and surface what to harden. Runs the built-in config linter, then walks the operator-guide security checklist (2FA enforcement, rotated secrets, internal-listener exposure, forwarded-for trust, TLS headers, webhook key permissions, database choice, DCR hardening, audit retention), and produces a ranked, numbered punch-list the user can pick fixes from. Triggers: audit Forseti, review the Forseti setup, harden Forseti, security review of the config, best-practice check.
---

# Auditing a Forseti deployment

Produce a ranked findings list, not a lecture. Check the live config against the deployment's own tooling and the operator guide, rank by severity, and let the user choose what to fix. Read the config that is actually deployed; do not assume the example files.

## 1. Locate the config and the deployment shape

Find the active `config.toml` (`$FORSETI_CONFIG_PATH`), `infra/kratos/kratos.yml`, `infra/hydra/hydra.yml`, and how it is run (single binary vs multi-instance, SQLite vs Postgres, behind a proxy or not). Rationale for each item below is in `docs/operator-guide.md`.

## 2. Run the built-in linter

`forseti config-check --strict` lints the Ory config and is the fastest source of real findings. Fold its output into the punch-list.

## 3. Walk the checklist

For each item, record pass/fail and severity. Highest-severity items first:

- **2FA enforcement (critical).** In `kratos.yml`, both `session.whoami.required_aal` and `selfservice.flows.settings.required_aal` must be `highest_available`. `settings.required_aal: aal1` opens the factor-removal bypass (an attacker with the password or recovery email strips the second factor). Forseti cannot enforce this from its side.
- **Secrets rotated and unique.** Hydra `secrets.system` and pairwise salt; Kratos `secrets.cookie` and `secrets.cipher` (exactly 32 chars); Forseti `[security].cookie_secret` set to a stable ≥32-byte value (not the ephemeral per-boot key). None committed to the repo.
- **No placeholder secrets in the live config.** Confirm no OAuth `client_secret`, audit token, or SSH/SAML key was carried over from an example or playground config; rotate anything that was.
- **Audit webhook token.** `[audit].webhook_token` set and matching the bearer in every `web_hook` in `kratos.yml` (Forseti refuses to boot if empty, but confirm it is not the dev placeholder).
- **Internal listener not public.** `[internal].bind` on loopback only. It carries the audit receiver and the POSIX resolver (your directory); the network ACL is load-bearing once it leaves loopback.
- **Forwarded-for trust.** `[proxy].trust_forwarded_for = true` only behind a proxy that strips inbound forwarded-for headers, else IP spoofing bypasses rate limits.
- **TLS and headers.** Reverse proxy terminates TLS and passes `X-Forwarded-Proto: https` + `X-Forwarded-Host`; CSP `frame_ancestors` / `X-Frame-Options` set for clickjacking defense.
- **Webhook signing key.** `data/webhook-signing-key.pem` present, `0600`, valid Ed25519 PKCS#8, and backed up (rotation is stop-replace-restart).
- **Admin surface.** `[admin].allowed_emails` is the intended operator set and non-empty; confirm the two-tier operator/org-owner model is understood. Admin requires AAL2 in code.
- **Database and backups.** Postgres (not SQLite) for multi-instance, or corruption results. Kratos and Hydra Postgres backed up (losing Hydra's JWKS invalidates every issued id_token).
- **DCR hardening.** `[oauth].dcr_reserved_names` denylist populated and DCR rate limits set.
- **Metrics.** `/metrics` gated by license and `[metrics].scrape_token`, and served only on the internal listener.
- **Retention scheduled.** `forseti audit-prune` and `forseti unverified-prune` run on a timer/cron; they do not run automatically.
- **Log hygiene.** Kratos `log.leak_sensitive_values: false` outside dev; secrets supplied via env, not TOML; email creds never over `tls = "none"`.

## 4. Report

Present a numbered, severity-ranked punch-list (critical first), one line per finding with the offending file/key and the fix, in the style of the `rust:review` / `security:review` skills. Then offer to apply the fixes the user selects. Do not change config as part of the audit itself unless asked.
