---
description: Pick up and work on the next ticket from the Ready column
---

Launch the github-ticket-worker agent to implement the next prioritized ticket.

## What This Command Does

1. **Select Ticket**
   - Find the top priority ticket in the Ready column
   - Verify it meets Definition of Ready
   - Confirm no blockers

2. **Setup**
   - Create feature branch: `feature/issue-{number}-short-description`
   - Move ticket to In Progress on project board
   - Add comment noting work has started

3. **Implement**
   - Follow project standards from CLAUDE.md
   - Write clean, well-documented code
   - Follow existing patterns and conventions

4. **Test**
   - Write/update tests for new functionality
   - Ensure all tests pass
   - Verify coverage meets project thresholds

5. **Create Pull Request**
   - Push feature branch
   - Create PR with detailed description
   - Link PR to the issue
   - Move ticket to In Review

## Usage

```
/work-ticket
```

Or to work on a specific ticket:
```
/work-ticket #123
```

## Configuration

Update the project board URL in your CLAUDE.md:
```markdown
Project Board: https://github.com/orgs/{org}/projects/{number}
```

## Workflow Rules

- Only work on tickets from the Ready column
- One ticket at a time (no parallel work)
- Never commit directly to main
- Always create PR for review
- Agent cannot merge PRs (human reviewer does this)

## Output

The agent will:
- Report which ticket was selected
- Provide implementation progress updates
- Create a pull request when complete
- Move ticket through board columns appropriately
