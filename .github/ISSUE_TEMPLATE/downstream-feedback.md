---
name: Downstream feedback
about: Report a problem or improvement from a downstream fork (workshop attendee, derived project)
title: "[downstream] "
labels: ["downstream-feedback", "needs-triage"]
---

<!--
This template is filled in by an agent running in a downstream fork
(e.g. a workshop attendee's project) to report problems or suggested
improvements back to the upstream Agile Flow framework.

Keep sections short and concrete. The upstream triage agent will
dedupe, label, and either close-with-explanation or convert into a
framework ticket.
-->

## Source

- **Downstream repo:** <!-- e.g. octocat/my-fork -->
- **Upstream version / commit:** <!-- output of `git log -1 --format=%h main` on the fork's upstream tracking branch, or the release tag -->
- **Reporter:** <!-- agent name + human owner, e.g. "claude (workshop attendee jdoe)" -->
- **Date observed:** <!-- YYYY-MM-DD -->

## Category

<!-- Pick one. Delete the others. -->

- [ ] Bug — framework code or script behaves incorrectly
- [ ] Doc gap — instructions missing, wrong, or out of date
- [ ] DX friction — works but is confusing, slow, or error-prone
- [ ] Enhancement — suggested addition or change

## What happened

<!-- 1-3 sentences. What did the downstream agent try to do, and what went wrong or felt wrong? -->

## Repro / evidence

<!--
For bugs: minimum commands to reproduce, plus the actual error.
For doc gaps: which file/section, and what was missing or misleading.
For DX friction: which step, and what would have helped.
Paste logs in fenced code blocks. Trim to the relevant lines.
-->

```
<!-- logs, error, or quote of misleading doc -->
```

## Expected vs actual

- **Expected:** <!-- one line -->
- **Actual:** <!-- one line -->

## Suggested fix

<!-- Optional. If the downstream agent has a concrete suggestion, name the file(s) and the change. Skip if uncertain. -->

## Scope hint

<!-- Help the upstream triage agent size this. Pick one. -->

- [ ] Quick fix (<20 lines, no behavior change)
- [ ] Small ticket (S, 1-4h)
- [ ] Medium ticket (M, 0.5-2d)
- [ ] Larger / needs design (L+)
- [ ] Not sure

---

<!--
Triage agent: see `/triage-downstream-feedback` for the workflow.
Do not edit below this line.
-->
<!-- triage-status: pending -->
