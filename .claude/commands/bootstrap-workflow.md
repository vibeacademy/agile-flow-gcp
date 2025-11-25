---
description: "Phase 4: Activate the development workflow"
---

Set up GitHub project board, branch protection, and create initial backlog from PRD features.

## Bootstrap Phase 4: Workflow Activation

**Prerequisites**:
- Phase 1 (Product Definition) complete
- Phase 2 (Technical Architecture) complete
- Phase 3 (Agent Specialization) complete

This is the final bootstrap phase. It activates the full agent workflow.

## What This Phase Does

### 1. GitHub Project Board Setup

Verify or create project board with columns:
- **Icebox** - Ideas not yet prioritized
- **Backlog** - Prioritized but not ready
- **Ready** - Well-defined, ready to work (2-5 items)
- **In Progress** - Currently being worked
- **In Review** - PR created, awaiting review
- **Done** - Merged and complete

### 2. Branch Protection Configuration

Verify or configure branch protection on `main`:
- [ ] Require pull request reviews before merging
- [ ] Require status checks to pass (if CI configured)
- [ ] Do not allow bypassing the above settings

### 3. Initial Backlog Creation

Convert PRD features into GitHub issues:
- Create epics for major feature areas
- Create issues for MVP features
- Link issues to epics
- Add initial priority labels

### 4. Ready Column Population

Move the highest-priority, well-defined tickets to Ready:
- Select 3-5 tickets for initial Ready column
- Ensure they meet Definition of Ready
- Add technical guidance and acceptance criteria

### 5. CLAUDE.md Finalization

Update CLAUDE.md with:
- Project board URL
- Repository URL
- Team/org information
- Any final configuration

## Pre-Flight Checklist

Before running this phase, ensure you have:

- [ ] GitHub repository created
- [ ] GitHub personal access token with repo and project permissions
- [ ] Permission to create project boards
- [ ] Permission to configure branch protection

## Configuration Required

You'll be asked to provide:

```
GitHub Organization: [your-org]
Repository Name: [your-repo]
Project Board Name: [your-project-name]
```

## Process

The workflow activation agent will:

1. **Verify GitHub Access**
   - Test token permissions
   - Confirm org/repo access

2. **Create/Verify Project Board**
   - Check if board exists
   - Create columns if needed
   - Configure board settings

3. **Configure Branch Protection**
   - Check current settings
   - Apply protection rules
   - Verify configuration

4. **Generate Backlog**
   - Read PRD features
   - Create epic issues
   - Create feature issues
   - Set initial priorities

5. **Populate Ready Column**
   - Select MVP tickets
   - Ensure Definition of Ready met
   - Move to Ready column

6. **Update Configuration**
   - Add URLs to CLAUDE.md
   - Verify agent configs reference correct board

## Example Backlog Generation

From PRD features like:
```markdown
### MVP Features
- User authentication (email/password)
- User profile management
- Core dashboard
```

Creates issues like:
```
Epic: User Authentication
  - Issue: Implement email/password signup
  - Issue: Implement login flow
  - Issue: Implement password reset
  - Issue: Add session management

Epic: User Profile
  - Issue: Create profile page
  - Issue: Implement profile editing
  - Issue: Add avatar upload
```

## What Gets Unlocked

After Phase 4, the full workflow is active:

```
/groom-backlog  →  Works with your project board
/work-ticket    →  Picks up tickets from your Ready column
/review-pr      →  Reviews PRs in your repository
/sprint-status  →  Shows your board status
```

## Verification

After this phase, verify the workflow:

1. **Check Project Board**
   - Visit the GitHub project board URL
   - Verify columns exist
   - Verify issues created

2. **Check Branch Protection**
   - Go to repo Settings → Branches
   - Verify `main` is protected

3. **Test Workflow**
   ```bash
   claude
   > /sprint-status
   ```
   Should show your board status

## Post-Bootstrap

Your project is now ready for development!

**Daily workflow:**
```bash
/sprint-status    # Morning check
/work-ticket      # Pick up work
/review-pr        # Review PRs
```

**Weekly planning:**
```bash
/check-milestone  # Track progress
/groom-backlog    # Maintain backlog
```

## Troubleshooting

**"GitHub token not authorized"**
- Ensure token has `repo` and `project` scopes
- Check token isn't expired

**"Cannot create project board"**
- Verify org permissions
- Try creating manually, then link

**"Branch protection failed"**
- Verify you have admin access to repo
- Configure manually in GitHub settings

**"Issues not appearing on board"**
- Check issue labels match board filters
- Manually add issues to project

## Running This Command

1. Ensure Phases 1-3 are complete
2. Have GitHub credentials ready
3. Type `/bootstrap-workflow`
4. Provide org/repo information
5. Review proposed changes
6. Confirm to apply

When complete, your Agile Flow project is fully operational!

## Next Steps

After bootstrap:

1. **Review the backlog** - `/groom-backlog`
2. **Start first ticket** - `/work-ticket`
3. **Invite team members** - Share repo access
4. **Set up CI/CD** - Configure GitHub Actions
5. **Schedule standups** - Daily `/sprint-status`
