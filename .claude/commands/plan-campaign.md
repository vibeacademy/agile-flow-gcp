---
description: "Design a marketing campaign with channel strategy, creative direction, and budget"
---

## Plan Marketing Campaign

Launch the growth-marketing-strategist agent to design a comprehensive marketing campaign.

## Instructions

Guide the user through campaign planning by asking these questions ONE AT A TIME:

### Question 1
```
What is the primary goal of this campaign?

1. Brand awareness (get our name out there)
2. User acquisition (drive signups/downloads)
3. Product launch (announce new feature/product)
4. Re-engagement (bring back inactive users)
5. Seasonal promotion (holiday, event-based)
6. Other (please describe)

Enter a number (1-6) or describe:
```

### Question 2
```
Who is the target audience for this campaign?

Describe in one sentence (e.g., "Small business owners aged 25-45 who use spreadsheets for inventory")
```

### Question 3
```
What's your budget range?

1. $0 (organic only)
2. $100-500
3. $500-2,000
4. $2,000-10,000
5. $10,000+
6. Not sure yet

Enter a number (1-6):
```

### Question 4
```
What's the timeline?

1. Launch this week
2. Launch in 2 weeks
3. Launch in 1 month
4. Ongoing/evergreen campaign
5. Tied to specific date (please specify)

Enter a number (1-5) or specify date:
```

### Question 5
```
Which channels are you considering? (Select all that apply, e.g., "1,3,5")

1. Social media (organic)
2. Paid social (Meta, TikTok, etc.)
3. Google/Search ads
4. Email marketing
5. Content/SEO
6. Influencer partnerships
7. Local/community marketing
8. Referral/viral program
9. Not sure - recommend channels

Enter numbers separated by commas:
```

### Question 6
```
Do you have any creative assets ready?

1. Yes - photos, videos, copy ready
2. Partial - some assets, need more
3. No - need to create everything
4. Need guidance on what to create

Enter a number (1-4):
```

## Output

After collecting responses, create a Campaign Brief document:

```markdown
## Campaign Brief: [Name based on goal]

### Background
[Context from user responses]

### Objective
- Goal: [From Q1]
- Primary KPI: [Appropriate metric]
- Target: [Specific number if possible]

### Target Audience
[From Q2, expanded with psychographics]

### Channel Strategy
[From Q5, with rationale and prioritization]

| Channel | Role | Budget Allocation |
|---------|------|-------------------|
| [Channel] | [Awareness/Conversion/etc] | [% or $] |

### Creative Direction
- Key message: [One sentence value prop]
- Tone: [Brand voice guidance]
- Assets needed: [Based on Q6]
- Variants to test: [A/B test recommendations]

### Timeline
[From Q4]

| Milestone | Date |
|-----------|------|
| Creative ready | [Date] |
| Launch | [Date] |
| First optimization | [Date] |
| Wrap-up/Report | [Date] |

### Budget
- Total: [From Q3]
- Allocation: [By channel]

### Success Metrics
- Primary: [KPI with target]
- Secondary: [Supporting metrics]

### Next Steps
1. [Immediate action]
2. [Next action]
3. [Next action]
```

Save the brief to `docs/campaigns/[campaign-name]-brief.md`.
