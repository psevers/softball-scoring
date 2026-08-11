# Issue tracker: GitHub

Issues, specs, and implementation tickets for this repository live in GitHub Issues under `psevers/softball-scoring`.

## Conventions

- Prefer the installed GitHub connector for issue operations; use the `gh` CLI as a fallback.
- Publish a feature spec as its own issue before publishing implementation tickets.
- Publish one implementation ticket per vertical slice in dependency order.
- Apply the `ready-for-agent` label to fully specified specs and tickets.
- Use GitHub's native issue dependencies when available. Otherwise include a `Blocked by: #<issue>` line in the issue body.
- Do not close or modify a parent spec when creating child implementation tickets.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## When a skill says “publish to the issue tracker”

Create a GitHub issue in `psevers/softball-scoring`.

## When a skill says “fetch the relevant ticket”

Read the complete GitHub issue body, labels, and comments.
