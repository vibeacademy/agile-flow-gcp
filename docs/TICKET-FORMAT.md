# Agentic PRD Lite -- Ticket Format Reference

This is the single source of truth for how tickets are written. Other files (agents, skills) reference this document. Do not duplicate this content elsewhere.

---

## 1. Why This Format Exists

Agents are hypersensitive to contextual ambiguity. Too much context causes drift -- the agent wanders off-task chasing irrelevant details. Too little context causes hallucination -- the agent invents assumptions to fill gaps. This format is the sweet spot: every sentence is either a directive or a constraint. Nothing is decorative. If a sentence does not tell the agent what to do, where to do it, what not to do, or how to prove it worked, it does not belong in the ticket.

---

## 2. The Format

Each ticket has **Standard Fields** followed by **4 Power Sections**.

### Standard Fields

| Field | Description |
|-------|-------------|
| **Problem Statement** | What is broken or missing, and why it matters. 2-3 sentences max. |
| **Parent Epic** | Link to the parent epic, if applicable. Omit if standalone. |
| **Effort Estimate** | XS (< 1 hr), S (1-4 hr), M (4-8 hr), L (1-3 days), XL (3+ days). |
| **Priority** | P0 (drop everything), P1 (current sprint), P2 (next sprint), P3 (backlog). |

### Power Section A: Environment Context

Tell the agent WHERE it is working.

- **Tech stack and framework** -- reference TECHNICAL-ARCHITECTURE.md, not a free-form description.
- **Integration points** -- existing APIs, databases, services, or queues this ticket touches.
- **Existing patterns to follow** -- specific files the agent should read before writing code (e.g., "follow the pattern in `src/routes/health.py`").
- **Files likely to be created or modified** -- list them explicitly so the agent scopes its work.

### Power Section B: Guardrails

Tell the agent what NOT to do.

- **Security constraints** -- sourced from AGENTIC-CONTROLS.md and PRD non-functional requirements.
- **Performance targets** -- latency ceilings, throughput floors, memory limits.
- **Compatibility requirements** -- browser support, API versioning, backward compatibility rules.
- **Explicit prohibitions** -- "Do NOT modify the auth middleware." "Do NOT add runtime dependencies." Be specific.

### Power Section C: Happy Path

Tell the agent the Input, Logic, and Output flow.

- Use numbered steps or a Mermaid diagram. Pick one; do not mix.
- One clear flow per ticket. If there are multiple major branch points, the ticket is too broad.
- Include the data shape at each step where relevant (request body, response payload, DB row).

### Power Section D: Definition of Done

Tell the agent how to PROVE it succeeded. Not "it works." Not "tests pass."

- **Specific test assertions** -- "Assert that `GET /api/foo` returns HTTP 200 with body `{\"bar\": \"baz\"}`."
- **Lint and type checks** -- "Zero errors from `mypy --strict` and `ruff check`."
- **Integration verification** -- "The new endpoint is callable from the existing API gateway config."
- **Reviewer checklist** -- what the PR reviewer should be able to verify by inspection or by running one command.

---

## 3. Concrete Example

```
TICKET: BACKEND-042 -- Add /ping health-check endpoint

Problem Statement:
The deployment pipeline has no lightweight endpoint to verify the service is
running. Render health checks currently hit the root route, which loads
middleware and returns HTML. We need a dedicated /ping endpoint that returns
JSON with zero middleware overhead.

Parent Epic: INFRA-010 (Observability and Health Checks)
Effort Estimate: XS
Priority: P1

--- A. Environment Context ---
- Stack: Python 3.12 / FastAPI 0.111 / Uvicorn (see TECHNICAL-ARCHITECTURE.md)
- Integration points: Render health-check configuration (render.yaml)
- Existing pattern: follow src/routes/health.py for route registration
- Files to create or modify:
    - CREATE src/routes/ping.py
    - MODIFY src/main.py (register the new router)
    - CREATE tests/test_ping.py

--- B. Guardrails ---
- Do NOT add authentication to this endpoint (it must be publicly reachable).
- Do NOT import any database or ORM modules; this endpoint must have zero
  downstream dependencies.
- Response time must be < 10ms at p99.
- Do NOT modify any existing routes or middleware.

--- C. Happy Path ---
1. Client sends GET /ping with no body and no auth headers.
2. FastAPI routes to the ping handler (no middleware chain).
3. Handler returns HTTP 200 with body: {"ping": "pong"}
   Content-Type: application/json
4. No database call, no logging side-effect, no cache hit.

--- D. Definition of Done ---
- test_ping.py asserts GET /ping returns 200 with body {"ping": "pong"}.
- test_ping.py asserts response Content-Type is application/json.
- test_ping.py asserts response time < 50ms in test environment.
- `ruff check src/routes/ping.py` returns zero errors.
- `mypy --strict src/routes/ping.py` returns zero errors.
- render.yaml health-check path is updated to /ping (or verified already correct).
- PR reviewer can run `curl localhost:8000/ping` and see {"ping": "pong"}.
```

---

## 4. Scoping Heuristics

Use these rules to decide if a ticket is the right size:

1. **One ticket = one deployable change.** It maps to a single pull request. If you cannot describe the PR title in under 10 words, the ticket is too broad.
2. **Three-file rule.** If the ticket touches more than 3 files for unrelated reasons, decompose it. Touching 5 files that all serve one feature is fine; touching 3 files for 3 unrelated fixes is not.
3. **Four-sentence environment rule.** If the Environment Context section exceeds 4 sentences, the ticket likely spans too many subsystems. Decompose.
4. **One branch-point rule.** If the Happy Path has more than one major conditional branch (e.g., "if admin, do X; if user, do Y; if guest, do Z"), split into separate tickets per actor or condition.
5. **XL is a warning.** If the effort estimate is XL, the ticket almost certainly needs decomposition. Break it into M or L tickets with explicit dependencies.

---

## 5. Where Each Section Comes From

| Power Section | Primary Source | What to Extract |
|---|---|---|
| A. Environment Context | TECHNICAL-ARCHITECTURE.md | Stack versions, framework conventions, file structure, integration points |
| B. Guardrails | AGENTIC-CONTROLS.md + PRD non-functional requirements | Security rules, performance targets, explicit prohibitions, compatibility constraints |
| C. Happy Path | PRODUCT-REQUIREMENTS.md + architecture diagrams | Feature flow broken into sequential steps, data shapes at each boundary |
| D. Definition of Done | PRD acceptance criteria + existing test patterns | Concrete assertions, lint/type commands, reviewer-verifiable outcomes |

---

## 6. Anti-Patterns

| Anti-Pattern | Why It Fails |
|---|---|
| Two-page Problem Statement | The agent parses the entire block as context. Excess narrative dilutes the actual objective and causes drift. |
| Empty Guardrails section | "The agent will figure out the constraints" -- it will not. It will take the shortest path, which may include modifying shared utilities, adding dependencies, or ignoring security boundaries. |
| Vague Definition of Done ("works correctly", "tests pass") | The agent has no termination signal. It will either stop too early (no tests) or loop indefinitely trying to satisfy an unmeasurable goal. |
| Meeting notes in the ticket | Stakeholder opinions, market justification, and design debate are noise. The agent cannot act on "PM wants this by Q3." Strip it. |
| Multiple features per ticket | Each feature needs its own Environment Context, Guardrails, and Happy Path. Bundling them forces the agent to context-switch mid-task, which degrades output quality. |
| Copy-pasting the full architecture doc into Environment Context | Reference the file. Do not inline it. The agent can read files; it cannot un-read a wall of text that buries the relevant lines. |
