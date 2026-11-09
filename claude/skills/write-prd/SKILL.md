---
name: write-prd
description: Draft a product requirements document (PRD) for a feature through clarifying questions. Use when the user wants to spec a feature before building it, or runs /write-prd. Pairs with generate-tasks and process-tasks.
---

# Write a PRD

1. Before writing, ask 3 to 7 clarifying questions as a numbered list with lettered options, so the user can answer briefly ("1b, 2a"). Cover what's missing among: problem and goal, target users, core user stories, acceptance criteria, scope and non-goals, data and integrations, constraints.
2. Look at the code the feature will touch and note existing patterns. Don't design around assumptions.
3. Write the PRD with these sections:
   - Overview
   - Goals
   - User stories
   - Functional requirements (numbered and testable)
   - Non-goals
   - Design and technical considerations
   - Success metrics
   - Open questions
4. Write for a junior developer: explicit, no unexplained jargon.
5. Save as `tasks/NNNN-prd-<feature-name>.md`, using the next free four-digit number, unless the repo has its own convention. If the repo is shared with a team, ask before adding files to it.
6. Do not start implementing. Suggest `/generate-tasks` as the next step.
