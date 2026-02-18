---
description: Create a well-structured ticket that meets Definition of Ready
---

Create a new ticket on the project board with guided workflow.

## Critical Rules

1. **Every ticket must meet Definition of Ready** before being added to the board
2. **Use the board configuration** from the project's GitHub Project settings
3. **Never create duplicate tickets** — search existing issues first
4. **Assign appropriate priority** (P0 = critical, P1 = important, P2 = nice to have)

## Workflow

1. **Understand** — Ask clarifying questions about the feature/fix/task
2. **Gather Context** — Read `docs/TECHNICAL-ARCHITECTURE.md` and `docs/PRODUCT-REQUIREMENTS.md` to pre-populate Environment Context and Guardrails
3. **Research** — Search existing issues to avoid duplicates, check related code
4. **Draft** — Write the ticket following the template below
5. **Scope Check** — If effort estimate is XL or the happy path has multiple branch points, suggest decomposition before creating
6. **Review** — Present the draft to the user for approval
7. **Create** — Create the GitHub issue and add it to the project board
8. **Categorize** — Set priority, size estimate, and move to Backlog

## Ticket Template

```markdown
## Problem
[What problem does this solve? Why does it matter? 2-3 sentences max.]

## A. Environment Context
[Tech stack, integration points, existing patterns to follow, files to modify.
Populate from TECHNICAL-ARCHITECTURE.md and existing codebase.]

## B. Guardrails
[Explicit constraints: security rules, performance targets, what NOT to do.
Populate from AGENTIC-CONTROLS.md and PRD non-functional requirements.]

## C. Happy Path
[Step-by-step Input → Logic → Output flow. One clear flow per ticket.]

## D. Definition of Done
[Concrete proof of completion: specific tests, assertions, endpoints to verify.
Not vague — the PR reviewer must be able to check each item.]

## Acceptance Criteria
- [ ] [Specific, testable criterion]
- [ ] [Another criterion]

## Parent Epic
#[epic-number] (if applicable)

## Effort Estimate
[XS (<30 min) | S (1-2 hours) | M (2-4 hours) | L (4-8 hours) | XL (1+ days)]
```

See `docs/TICKET-FORMAT.md` for the canonical format specification and examples.

## Usage

```
/create-ticket
/create-ticket Add health check endpoint to the API
```
