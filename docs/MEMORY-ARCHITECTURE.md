# Memory Architecture — Agent Institutional Knowledge

How agile-flow agents persist, retrieve, and share knowledge across sessions.
For context engineering principles behind these choices, see
[CONTEXT-OPTIMIZATIONS.md](CONTEXT-OPTIMIZATIONS.md).

---

## 1. The Mental Model

Think of an agentic system as an operating system:

| OS Concept | Agile-Flow Equivalent | Example |
|------------|-----------------------|---------|
| **CPU** | LLM (Claude) | Processes instructions, generates output |
| **RAM** | Context window | Conversation history, tool results, system prompt |
| **DISK** | External persistence | GitHub board, Memory MCP, session journals, git history, docs/ |
| **Memory Controller** | Slash commands + agent protocols | `/log-session`, `/work-ticket`, post-merge recording |

**RAM is fast but volatile.** Everything in the context window disappears
when the session ends. If knowledge must survive a session boundary, it must
be written to DISK before the session closes.

**RAM is finite.** The context window has a hard token limit. Every token
loaded competes for attention (see
[CONTEXT-OPTIMIZATIONS.md](CONTEXT-OPTIMIZATIONS.md) for why this matters).
Memory architecture must be selective — store what cannot be rederived, not
everything that was observed.

**The Memory Controller decides what moves between RAM and DISK.** Slash
commands and agent protocols define when and how knowledge is persisted.
Without explicit write instructions, knowledge stays in RAM and is lost.

---

## 2. Four Memory Types

Agile-flow's persistence mechanisms map to four cognitive memory types.

### Working Memory (RAM — context window)

| Attribute | Value |
|-----------|-------|
| **What it stores** | Current task context: ticket body, file contents, tool results, conversation history |
| **Where it lives** | LLM context window |
| **Who reads/writes** | Every agent, every session — automatic |
| **Lifespan** | Single session only |

Working memory is managed by Claude Code's context system. Agents do not
need to explicitly manage it, but should be aware that it is finite and
volatile. The context engineering principles in CONTEXT-OPTIMIZATIONS.md
exist to maximize the useful capacity of working memory.

### Episodic Memory (what happened)

| Attribute | Value |
|-----------|-------|
| **What it stores** | Session-specific events: tickets delivered, challenges encountered, decisions made |
| **Where it lives** | `reports/session-journals/YYYY-MM-DD.md` (git-tracked) |
| **Who reads/writes** | Written by `/log-session`; read by any agent or human reviewing history |
| **Lifespan** | Permanent (committed to git) |

Episodic memory captures the narrative of each work session. It answers
"what happened on this date?" — which tickets moved, what broke, what
workarounds were applied.

**Write path:** The `/log-session` command captures tickets delivered,
challenges and mitigations, insights and learnings, and metrics. It writes
a structured journal to `reports/session-journals/`.

**Read path:** Agents or humans read journals via git. Useful for
understanding the history behind a decision or debugging a recurring issue.

### Semantic Memory (what we know)

| Attribute | Value |
|-----------|-------|
| **What it stores** | Facts, patterns, and relationships: completed tickets, review observations, feature dependencies, strategic decisions |
| **Where it lives** | Memory MCP server (graph database) |
| **Who reads/writes** | All four agents read and write via MCP tools |
| **Lifespan** | Persistent across sessions until explicitly deleted |

Semantic memory is the agent team's shared knowledge graph. It stores
structured facts that any agent can query.

**Entity types and naming conventions:**

All agents must follow these conventions when creating Memory MCP entities.
Consistent naming is critical because Memory MCP uses keyword search, not
embeddings — retrieval quality depends entirely on predictable entity names.

| Entity Type | Convention | Example | Created By |
|-------------|-----------|---------|------------|
| CompletedTicket | `CompletedTicket-{issue-number}` | `CompletedTicket-142` | Ticket Worker |
| ReviewObservation | `Review-PR-{pr-number}` | `Review-PR-150` | PR Reviewer |
| PatternDiscovered | `Pattern-{domain}-{short-name}` | `Pattern-auth-jwt-refresh` | Ticket Worker |
| LessonLearned | `Lesson-{domain}-{short-name}` | `Lesson-db-n-plus-one-fix` | Ticket Worker |
| FeatureDecision | `Decision-{feature-name}` | `Decision-social-login` | Product Manager |
| PrioritizationLogic | `Prioritization-{epic-name}` | `Prioritization-onboarding-flow` | Backlog Prioritizer |
| QualityTrend | `Trend-{topic}` | `Trend-test-coverage-gaps` | PR Reviewer |

**The `{domain}` field** should match the ticket's epic label or primary
domain area (e.g., `auth`, `db`, `ui`, `api`, `infra`, `ci`, `docs`).
Use lowercase, hyphen-separated words. Keep names short — they are search
keys, not descriptions. Put descriptive detail in observations instead.

**Relation types:**

Agents use `create_relations` to link entities. Common relations include
dependency chains (`Feature X` depends on `Feature Y`), justification links
(`Decision A` justifies `Ticket B`), and pattern associations
(`PatternDiscovered` relates to `CompletedTicket`).

**MCP tools available:**

| Tool | Purpose | Used By |
|------|---------|---------|
| `create_entities` | Store new knowledge | All agents |
| `add_observations` | Append facts to existing entities | All agents |
| `create_relations` | Link entities together | Backlog Prioritizer, Product Manager |
| `search_nodes` | Query by keyword | All agents |
| `open_nodes` | Retrieve specific entities | All agents |

**Agent-specific usage:**

- **Ticket Worker** — records CompletedTicket, PatternDiscovered, and
  LessonLearned entities after PR merge
- **PR Reviewer** — records ReviewObservation and QualityTrend entities
  after posting reviews
- **Backlog Prioritizer** — stores prioritization decisions, feature
  dependencies, and sequencing logic; uses relations to model dependency
  chains
- **Product Manager** — stores market research, feature decision rationale,
  success metrics, and strategic context

### Procedural Memory (how we work)

| Attribute | Value |
|-----------|-------|
| **What it stores** | Workflows, conventions, safety rules, formatting standards |
| **Where it lives** | `CLAUDE.md`, `.claude/agents/*.md`, `.claude/commands/*.md`, `.claude/skills/*.md`, `docs/` |
| **Who reads/writes** | Written by humans (code review + merge); read by all agents every session |
| **Lifespan** | Permanent (committed to git, loaded into context on demand) |

Procedural memory is the most heavily used memory type. It defines how
agents behave — their protocols, constraints, and workflows. Unlike the
other memory types, procedural memory is loaded directly into working
memory (RAM) at session start.

**Hierarchy:**

```
CLAUDE.md                          (loaded every session — universal rules)
  |
  +-- .claude/agents/*.md          (loaded when agent is invoked)
  |
  +-- .claude/commands/*.md        (loaded when command is invoked)
  |
  +-- .claude/skills/*.md          (loaded when skill is referenced)
  |
  +-- docs/                        (loaded on demand via tool reads)
```

**Key design principle:** Procedural memory follows the "one canonical
location per fact" rule. A convention defined in CLAUDE.md is not repeated
in agent files. Agent files reference CLAUDE.md for shared rules and
contain only what is unique to that agent's role.

---

## 3. Data Flow — A Ticket's Lifecycle Through Memory

This walkthrough traces a single ticket through the memory system from
session start to the next session.

### Session Start

```
DISK -> RAM
  |
  +-- CLAUDE.md loaded (procedural memory)
  +-- Agent policy loaded (procedural memory)
  +-- Command file loaded (procedural memory)
  +-- search_nodes("recent patterns") (semantic memory -> RAM)
```

The agent begins with procedural memory in context. It may query semantic
memory for relevant prior knowledge (e.g., patterns from similar tickets).

### During Session

```
RAM (working memory active)
  |
  +-- Reads ticket from GitHub board
  +-- Creates branch, writes code
  +-- Runs tests, creates PR
  +-- Tool results accumulate in context
```

All work happens in working memory. The context window fills with ticket
content, code diffs, test output, and conversation history. No persistence
has occurred yet.

### Session End (Post-Merge)

```
RAM -> DISK
  |
  +-- create_entities: CompletedTicket-{issue} (semantic memory)
  +-- create_entities: Pattern-{name} (semantic memory, if applicable)
  +-- create_entities: Lesson-{name} (semantic memory, if applicable)
  +-- /log-session writes journal (episodic memory)
  +-- git commit preserves code changes (procedural memory, if conventions changed)
  +-- Board state updated: ticket -> Done
```

This is the critical persistence step. Without explicit writes, everything
learned during the session is lost.

### Next Session

```
DISK -> RAM
  |
  +-- search_nodes("CompletedTicket-{issue}") retrieves prior work
  +-- Session journals available via git for historical context
  +-- Updated procedural memory reflects any convention changes
```

The next agent session can retrieve what was learned. The knowledge graph
provides structured facts; session journals provide narrative context;
git history provides code-level detail.

---

## 4. Retrieval and Write Mechanics

### Keyword Search via Memory MCP

The `search_nodes` tool performs keyword matching against entity names and
observations. Effective retrieval depends on consistent naming conventions:

- Entity names use the format `{Type}-{identifier}` (e.g.,
  `CompletedTicket-141`, `Pattern-repository-pattern`)
- Observations should include searchable terms: issue numbers, file paths,
  technology names, pattern names
- Relations enable graph traversal: "find all tickets that depend on
  Feature X"

**Search example:**

```json
{
  "tool": "mcp__memory__search_nodes",
  "input": { "query": "authentication" }
}
```

Returns all entities with "authentication" in their name or observations.

### Explicit vs. Automatic Writes

| Write Type | Trigger | Example |
|------------|---------|---------|
| **Protocol-driven** | Agent policy mandates the write | Ticket Worker records CompletedTicket after merge |
| **Command-driven** | Slash command includes write step | `/log-session` creates a session journal |
| **Judgment-driven** | Agent decides knowledge is worth preserving | Ticket Worker records a PatternDiscovered when a reusable pattern emerges |

Protocol-driven and command-driven writes are reliable — they happen every
time. Judgment-driven writes depend on the agent recognizing that something
is worth recording. The Memory Schema tables in agent policies provide
guidance on what qualifies.

---

## 5. Known Gaps

| Gap | Textbook Recommendation | Current State | When It Matters | Mitigation Path |
|-----|------------------------|---------------|-----------------|-----------------|
| **No automatic memory pruning** | Time-decay scoring to retire stale entities | Entities accumulate indefinitely | After 50+ sessions when search results become noisy | Ticket #146 — memory pruning command |
| **No post-session validation** | Verify that required memory writes occurred | No enforcement — agents may skip writes | When a session ends without recording CompletedTicket | Ticket #142 — post-session validation hook |
| **Keyword search only** | Semantic similarity search for fuzzy retrieval | Memory MCP uses exact keyword matching | When searching for concepts (not exact terms) | Depends on Memory MCP server capabilities |
| **No entity naming enforcement** | Validation against naming conventions | Naming is advisory, not enforced | When inconsistent names make search unreliable | Ticket #147 — entity naming conventions doc |
| **No cross-session context paging** | Automatic retrieval of relevant prior context | Agents must manually search_nodes | When starting work on a ticket related to prior work | Ticket #143 — ticket-aware context paging |
| **No backward-move audit trail** | Require explanation when tickets move backward | Board moves are silent | When a ticket moves from In Review back to In Progress without explanation | Ticket #144 — backward ticket move comments |

---

## 6. Extending the Memory System

For teams outgrowing the defaults:

**Add new entity types.** Define the entity type, naming convention, and
creation trigger in the relevant agent policy file. Follow the existing
Memory Schema table format.

**Add new relations.** Use `create_relations` to model domain-specific
connections. Document the relation types in agent policies so all agents
use consistent vocabulary.

**Increase retrieval quality.** Write observations with searchable
keywords. Use consistent naming conventions. Prune stale entities
periodically (see gap table above).

**Monitor memory health.** Periodically run `read_graph` to inspect the
knowledge graph. Look for orphaned entities, inconsistent naming, and
excessive observation counts that may indicate redundant recording.

**Keep procedural memory lean.** The context engineering principles in
[CONTEXT-OPTIMIZATIONS.md](CONTEXT-OPTIMIZATIONS.md) apply to memory
architecture too. Every entity loaded into working memory competes for
attention. Store what cannot be rederived; reference what can.

---

## See Also

- [CONTEXT-OPTIMIZATIONS.md](CONTEXT-OPTIMIZATIONS.md) — Context
  engineering principles that inform memory design
- [AGENT-WORKFLOW-SUMMARY.md](AGENT-WORKFLOW-SUMMARY.md) — Complete agent
  workflow documentation
- [ARTIFACT-FLOW.md](ARTIFACT-FLOW.md) — How artifacts flow through the
  system
