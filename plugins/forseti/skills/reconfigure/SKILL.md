---
name: reconfigure
description: Use to change an existing Forseti deployment toward a specific goal: add a social login provider (GitHub, Google, Microsoft, GitLab, Apple), enable Linux/POSIX login (PAM/NSS/sshd via the device grant), register a downstream OAuth client, enable or switch the email provider, turn on Enterprise SAML SSO, or adjust branding and rate limits. Locates the live config, reads the relevant operator-guide section, makes the change in the right file, validates it, and tests the affected flow. Triggers: add a GitHub login to Forseti, configure Linux login, add an OAuth client, reconfigure Forseti.
---

# Reconfiguring Forseti

Reconfiguration is goal-driven: what does the user want to achieve? The right change lives in different places (Forseti's `config.toml`, Kratos's `kratos.yml`, Hydra, or the admin UI). Read the relevant `docs/operator-guide.md` section for the current detail rather than working from memory, and validate before declaring done.

## 1. Establish the goal and the current state

Ask what the user wants to achieve if it is not already clear. Then locate the deployment: the active `config.toml` (`$FORSETI_CONFIG_PATH`), `infra/kratos/kratos.yml`, `infra/hydra/hydra.yml`, and how the stack is run (playground compose vs native). Note whether TLS/proxy is in front (it affects callback URLs).

## 2. Dispatch by goal

### Add a social login provider (GitHub, Google, Microsoft, GitLab, Apple, custom OIDC)

Configured in **Kratos**, not Forseti. In `kratos.yml` under `selfservice.methods.oidc.config.providers[]`, add an entry: `id`, `provider`, `client_id`, `client_secret` (via `${ENV}` substitution, not inline), `mapper_url`, and `scope`. Provide the claim-to-trait mapper as a Jsonnet file under `infra/kratos/` (e.g. `oidc.github.jsonnet`). At the IdP, register the callback as `https://<kratos-host>/self-service/methods/oidc/callback/<id>`. Forseti auto-renders one "Sign in with X" button per provider (known: github, google, microsoft, gitlab, apple, facebook; unknown ids get a generic icon). See operator-guide §oidc.

### Enable Linux / POSIX login

Forseti-native, via the OAuth Device Authorization Grant. Set the `[posix]` table in `config.toml` (uid/gid bands, `default_shell`, `home_prefix`, `free_seats`, `pam_client_id`/`pam_client_secret`, `hydra_issuer`). Mint the confidential Hydra device-auth client with `forseti posix-init-client`. Enroll the host at `/admin/hosts` (one-time `host_id:secret`), provision Kratos identities into POSIX accounts at `/admin/posix`, and install the `forseti-unix` host client (NSS + PAM + sshd `AuthorizedKeysCommand` + daemon; also packaged for Guix). Offline passphrase fallback is `/settings/offline-access`. Free up to `free_seats` (default 25); more needs a commercial license.

### Register a downstream OAuth client

Use the admin UI: `/admin/clients/new` (40+ prefilled app templates), or issue a DCR initial-access token at `/admin/dcr-tokens` for RFC 7591 self-registration. Harden with the `[oauth].dcr_reserved_names` denylist to block brand impersonation on the consent screen.

### Enable or switch the email provider

Set `[email]` in `config.toml`: `enabled`, `from_address`, `from_name`, `provider`, and the provider credentials (prefer env over inline). Kratos's courier SMTP is separate and lives in `kratos.yml`.

### Enable Enterprise SAML SSO (commercial)

Set `[saml]` in `config.toml` to point at a Jackson/Ory Polis instance (URL, API key, verifier, SP entity id); per-org connections are managed at `/sso/{org-slug}`. See `docs/commercial/saml.md`.

### Branding, rate limits, other subsystems

`[brand]`, `[auth]`/`[oauth]`/`[orgs]`/`[claim_email]`/`[handoff]` rate limits and TTLs are all in `config.toml`.

## 3. Validate and test

- Lint the Ory side: `forseti config-check` (`--strict`).
- Restart what changed: Kratos for `kratos.yml` edits, Forseti for `config.toml` edits (some values are hot, most are read at boot).
- Exercise the changed flow end to end in a browser (the new provider button, a POSIX login, the downstream authorize round-trip). Do not report the change as working without loading it.

For a full hardening pass rather than a single change, use the `forseti:audit` skill.
