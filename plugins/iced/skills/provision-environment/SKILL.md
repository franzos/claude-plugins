---
name: provision-environment
description: Use before running any build, test, lint, or format command to establish a working toolchain or runtime. Follows the user's declared environment presets, probes what is already available, provisions only in ways that do not modify the host machine (an ephemeral nix/guix shell or a throwaway container), and otherwise asks the user instead of guessing or installing.
---

# Provisioning a toolchain or runtime

Before you run a build, test, lint, or format command, make sure the tool is actually available, and get there without changing the user's machine. Work through these steps in order and stop at the first that succeeds.

## 1. Follow declared presets

If the user has declared environment facts (typically an `## Environment` block in their `~/.claude/CLAUDE.md`, which you receive automatically), follow them: the container runtime to use, the package manager, how toolchains are provided, whether to format in a container, and so on. These win over anything you would infer.

## 2. Detect what is already there

Probe, do not assume. Check without side effects:

- **Binaries:** `command -v <tool>` (never run a tool just to see if it errors).
- **Container runtime:** a present binary is not enough, confirm the daemon: `docker info >/dev/null 2>&1`, else `podman info >/dev/null 2>&1`. `podman` is a drop-in for `docker`.
- **Language package manager:** resolve from the lockfile, not from what is installed (`pnpm-lock.yaml` -> pnpm, `package-lock.json` -> npm, `yarn.lock` -> yarn, `bun.lockb` -> bun).
- **Declared project environment:** prefer whatever the project ships: `manifest.scm`, `flake.nix`, a devcontainer, `.tool-versions`/`.mise.toml`, `.nvmrc`, `rust-toolchain.toml`.
- **OS:** `uname -s` (Linux/Darwin). Assume a POSIX shell; if it is something else, say so and ask.

If the tool the task needs is already on `PATH`, use it and move on.

## 3. Provision only non-invasively

If the tool is missing, you may still proceed **only** by means that leave the host unchanged:

- An ephemeral shell: `nix shell ...` or `guix shell ...` (transient, nothing installed into a profile).
- A throwaway container run, for example formatting Rust with no local toolchain:
  `docker run --rm -v "$PWD":/w -w /w rust:<toolchain-version> sh -c "rustup component add rustfmt && cargo fmt"` (use `podman` if that is the available runtime).

Never modify the host to satisfy a requirement: no `apt`/`dnf`/`brew`/`pacman`/`apk` installs, no global `rustup component add` on the host, no `sudo`, no writing to system paths. Provisioning is allowed to be transient, never permanent.

## 4. Otherwise, ask

If the requirement cannot be met from steps 1-3, do not force it and do not fall back to a host-modifying install. Stop and tell the user exactly what is missing and the options (for example "no Rust toolchain on `PATH`, and no `nix`, `guix`, or container runtime available, how would you like to proceed?"). Let them decide.

## Cap the effort

Try the declared/available path, then one non-invasive fallback, then ask. Do not loop retrying the same failing command.
