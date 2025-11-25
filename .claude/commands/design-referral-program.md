---
description: "Design a viral referral or ambassador program to drive organic growth"
---

## Design Referral Program

Launch the growth-marketing-strategist agent to design a referral, ambassador, or viral growth program.

## Instructions

Guide the user through referral program design by asking these questions ONE AT A TIME:

### Question 1
```
What type of program do you want to create?

1. Simple referral (give $X, get $X)
2. Tiered referral (rewards increase with more referrals)
3. Ambassador program (ongoing relationship with advocates)
4. Viral loop (built into product experience)
5. Not sure - help me decide

Enter a number (1-5):
```

### Question 2
```
What can you offer as incentives?

1. Discount/credit on our product
2. Cash/gift cards
3. Free premium features
4. Physical swag/merchandise
5. Recognition/status (leaderboards, badges)
6. Combination (please describe)
7. Not sure what we can afford

Enter a number (1-7) or describe:
```

### Question 3
```
What's the value of a new user to your business?

1. < $10
2. $10-50
3. $50-200
4. $200+
5. Not sure yet

Enter a number (1-5):
```

### Question 4
```
How will users share?

1. Unique referral link
2. Referral code to enter at signup
3. In-app invite flow (email, SMS)
4. Social media sharing
5. All of the above
6. Need recommendation

Enter a number (1-6):
```

### Question 5
```
When should rewards be granted?

1. Immediately on signup
2. After referee completes action (purchase, trial, etc.)
3. After referee stays X days
4. Split - partial now, partial later
5. Need recommendation based on fraud risk

Enter a number (1-5):
```

## Output

Create a Referral Program Design document:

```markdown
## Referral Program Design: [Program Name]

### Program Type
[From Q1 with explanation]

### Value Exchange

**Referrer Gets:**
- Reward: [Specific incentive]
- When: [Trigger event]
- Limit: [Max rewards per user]

**Referee Gets:**
- Reward: [Specific incentive]
- When: [Trigger event]
- Conditions: [Requirements to qualify]

### Economics
- Customer LTV: ~$[X] (from Q3)
- Referral reward cost: $[X]
- Target CAC via referral: $[X]
- Break-even referrals needed: [X]

### Mechanics

**Sharing Flow:**
[From Q4]

1. User navigates to referral section
2. [Step 2]
3. [Step 3]
4. Referee signs up with attribution
5. Reward granted when [trigger from Q5]

**Tracking:**
- Attribution method: [Link/Code/Both]
- Attribution window: [X days]
- Fraud prevention: [Measures]

### Anti-Gaming Measures
- [ ] Email verification required
- [ ] One reward per household/IP
- [ ] Reward caps per period
- [ ] Manual review for high-volume referrers
- [ ] [Additional measures]

### Viral Coefficient Targets
- Current K-factor: [If known]
- Target K-factor: [Goal]
- Invites per user needed: [X]
- Conversion rate needed: [X%]

### Implementation Requirements

**Technical:**
- [ ] Unique referral link/code generation
- [ ] Attribution tracking
- [ ] Reward fulfillment system
- [ ] Analytics dashboard

**Legal:**
- [ ] Terms and conditions
- [ ] Tax implications (if cash rewards)
- [ ] Regional restrictions

### Launch Plan
1. Soft launch to power users
2. Iterate based on feedback
3. Full launch with promotion
4. Ongoing optimization

### Success Metrics
| Metric | Target | Measurement |
|--------|--------|-------------|
| Participation rate | X% | % of users who refer |
| Shares per referrer | X | Avg invites sent |
| Conversion rate | X% | Referees who convert |
| K-factor | X.X | Viral coefficient |
| CAC via referral | $X | Cost per referred user |

### Next Steps
1. [Immediate action]
2. [Next action]
3. [Next action]
```

Save to `docs/REFERRAL-PROGRAM.md`.
