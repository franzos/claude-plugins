---
name: plan:resume
description: Use when picking up a plan that was interrupted, in a fresh session. Finds the newest checkpoint for the project in the knowledge base, verifies its claims against the actual tree before trusting them, reports any drift, and continues execution from the stated next action.
---

# Resuming an interrupted plan

> `$KB` is your knowledge-base root: a directory outside the working repo holding
> `<project>/specs/`, `<project>/plans/` and `<project>/checkpoints/`. Point at it from
> your CLAUDE.md. Keeping these out of the repo keeps process artifacts from leaking
> into it, and the knowledge survives clones, branches and machines.

## 1. Find the checkpoint

Look in `$KB/<project>/checkpoints/`, where `<project>` is the repo's folder name.

Take the newest file by date in the filename. If several slugs are in play, list them with their dates and ask the user which. If there is no checkpoints directory, this is not a resume - use `/plan:run`.

Read the checkpoint first. Its header names the plan and spec - read those next, then the rest of its "Read first" list, in the order it names them. Honour its staleness warnings: if it says a file is not to be trusted, do not read it for facts.

If the header is missing (a checkpoint written before this was required, or by hand), find the plan yourself: strip the date from the checkpoint filename and match the remaining slug against `$KB/<project>/plans/`. The dates will not match - the plan is dated when it was written, the checkpoint when work stopped.

## 2. Verify before trusting it

**The checkpoint describes the tree as it was when work stopped. Confirm it still holds before acting on it.** Things move: the user may have committed, merged, reverted, or reboot may have lost something.

Check, at minimum:

- `git log --oneline` and `git status` against the commits and branch the checkpoint claims.
- The test suite against the pass/fail count it claims.
- Whether the containers, databases, or services it describes are actually in the state it describes.

This is cheap and it is the whole point of the checkpoint being trustworthy.

## 3. Report the delta

Tell the user, in a few lines:

- What the checkpoint claimed.
- What is actually true now.
- Whether the stated next action is still the right one.

If reality matches, say so plainly and continue. If it has drifted, **stop and ask** rather than guessing which version is correct. A resume that acts on a stale premise undoes work.

## 4. Continue

Pick up at the next action the checkpoint names. From here the rules are `/plan:run`'s: follow the stated execution order, tick checkboxes in the plan file, fast gate per commit, full gate once at the end, reviewer only on judgment-heavy tasks.

Do not re-verify work the checkpoint recorded as done and that git confirms - that is rediscovery, and avoiding it is why the checkpoint exists.

## 5. Stopping again

If this session is also interrupted, invoke `/plan:snapshot`. It will write a new checkpoint and mark this one superseded.
