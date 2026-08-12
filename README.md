# claude-plugins

A small Claude Code plugin marketplace: a set of domain experts (subagents) grouped into installable plugins. Each plugin ships one or more agents you can dispatch for a specific stack or domain, from stack-specific implementation engineers to deep single-domain specialists.

## Installing

Add this marketplace, then install the plugins you want:

```
/plugin marketplace add franzos/claude-plugins
/plugin install engineers
/plugin install identity
```

Plugins are namespaced by the marketplace they come from (this one is named `gofranz`). If another added marketplace also ships a plugin called `engineers`, qualify the install with `@gofranz` to disambiguate:

```
/plugin install engineers@gofranz
```

To develop against a local checkout instead, point the marketplace at the directory:

```
/plugin marketplace add /path/to/claude-plugins
```

## Recommended setup: declare your environment

These agents run build, test, and format commands. To skip auto-detection, describe your machine once in your global `~/.claude/CLAUDE.md`. Claude reads it every session and the facts reach the agents. This is optional: without it, the agents probe for what's available and ask when unsure. They never install system-wide packages without asking.

Add a block like this, adjusted to your setup. It can declare not just which tools exist but how you want them used (for example, whether to format inside a container):

    ## Environment

    - OS / shell: Linux, bash (POSIX)
    - Container runtime: podman
    - Node package manager: pnpm (or: follow the project's lockfile)
    - Toolchains: provide via `guix shell`; prefer a project `manifest.scm`
    - Formatting/linting: run in a container when the tool isn't on `PATH`
    - Never install system-wide packages without asking

Example for a different setup:

    ## Environment

    - OS / shell: macOS, zsh
    - Container runtime: docker
    - Node package manager: follow the lockfile
    - Toolchains: system plus `mise`; fall back to `nix shell`
    - Formatting/linting: use the tool on `PATH`; do not use containers

The agents treat this as guidance, not gospel: if a declared tool turns out not to be present, they fall back and tell you.

## Plugins

| Plugin | What it provides |
| --- | --- |
| `engineers` | Stack-specific implementation engineers: `engineer:cpp`, `engineer:go`, `engineer:java`, `engineer:nextjs`, `engineer:qt`, `engineer:react`, `engineer:rust`, `engineer:typescript`. |
| `identity` | Identity and access specialists: `specialist:keycloak`, `specialist:oauth-oidc`, `specialist:oid4vc`, `specialist:node-oidc-provider`. |
| `guix` | GNU Guix specialist: `specialist:guix` (package definitions, services, home configurations, channels, manifests, G-expressions, store/daemon debugging). |
| `security` | Language-agnostic security auditor: `specialist:security` (attack-surface mapping and attacker-exploitable findings). |
| `sql` | SQL specialist: `specialist:sql` (query optimization, schema and index design, execution-plan analysis, cross-platform features). |
| `iota` | IOTA L1 protocol specialist: `specialist:iota` (the Move-based, object-centric blockchain, its Rust monorepo, RPC servers, indexer, CLI, and SDKs). |
| `iced` | iced Rust GUI specialist: `specialist:iced` (The Elm Architecture loop, widgets, `Task`/`Subscription`, theming, custom `Widget`/canvas/shader work). |
| `plan` | Multi-session workflow skills: `plan:new` (spec and plan), `plan:run` (execute autonomously), `plan:snapshot` (record verified state on interruption), `plan:resume` (verify a snapshot, then continue). Slash-commands only, no hooks. |
| `forseti` | Operator skills for Forseti (the web UI for the Ory Kratos + Hydra stack): `forseti:setup`, `forseti:reconfigure`, `forseti:audit`. |
| `stackpit` | Operator skills for Stackpit (the self-hosted, single-binary Sentry replacement): `stackpit:setup`, `stackpit:reconfigure`, `stackpit:audit`. |
| `infra` | Infrastructure and operations specialists: `specialist:haproxy`, `specialist:nginx`, `specialist:caddy`, `specialist:traefik` (reverse proxies and web servers), `specialist:docker`, `specialist:podman` (container runtimes), and `specialist:systemd` (service manager). |

### External dependency: `plan` needs `feature-dev`

The `plan` skills dispatch `feature-dev:code-explorer`, `feature-dev:code-architect`, and `feature-dev:code-reviewer`. Those agents ship in Anthropic's own marketplace, not this one, so installing `plan` does not pull them in. Add them yourself:

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin install feature-dev
```

Without them the skills still load, but the steps that delegate exploration, architecture, and review have nothing to dispatch to and fall back to inline work in your session.

## Best practices

When you build your own skills or agents, wire them to the ones that already exist instead of re-deriving their knowledge. The agents in this repository (and any skills you've installed) are reusable building blocks, so lean on them:

- **Delegate to existing agents.** If your skill or agent needs stack-specific implementation, security review, or a domain deep-dive, dispatch the matching agent (`engineer:rust`, `specialist:security`, `specialist:oauth-oidc`, and so on) rather than duplicating that expertise inline. A short skill that routes to the right agent beats a long one that reimplements it.
- **Compose, don't copy.** Before writing new guidance, check whether a skill or agent here already covers it and reference it by name. Duplicated instructions drift apart over time; a single reference stays current.
- **Point at the source of truth.** When several skills need the same fact (an environment convention, a build command, a spec citation), keep it in one place and link to it. This is the same reason these agents read your global `~/.claude/CLAUDE.md` instead of each hard-coding your setup.
- **Keep agents focused, let skills orchestrate.** Each agent here does one thing well. Your skills can chain them (explore, then implement, then review) to get a workflow without any one agent growing into a catch-all.

The payoff is less duplication and more effective skills: fixes and improvements to a shared agent propagate to everything that references it.

## Structure

```
.claude-plugin/marketplace.json   # marketplace manifest
plugins/<name>/
  .claude-plugin/plugin.json       # plugin manifest
  agents/*.md                      # agent definitions
  skills/<skill>/SKILL.md          # skill definitions
```

Agents are plain Markdown with YAML frontmatter (`name`, `description`, `tools`, `model`). They are written to be portable: build and test commands are shown as examples (with `guix shell` as one option), not as assumptions about your machine.
