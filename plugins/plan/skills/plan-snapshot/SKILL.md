---
name: plan:snapshot
description: Use when interrupting a plan that is mid-execution - the user stops the run, context is getting long, the machine needs a reboot, or the session is ending unfinished. Writes a verified snapshot to the knowledge base so a fresh session can resume without rediscovery. Read by /plan:resume.
---

# Checkpointing an interrupted plan

> `$KB` is your knowledge-base root: a directory outside the working repo holding
> `<project>/specs/`, `<project>/plans/` and `<project>/checkpoints/`. Point at it from
> your CLAUDE.md. Keeping these out of the repo keeps process artifacts from leaking
> into it, and the knowledge survives clones, branches and machines.

Writes `$KB/<project>/checkpoints/YYYY-MM-DD-<slug>.md`, dated the day work stopped. Same slug as the plan. Several checkpoints may accumulate for one plan; the newest is the live record.

The reader is a fresh session with **no memory of this one**. Everything it needs must be in the file or named by path in it.

## The one rule

**Every fact in this file is measured, now, against the tree it describes. Nothing is copied from an agent's report, and nothing is recalled from earlier in this session.**

Before writing a single number, run the commands: `git log --oneline`, `git status`, the test suite, the linter. A stale checkpoint is worse than none, because the next session trusts it.

If you cannot verify something, write that you could not verify it.

## Structure

### Header

Two lines, before anything else. A checkpoint that cannot name its own plan is orphaned.

```
Plan: /absolute/path/to/kb/<project>/plans/YYYY-MM-DD-<slug>.md
Spec: /absolute/path/to/kb/<project>/specs/YYYY-MM-DD-<slug>.md
```

Absolute paths, verified to exist. The plan and spec carry the date they were written, which is not this checkpoint's date - only the slug matches. If there is no spec, say `Spec: none`.

### START HERE

Open with the three things a fresh session needs in its first ten seconds:

- **Is anything broken?** Failing tests, a dirty tree, a half-applied migration - state it plainly, or state that nothing is broken.
- **Is anything waiting?** Unmerged branches, an unanswered question for the user, a service left running or stopped.
- **What is the single next action?** One task, named, with whether anything blocks it.

### Read first, in this order

A numbered list of the files the next session must read, in the order it should read them, each with one line on why. The spec and plan come first. Include exact absolute paths.

Say explicitly which files are now **stale and must not be trusted**. A superseded checkpoint, a progress note that stopped being updated, a README that no longer matches. Name them.

### Status

A table of what landed:

| task | commit | what landed | tests |
|---|---|---|---|

Commit SHAs read from `git log`, test counts from an actual run. Then state the branch, whether it is merged or outstanding, and the exact pass/fail count.

### Execution order

If the plan's order was changed, or a task was done out of order, say so and say why. Note which tasks remain and in what order they must now run.

### Deviations

What the plan said, what actually happened, and whether the plan file was edited to match. If it was not edited, say that - the next session will otherwise follow a plan that is wrong.

### Environment and traps

How to get back to a working state: build and test commands with their exact invocation, containers or databases left running or stopped and how to restart them, any override that has to be repeated or the command silently does the wrong thing.

This section is worth more than any other to the next session. Be specific about the traps you actually hit.

### What we learned

Findings that are not in the plan and would cost a session to rediscover: real data queried, a library that behaves differently than documented, an approach that was tried and abandoned and why.

## Finishing

Update the plan file's checkboxes to match reality before writing the checkpoint.

If an older checkpoint for this slug is now superseded, say so in the new one and name it.

Do not commit. Tell the user the checkpoint path and the one-line summary of where things stand.
