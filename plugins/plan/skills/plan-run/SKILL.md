---
name: plan:run
description: Use when executing a written implementation plan from the knowledge base in a fresh session. Reads the spec and plan, works the tasks in order, checks them off in place, and keeps the expensive gates off the hot path. Pair with /plan:snapshot to stop cleanly and /plan:resume to pick up an interrupted run.
---

# Executing a plan

> `$KB` is your knowledge-base root: a directory outside the working repo holding
> `<project>/specs/`, `<project>/plans/` and `<project>/checkpoints/`. Point at it from
> your CLAUDE.md. Keeping these out of the repo keeps process artifacts from leaking
> into it, and the knowledge survives clones, branches and machines.

Run this in a **fresh session**. Execution in the same session that wrote the plan starts at 100k+ of context and pays that on every turn for the rest of the run.

## Run it autonomously

**Work the whole plan through without checking in.** The user already signed the plan off. Do not ask permission to start a task, to move to the next one, or to act on the commit answer they give you in section 1.

Report at milestones, not per task - a short line when a group of related tasks lands, not a narration of each one.

There are exactly four reasons to stop and ask:

1. The two run questions at the start (section 1), asked together, once.
2. A task contradicts the spec, or doing it would change scope (section 3).
3. Something is genuinely ambiguous and both readings lead to materially different work.
4. The context thresholds below.

Anything else - a task that needs a small mechanical deviation, a pre-existing failure, a judgment call with an obvious default - decide it, note it, keep going.

## 1. Load

Find the plan under `$KB/<project>/plans/`. If several match, take the newest by date and say which one you took.

Check `$KB/<project>/checkpoints/` first. If a checkpoint exists for this slug, this is a resume, not a fresh run - use `/plan:resume` instead.

Read, in this order: the spec, the plan, then the project's `CLAUDE.md` (repo root first, then `$KB/<project>/CLAUDE.md`). Read the files the plan names as you reach the tasks that touch them, not up front.

Record the starting state before touching anything: current branch, whether the tree is clean, and the current pass/fail count. This is the baseline you will compare against at the end.

A dirty tree or already-failing tests are not automatically a stop. If they are pre-existing and unrelated to the plan, note them as the baseline and carry on. Stop only if they would mask the plan's own work - uncommitted changes to files the plan modifies, or failures in the area being changed.

### Ask the two run questions, once

Ask both together, here, before any work starts. Record the answers and follow them for the whole run without raising either again.

**1. Committing.** the user's standing rule is to never commit unless they asked, so ask once rather than per task:

> Commit as I go, one commit per task - or leave everything in the tree for you to review?

If they do not answer, or the run starts without one, the default is **leave it in the tree** - that is what their standing rule says. This covers commits only: push, tag, and merge stay gated for the whole run regardless, and need a separate explicit ask.

**2. Verification.** Ask whether each task should be checked by a second agent:

> Verify each task with a second agent before I move on - or only the judgment-heavy ones?

Default if unanswered: **only the judgment-heavy ones**, which is the cadence rule's normal behaviour. Say what it costs them: a reviewer dispatch per task is roughly one extra agent per task, against catching a task that looks done and isn't.

## 2. Work the tasks

Follow the plan's stated execution order, not document order.

For each task:

1. **Implement** it.
2. **Verify** it the way the plan says to verify it.
3. **Check** it - see below.
4. Commit it, if that is what they answered in section 1 - one commit per task, one-line subject matched to `git log`. Otherwise leave it in the tree.
5. **Tick the checkbox in the plan file.** This is the only progress record.

### The check step

Always, and it costs a turn: read back your own diff and confirm it does what the *task* said, not what you remember doing. Confirm the verification actually exercised the new code - a test that passes without touching your change proves nothing. **If the task is only partly done, say so and do not tick the box.**

Then, depending on their answer to question 2:

- **Second agent on every task**: dispatch `feature-dev:code-reviewer` against the task's diff, briefed with what the task said it would do. Fix what it confirms before ticking the box. Note anything you disagree with and why, rather than silently ignoring it.
- **Judgment-heavy only** (the default): dispatch it for multi-file coordination, concurrency, or anything security-sensitive. Mechanical single-file tasks ride to the final review.

A reviewer finding that contradicts the plan or spec is a stop-and-ask, not something to fix quietly.

**Gates, per the cadence rule:**

- Per intermediate commit: the fast gate only - format plus the *scoped* tests for the change, not the whole suite. For Rust that is the project's fast-gate command.
- Once per branch, at the end: the full gate - lint with warnings denied, and the full test suite.

The heavy format/lint/test/review round is a once-per-branch cost. Paying it per task is what makes a run drag.

## 3. When the plan turns out to be wrong

It will. When a task cannot be done as written:

- Stop and think before improvising.
- If the fix is mechanical and local, make it and **edit the plan file to match**. A plan that disagrees with the tree is worse than no plan.
- If it changes scope or contradicts the spec, ask the user. Do not quietly redesign.

Record every deviation in the plan file as you go. Whoever reads it next has no memory of this session.

## 4. Finishing

Run the full gate once. Report: what landed, what was skipped and why, what the plan said that turned out wrong.

Do not push, tag, or merge - those stay gated whatever they answered about commits. If the work is still sitting in the tree, propose a one-line commit subject matched to `git log`.

## Context thresholds

Long runs get expensive: at 400k of context every turn costs 400k of cache read before doing any work, and nuance starts getting lost.

**At 400k** - finish whatever task is in flight, then ask the user whether to pause. Never interrupt mid-task. Give them the numbers to decide with: current context, tasks done, tasks left. If they decline, carry on without raising it again until the next threshold.

**At 600k** - ask once more, same way. If they decline again, carry on and do not ask a third time.

These two prompts are the only unprompted interruptions permitted during a run. Everything else works straight through.

If the user says pause at either point, invoke `/plan:snapshot`.

## Interruption

If the user stops the run, or the machine needs a reboot - invoke `/plan:snapshot`. Do not just stop; an unrecorded stop costs a full rediscovery next session.
