---
description: "Audit current marketing efforts and get optimization recommendations"
---

## Marketing Audit

Launch the growth-marketing-strategist agent to audit current marketing efforts and provide recommendations.

## Instructions

Guide the user through a marketing audit by asking these questions ONE AT A TIME:

### Question 1
```
What marketing channels are you currently using? (Select all that apply, e.g., "1,3,5")

1. Organic social media
2. Paid social (Meta, TikTok, etc.)
3. Google/Search ads
4. SEO/Content marketing
5. Email marketing
6. Influencer partnerships
7. Referral program
8. PR/Media
9. Events/Conferences
10. None yet - planning to start

Enter numbers separated by commas:
```

### Question 2
```
What's your approximate monthly marketing spend?

1. $0 (organic only)
2. $1-500
3. $500-2,000
4. $2,000-10,000
5. $10,000+

Enter a number (1-5):
```

### Question 3
```
What's your biggest marketing challenge right now?

1. Not enough traffic/awareness
2. Traffic but low conversions
3. High customer acquisition cost (CAC)
4. Don't know what's working
5. Can't scale what's working
6. No clear strategy/direction
7. Other (please describe)

Enter a number (1-7) or describe:
```

### Question 4
```
What data/metrics do you currently track?

1. Basic analytics (traffic, signups)
2. Channel attribution (know where users come from)
3. Full funnel metrics (CAC, LTV, ROAS)
4. Limited tracking - need to improve
5. No tracking yet

Enter a number (1-5):
```

### Question 5
```
What's your primary user acquisition goal?

1. More volume (scale signups)
2. Better quality (higher-value users)
3. Lower cost (reduce CAC)
4. Faster growth (accelerate timeline)
5. All of the above

Enter a number (1-5):
```

## Output

Create a Marketing Audit Report:

```markdown
## Marketing Audit Report

**Date:** [Today's date]
**Audited by:** Growth Marketing Strategist

---

### Executive Summary

**Current State:** [Brief assessment]

**Key Finding:** [Most important insight]

**Top Recommendation:** [Highest-impact action]

---

### Channel Assessment

[For each channel from Q1]

#### [Channel Name]
- **Status:** Active/Inactive
- **Investment:** [$ or effort level]
- **Performance:** [Assessment based on available info]
- **Grade:** A/B/C/D/F
- **Recommendation:** [Keep/Optimize/Pause/Scale]

| Channel | Status | Grade | Action |
|---------|--------|-------|--------|
| [Channel] | [Active/Inactive] | [Grade] | [Action] |

---

### Problem Analysis

**Primary Challenge:** [From Q3]

**Root Causes:**
1. [Cause 1]
2. [Cause 2]
3. [Cause 3]

**Impact:**
[How this challenge affects growth]

---

### Measurement Gaps

**Current Tracking:** [From Q4]

**Missing Metrics:**
- [ ] [Metric that should be tracked]
- [ ] [Metric that should be tracked]
- [ ] [Metric that should be tracked]

**Tracking Recommendations:**
1. [What to implement]
2. [What to implement]

---

### Budget Analysis

**Current Spend:** [From Q2]

**Allocation Assessment:**
[Is spend distributed effectively?]

**Recommended Reallocation:**
| Channel | Current | Recommended | Rationale |
|---------|---------|-------------|-----------|
| [Channel] | [%/$] | [%/$] | [Why] |

---

### Quick Wins (Next 30 Days)

1. **[Quick Win 1]**
   - Effort: Low/Medium/High
   - Impact: Low/Medium/High
   - Action: [Specific steps]

2. **[Quick Win 2]**
   - Effort: Low/Medium/High
   - Impact: Low/Medium/High
   - Action: [Specific steps]

3. **[Quick Win 3]**
   - Effort: Low/Medium/High
   - Impact: Low/Medium/High
   - Action: [Specific steps]

---

### Strategic Recommendations (60-90 Days)

#### Priority 1: [Recommendation]
**Why:** [Rationale tied to Q5 goal]
**How:** [Implementation approach]
**Expected Impact:** [Metrics improvement]
**Investment:** [Time/money required]

#### Priority 2: [Recommendation]
**Why:** [Rationale]
**How:** [Implementation approach]
**Expected Impact:** [Metrics improvement]
**Investment:** [Time/money required]

#### Priority 3: [Recommendation]
**Why:** [Rationale]
**How:** [Implementation approach]
**Expected Impact:** [Metrics improvement]
**Investment:** [Time/money required]

---

### Channels to Consider

**Not Currently Using:**
[Channels that could work based on product/audience]

| Channel | Fit | Difficulty | Recommendation |
|---------|-----|------------|----------------|
| [Channel] | High/Med/Low | Easy/Med/Hard | [Try/Skip/Later] |

---

### Competitive Gaps

**What competitors likely do better:**
- [Gap 1]
- [Gap 2]

**Opportunities to differentiate:**
- [Opportunity 1]
- [Opportunity 2]

---

### Success Metrics to Target

Based on goal: [From Q5]

| Metric | Current | 30-Day Target | 90-Day Target |
|--------|---------|---------------|---------------|
| [Metric] | [Value] | [Target] | [Target] |

---

### Next Steps

**Immediate (This Week):**
1. [ ] [Action]
2. [ ] [Action]

**Short-term (30 Days):**
1. [ ] [Action]
2. [ ] [Action]

**Medium-term (90 Days):**
1. [ ] [Action]
2. [ ] [Action]

---

### Questions to Discuss

1. [Question for user to consider]
2. [Question for user to consider]
3. [Question for user to consider]
```

Save to `docs/MARKETING-AUDIT.md`.
