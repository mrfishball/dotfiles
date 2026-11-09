---
name: generate-tasks
description: Turn a PRD into a step-by-step implementation task list. Use when the user wants tasks from a PRD or spec, or runs /generate-tasks.
---

# Generate tasks from a PRD

1. Pick the PRD. If the user didn't name one, list the `tasks/*-prd-*.md` files that don't yet have a matching `tasks/tasks-<prd file name>` as a numbered list, and ask which to use. Always confirm the file name before continuing.
2. Read the PRD and the code it affects.
3. Phase 1: draft about five parent tasks. Show them and ask the user to reply "Go" for sub-tasks. Wait.
4. Phase 2: break each parent into small sub-tasks. Each sub-task ends with how to verify it (a test to write and pass, or a check to run).
5. Add a "Relevant files" section listing files to create or change, with their test files and a one-line purpose each.
6. Save as `tasks/tasks-<prd file name>`:

   ```markdown
   ## Relevant files
   - `path/to/file.py`: purpose
   - `path/to/test_file.py`: tests for file.py

   ## Tasks
   - [ ] 1.0 Parent task
     - [ ] 1.1 Sub-task → verify: test X passes
   ```

7. Suggest `/process-tasks` as the next step.
