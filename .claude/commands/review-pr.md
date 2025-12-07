---
description: Review pull requests in the In Review column
---

Launch the pr-reviewer agent to review pull requests and provide go/no-go recommendations.

## What This Command Does

1. **Find PRs for Review**
   - Query tickets in the In Review column on the project board
   - Find linked pull requests
   - Check CI/CD status

2. **Code Review**
   - Review all changed files
   - Check code quality and conventions
   - Verify types and error handling
   - Assess maintainability and readability

3. **Verify Requirements**
   - Confirm ticket requirements are met
   - Check acceptance criteria are satisfied
   - Validate feature works end-to-end

4. **Test Verification**
   - Ensure all tests pass
   - Verify coverage meets thresholds
   - Review test quality

5. **Provide Assessment**
   - Post detailed review comment on PR
   - Provide GO or NO-GO recommendation
   - List any required changes
   - Highlight strengths and suggestions

## Usage

```
/review-pr
```

Or to review a specific PR:
```
/review-pr #234
```

## Important Notes

**The pr-reviewer agent CANNOT:**
- Merge pull requests (human does this)
- Move tickets to Done (human does this after merge)
- Approve PRs on GitHub (provides recommendation only)

**The agent provides decision support:**
- Detailed technical review
- GO/NO-GO recommendation with rationale
- Human reviewer makes final merge decision

## Configuration

Update the project board URL in your CLAUDE.md:
```markdown
Project Board: https://github.com/orgs/{org}/projects/{number}
```

## Output

The agent will post a detailed review comment including:
- Technical requirements checklist
- Code quality assessment
- Testing verification
- Security review
- GO/NO-GO recommendation
- Required changes (if NO-GO)
- Suggestions (non-blocking)
