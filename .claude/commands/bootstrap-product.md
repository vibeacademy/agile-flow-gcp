---
description: "Phase 1: Create Product Requirements Document and Roadmap"
---

Launch the agile-product-manager agent to define the product vision, requirements, and initial roadmap.

## Bootstrap Phase 1: Product Definition

This is the first phase of project bootstrap. The Product Manager will guide you through defining:

1. **Product Vision** - What problem are we solving? For whom?
2. **Target Audience** - Who are our users? What are their needs?
3. **Core Features** - What must the product do? What's the MVP?
4. **Success Metrics** - How do we measure success?
5. **Competitive Landscape** - Who else solves this problem?
6. **Initial Roadmap** - What are the phases and milestones?

## Interview Process

The Product Manager will ask you questions to understand your product:

### Vision & Problem
- What problem does this product solve?
- Why does this problem matter?
- What's your vision for the solution?

### Target Users
- Who is your primary user?
- What are their pain points?
- How do they currently solve this problem?

### Features & Scope
- What are the must-have features for launch?
- What features can wait for later?
- What will you explicitly NOT build?

### Success & Metrics
- What does success look like?
- How will you measure adoption?
- What are your business goals?

### Timeline & Phases
- When do you need to launch?
- What are the major milestones?
- What are the phases of development?

## Outputs

This phase creates two documents:

### docs/PRODUCT-REQUIREMENTS.md
```markdown
# Product Requirements Document

## Vision
[Product vision statement]

## Problem Statement
[What problem we're solving]

## Target Audience
[Who we're building for]

### User Personas
[Detailed user descriptions]

## Features

### MVP (Must Have)
- Feature 1
- Feature 2

### Phase 2 (Should Have)
- Feature 3
- Feature 4

### Future (Nice to Have)
- Feature 5

## Success Metrics
- Metric 1: Target
- Metric 2: Target

## Competitive Analysis
[How we compare to alternatives]

## Constraints & Assumptions
[Known limitations]
```

### docs/PRODUCT-ROADMAP.md
```markdown
# Product Roadmap

## Overview
[High-level timeline]

## Phases

### Phase 1: MVP
- Target: [Date]
- Goal: [What we're achieving]
- Features: [List]
- Exit Criteria: [How we know it's done]

### Phase 2: [Name]
- Target: [Date]
- Goal: [What we're achieving]
- Features: [List]

## Milestones
[Key dates and deliverables]

## Dependencies & Risks
[What could block us]
```

## What Happens Next

After Phase 1 is complete:
- All agents gain product context (vision, features, users)
- Phase 2 (Technical Architecture) can begin
- System Architect will reference the PRD for technical decisions

## Tips for Success

1. **Be specific** - Vague requirements lead to vague products
2. **Prioritize ruthlessly** - Everything can't be MVP
3. **Define "not building"** - What's explicitly out of scope?
4. **Set measurable goals** - "Better UX" isn't measurable
5. **Be realistic on timeline** - Padding is wisdom, not weakness

## Running This Command

Simply type `/bootstrap-product` and follow the Product Manager's questions.

The agent will:
1. Interview you about your product
2. Synthesize your answers into structured documents
3. Create docs/PRODUCT-REQUIREMENTS.md
4. Create docs/PRODUCT-ROADMAP.md
5. Summarize what was captured

When complete, run `./bootstrap.sh` to continue to Phase 2.
