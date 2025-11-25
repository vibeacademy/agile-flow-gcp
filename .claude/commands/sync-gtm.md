---
description: "Checkpoint sync between Product and Marketing for go-to-market alignment"
---

## Go-to-Market Sync

This command facilitates alignment checkpoints between Product Manager and Growth Marketing Strategist. Run this at key phases to ensure marketing is prepared and aligned with product reality.

## Instructions

First, determine which checkpoint the user needs:

### Question 1
```
Which GTM checkpoint are you at?

1. PRD Review - PRD drafted, need marketing input on personas/positioning
2. Scope Lock - MVP scope finalized, ready to brief marketing on GTM
3. Dev Midpoint - Development ~50% complete, marketing prepares assets
4. Pre-Launch - Feature complete, ready for soft launch
5. Launch - Full release, execute campaigns
6. Post-Launch - Analyze results, iterate

Enter a number (1-6):
```

Then run the appropriate checkpoint protocol below.

---

## Checkpoint 1: PRD Review

**Timing:** After PRD draft, before finalizing scope

**Purpose:** Validate that target audience is marketable and positioning is differentiated

### Marketing Reviews:
- Read `docs/PRODUCT-REQUIREMENTS.md`
- Assess target audience clarity
- Evaluate competitive positioning
- Flag any messaging concerns

### Questions for Product Manager:
```
1. Is the target audience specific enough to reach through marketing channels?
2. Is the value proposition differentiated from competitors?
3. Are there any claims we can't substantiate?
4. What's the one sentence we want customers to remember?
```

### Output: PRD Marketing Review
```markdown
## PRD Marketing Review

**Date:** [Date]
**PRD Version:** [Version/Date of PRD reviewed]

### Target Audience Assessment
- Clarity: [Clear/Needs Work]
- Reachability: [Easy/Moderate/Hard to reach via marketing]
- Size: [Large enough to justify investment?]
- Feedback: [Specific suggestions]

### Positioning Assessment
- Differentiation: [Strong/Moderate/Weak]
- Credibility: [Can we back up claims?]
- Simplicity: [Easy to explain in 10 seconds?]
- Feedback: [Specific suggestions]

### Recommended Messaging Framework
- **Headline:** [One sentence value prop]
- **Subhead:** [Supporting benefit]
- **Proof Points:** [3 reasons to believe]

### Red Flags
- [ ] [Any concerns that could hurt marketing]

### Alignment Status: [ALIGNED / NEEDS DISCUSSION]

### Action Items
- [ ] [Action for Product Manager]
- [ ] [Action for Marketing]
```

Save to `docs/gtm/checkpoint-1-prd-review.md`

---

## Checkpoint 2: Scope Lock

**Timing:** When MVP scope is finalized and development begins

**Purpose:** Brief marketing on what's being built so GTM planning can start

### Product Manager Provides:
- Final MVP feature list
- Target launch timeframe
- Key differentiators
- Any constraints (budget, channels, timing)

### Questions to Answer:
```
1. What are the 3-5 features in MVP? (brief description of each)
2. What's the target launch window?
3. What's the budget range for launch marketing?
4. Any channels that are off-limits or required?
5. Who are the first 100 users we want?
```

### Output: GTM Brief
```markdown
## Go-to-Market Brief

**Date:** [Date]
**Target Launch:** [Window]

### Product Summary
[2-3 sentence description of what's being built]

### MVP Features
| Feature | User Benefit | Marketing Angle |
|---------|--------------|-----------------|
| [Feature 1] | [Benefit] | [How to message] |
| [Feature 2] | [Benefit] | [How to message] |
| [Feature 3] | [Benefit] | [How to message] |

### Target Audience
- **Primary:** [Who]
- **First 100 users:** [Specific profile]
- **Where to find them:** [Channels/communities]

### Positioning
- **Category:** [What category do we compete in?]
- **Differentiator:** [Why us over alternatives?]
- **Proof:** [Evidence/credibility]

### Competitive Landscape
| Competitor | Their Positioning | Our Counter |
|------------|-------------------|-------------|
| [Competitor] | [Their claim] | [Our advantage] |

### Launch Constraints
- Budget: [Range]
- Timeline: [Dates]
- Channel restrictions: [Any limitations]
- Dependencies: [What must happen first]

### GTM Skeleton
- **Awareness:** [High-level channel strategy]
- **Activation:** [How we'll convert interest to signups]
- **Launch moment:** [Big bang vs. soft launch]

### Open Questions
- [ ] [Question for Product Manager]
- [ ] [Question to resolve before launch]

### Alignment Status: [ALIGNED / NEEDS DISCUSSION]
```

Save to `docs/gtm/checkpoint-2-scope-lock.md`

---

## Checkpoint 3: Dev Midpoint

**Timing:** Development ~50% complete

**Purpose:** Marketing finalizes assets while there's still time to adjust

### Marketing Prepares:
- Landing page copy
- Ad creative concepts
- Email sequences
- Social content calendar
- Influencer/partner outreach

### Questions to Answer:
```
1. Any scope changes since Checkpoint 2?
2. Is the launch date still on track?
3. Can we get early access for screenshots/demos?
4. Any new competitive intel?
5. Are there beta users we can feature?
```

### Output: Asset Readiness Check
```markdown
## GTM Asset Readiness

**Date:** [Date]
**Launch Target:** [Date]
**Days to Launch:** [X]

### Scope Check
- Changes since Checkpoint 2: [None / List changes]
- Impact on messaging: [None / Adjustments needed]

### Asset Status
| Asset | Status | Owner | Due |
|-------|--------|-------|-----|
| Landing page copy | [Draft/Review/Final] | [Who] | [Date] |
| Landing page design | [Draft/Review/Final] | [Who] | [Date] |
| Ad creative (static) | [Draft/Review/Final] | [Who] | [Date] |
| Ad creative (video) | [Draft/Review/Final] | [Who] | [Date] |
| Email welcome sequence | [Draft/Review/Final] | [Who] | [Date] |
| Social launch posts | [Draft/Review/Final] | [Who] | [Date] |
| Press/media kit | [Draft/Review/Final] | [Who] | [Date] |

### Early Access Needs
- [ ] Screenshots of key features
- [ ] Demo video/GIF
- [ ] Beta user testimonials
- [ ] Product walkthrough

### Campaign Setup Status
| Channel | Account Ready | Tracking Setup | Creative Loaded |
|---------|---------------|----------------|-----------------|
| [Channel] | [Yes/No] | [Yes/No] | [Yes/No] |

### Blockers
- [ ] [Blocker and owner]

### Alignment Status: [ON TRACK / AT RISK / BLOCKED]
```

Save to `docs/gtm/checkpoint-3-dev-midpoint.md`

---

## Checkpoint 4: Pre-Launch

**Timing:** Feature complete, before public launch

**Purpose:** Final alignment and soft launch to early adopters

### Pre-Launch Checklist:
```markdown
## Pre-Launch Checklist

**Date:** [Date]
**Launch Date:** [Date]
**Days to Launch:** [X]

### Product Readiness
- [ ] All MVP features complete
- [ ] Critical bugs resolved
- [ ] Performance acceptable
- [ ] Onboarding flow tested

### Marketing Readiness
- [ ] Landing page live (or staged)
- [ ] Tracking/analytics implemented
- [ ] Ad campaigns ready to activate
- [ ] Email sequences loaded
- [ ] Social posts scheduled

### Soft Launch Plan
- **Audience:** [Who gets early access]
- **Size:** [How many]
- **Duration:** [How long before full launch]
- **Goal:** [What we're validating]
- **Feedback mechanism:** [How we'll collect input]

### Launch Day Plan
| Time | Action | Owner |
|------|--------|-------|
| [Time] | [Action] | [Who] |

### Rollback Plan
- **Trigger:** [What would cause us to pause]
- **Action:** [What we'd do]

### Alignment Status: [GO / NO-GO / CONDITIONAL]

### Conditions (if conditional):
- [ ] [What must be resolved]
```

Save to `docs/gtm/checkpoint-4-pre-launch.md`

---

## Checkpoint 5: Launch

**Timing:** Launch day/week

**Purpose:** Execute coordinated launch and monitor results

### Launch Execution Tracker:
```markdown
## Launch Tracker

**Launch Date:** [Date]
**Status:** [Live / Partial / Delayed]

### Launch Actions
| Action | Time | Status | Notes |
|--------|------|--------|-------|
| Product goes live | [Time] | [Done/Pending] | |
| Landing page updated | [Time] | [Done/Pending] | |
| Ads activated | [Time] | [Done/Pending] | |
| Emails sent | [Time] | [Done/Pending] | |
| Social posts live | [Time] | [Done/Pending] | |
| PR/outreach sent | [Time] | [Done/Pending] | |

### Day 1 Metrics
| Metric | Target | Actual |
|--------|--------|--------|
| Site visits | [X] | [X] |
| Signups | [X] | [X] |
| Activation rate | [X%] | [X%] |

### Issues/Incidents
| Issue | Severity | Status | Resolution |
|-------|----------|--------|------------|
| [Issue] | [High/Med/Low] | [Open/Resolved] | [Action] |

### Real-time Adjustments
- [Adjustment made and why]

### Day 1 Summary
[Brief narrative of how launch went]
```

Save to `docs/gtm/checkpoint-5-launch.md`

---

## Checkpoint 6: Post-Launch

**Timing:** 1-2 weeks after launch

**Purpose:** Analyze results, capture learnings, iterate

### Post-Launch Review:
```markdown
## Post-Launch Review

**Launch Date:** [Date]
**Review Date:** [Date]
**Days Since Launch:** [X]

### Results vs. Targets
| Metric | Target | Actual | Delta |
|--------|--------|--------|-------|
| Signups | [X] | [X] | [+/-X%] |
| Activation | [X%] | [X%] | [+/-X%] |
| CAC | $[X] | $[X] | [+/-X%] |
| [Other] | [X] | [X] | [+/-X%] |

### Channel Performance
| Channel | Spend | Results | CAC | ROAS |
|---------|-------|---------|-----|------|
| [Channel] | $[X] | [X signups] | $[X] | [X.Xx] |

### What Worked
1. [Success and why]
2. [Success and why]

### What Didn't Work
1. [Failure and why]
2. [Failure and why]

### User Feedback Themes
- [Theme 1]: [Evidence]
- [Theme 2]: [Evidence]

### Product-Marketing Gaps
- [Any disconnect between product reality and marketing message]

### Iteration Plan
| Action | Owner | Priority | Timeline |
|--------|-------|----------|----------|
| [Action] | [Who] | [P0/P1/P2] | [When] |

### Learnings for Next Launch
1. [Learning]
2. [Learning]
3. [Learning]

### Alignment Status: [SUCCESSFUL / NEEDS ITERATION / REQUIRES PIVOT]
```

Save to `docs/gtm/checkpoint-6-post-launch.md`

---

## Summary: Checkpoint Flow

```
Checkpoint 1: PRD Review
    ↓ Marketing validates personas & positioning
Checkpoint 2: Scope Lock
    ↓ Marketing gets briefed, starts GTM planning
Checkpoint 3: Dev Midpoint
    ↓ Marketing finalizes assets
Checkpoint 4: Pre-Launch
    ↓ Final alignment, soft launch
Checkpoint 5: Launch
    ↓ Execute and monitor
Checkpoint 6: Post-Launch
    → Analyze, iterate, feed back to Product
```

Each checkpoint produces an artifact in `docs/gtm/` that serves as the alignment contract between Product and Marketing.
