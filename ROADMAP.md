# Feature roadmap for this fork

Planning baseline: `e30a9c304238` on `origin/main`, 2026-10-26. This plan applies to the owned fork and is not an upstream OpenAI roadmap.

## Outcome

Let an operator delegate a bounded task and return to an understandable, recoverable result. The [Elixir implementation](elixir/README.md) already supports several trackers, isolated issue workspaces, dispatch checks and blocked-run reporting. Its documented blocked map is currently in memory and clears on restart.

## 1. Preserve a blocked run across restart

Persist the minimum state needed to explain why an issue requires operator input. Reconcile that state against the live tracker and workspace before allowing an explicit resume.

Acceptance:

- Restarting does not silently dispatch an issue that was waiting for an approval or input.
- The operator sees the issue, blocking reason, last known attempt and a deliberate next action.
- A terminal tracker issue is not revived by persisted state.
- Resume cannot create two active attempts for the same claimed issue.
- Stored diagnostics exclude credentials and unnecessary prompt contents.

Pilot one tracker and one repository with synthetic blocked tasks. Compare recovery effort and accidental redispatches with the current restart behavior.

## 2. Make work limits visible

Show the configured task limits and observed effort alongside the run's useful output. Explain why a run stopped and what remains before offering another attempt.

Acceptance: an operator can identify unfinished work and its cost evidence without reading the entire transcript. Limits should stop additional work through the existing orchestrator contract, not merely decorate the dashboard.

## 3. Return a compact proof of completion

Present changed artifacts, exact validation state, unresolved findings and the next decision together. Keep PR state and commit identity current when displaying completion evidence.

## Ownership and boundaries

Symphony owns tracker-driven implementation runs. Shipshape prioritizes portfolio maintenance; PR Bot reviews a particular PR. Share links and explicit contracts rather than duplicating all three products.

Keep this a trusted-environment engineering preview. No expanded merge authority, new tracker category, billing product or unattended production rollout is part of the first release. Use the existing Elixir persistence/runtime facilities and tests. Success is an accepted task outcome with less supervision, not more agent activity.
