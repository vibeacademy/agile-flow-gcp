---
description: Groom the project backlog, prioritize tickets, and populate the Ready column
---

Launch the agile-backlog-prioritizer agent to perform comprehensive backlog grooming.

## What This Command Does

1. **Review Product Strategy**
   - Read `docs/PRODUCT-REQUIREMENTS.md` for current goals
   - Read `docs/PRODUCT-ROADMAP.md` for current phase and milestones
   - Verify backlog reflects strategic priorities

2. **Analyze Backlog Health**
   - Count tickets by status (Backlog, Ready, In Progress, In Review, Done, Icebox)
   - Assess ticket quality (descriptions, acceptance criteria, effort estimates)
   - Identify stale tickets (>30 days without activity)

3. **Prioritize Using CD3**
   - Calculate Cost of Delay / Duration for backlog items
   - Weight by user impact and business value
   - Consider feature dependencies

4. **Ensure Definition of Ready**
   - Verify top tickets have clear titles and descriptions
   - Confirm acceptance criteria are specific and testable
   - Check effort estimates and priority labels
   - Validate technical guidance is provided

5. **Populate Ready Column**
   - Move top 2-5 well-defined tickets to Ready
   - Balance quick wins with strategic features
   - Ensure no blockers on Ready items

6. **Identify Issues**
   - Flag tickets needing refinement
   - Identify dependency conflicts
   - Note scope creep or misalignment with roadmap

## Configuration

Update the project board URL in your CLAUDE.md:
```markdown
Project Board: https://github.com/orgs/{org}/projects/{number}
```

## Output

The agent will report:
- Backlog health metrics
- Top priorities moved to Ready
- Tickets needing refinement
- Blockers and risks
- Recommendations for next grooming session
