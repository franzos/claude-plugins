---
name: plan:new
description: Use when starting a new project or a substantial change that needs a written spec and plan before any code. Runs Q&A with the user, dispatches code-explorer and code-architect, writes spec and plan to the knowledge base, and gets an adversarial review before implementation. Not for small or mechanical changes - those go straight to code.
---

# Planning a change

> `$KB` is your knowledge-base root: a directory outside the working repo holding
> `<project>/specs/`, `<project>/plans/` and `<project>/checkpoints/`. Point at it from
> your CLAUDE.md. Keeping these out of the repo keeps process artifacts from leaking
> into it, and the knowledge survives clones, branches and machines.

Produces two files in the knowledge base and nothing else. **No implementation code is written in this skill.**

Stop and say so if the change is small or mechanical (a bug fix, a one-file tweak, a rename). Those do not need a plan.

## 0. Locate the project

Project name is the repo's folder name, lowercase kebab-case. Everything lands under `$KB/<project>/`.

Pick a slug now (kebab-case, describes the change, no date). The spec, the plan, and every checkpoint share it.

## 1. Q&A before anything else

Ask the user about what is underspecified. Use `AskUserQuestion` for real forks; plain prose for open questions. Batch related questions rather than drip-feeding them.

Ask about: the actual problem being solved, scope boundaries (what is explicitly *not* in this change), constraints, what "done" looks like, and anything the codebase cannot tell you.

Do not assume and do not proceed on a guess. If two readings of the request lead to materially different work, that is a question, not a judgment call.

## 2. Understand what exists

For a brownfield change, dispatch `feature-dev:code-explorer` with a specific question - the feature to trace, the subsystem to map. Ask it to return the files that matter most, then read those directly.

Do not explore the codebase inline. That is what the agent is for.

Skip this for greenfield work.

## 3. Write the spec

`$KB/<project>/specs/YYYY-MM-DD-<slug>.md`

The spec is the *what* and *why*, authoritative over everything downstream. It carries: the problem, the decisions taken and their rationale, explicit non-goals, constraints, and open questions still outstanding. Prose over bullets where the reasoning matters.

**Show it to the user and get sign-off before continuing.** A wrong spec makes every task below it wrong.

## 4. Design the blueprint

Dispatch `feature-dev:code-architect` with the signed-off spec. It returns files to create/modify, component design, data flow, and a build sequence.

Read the files it flags as critical before you trust the blueprint.

## 5. Write the plan

`$KB/<project>/plans/YYYY-MM-DD-<slug>.md`

The plan is the *how*: a numbered task list, each task a `- [ ]` checkbox. Progress is tracked in this file and nowhere else - a second ledger goes stale and misleads whoever reads it next.

Each task states what changes, which files, and how it is verified.

**Right-size the tasks.** Fold setup, scaffolding, config, and closely related changes together. Split only where a reviewer could genuinely reject one half while approving the other. Do not turn TDD micro-cycles into tasks. Ten to fifteen real tasks, not forty.

State the **execution order** if it differs from document order, and say why (a task that deletes a symbol another task still calls has to wait for it).

Include a short environment section: how to build, test, and lint this project, with the exact commands.

## 6. Adversarial review

Dispatch a reviewer against the plan before anyone executes it. Ask it to find: tasks that cannot be done in the stated order, tasks whose verification does not actually verify anything, missing work implied by the spec, and hidden coupling between "independent" tasks.

Fold what survives back into the plan.

## 7. Hand off

Tell the user both file paths and that execution belongs in a fresh session via `/plan:run`.

Do not commit the knowledge-base files. Do not start implementing.
